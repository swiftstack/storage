import Time
import File
import Async

import Platform

public class Storage {
    enum Error: String, Swift.Error {
        case invalidKind = "invalid kind, please use struct or enum"
        case incompatibleType = "the container was created for another type"
        case invalidSnapshot
        case unknownType
    }

    public typealias Key = String

    struct Settings {
        let path: Path

        var wal: File {
            return File(name: "wal", at: path)
        }

        var snapshot: File {
            return File(name: "snapshot", at: path)
        }
    }

    var settings: Settings
    var containers: [Key : ContainerProtocol] = [:]

    lazy var wal: WAL.Writer = {
        return WAL.Writer(to: settings.wal, encoder: coder)
    }()

    let coderType: StreamCoder.Type

    lazy var coder: StreamCoder = {
        return coderType.init(typeAccessor: { [unowned self] key in
            guard let container = self.containers[key] else {
                throw Error.unknownType
            }
            return container.type
        })
    }()

    public init(at path: Path, coder: StreamCoder.Type) throws {
        self.settings = Settings(path: path)
        self.coderType = coder
    }

    public func container<T>(for type: T.Type) throws -> Container<T>
        where T: AnyObject & Codable
    {
        throw Error.invalidKind
    }

    public func container<T: Codable>(for type: T.Type) throws -> Container<T> {
        switch containers[Key(for: type)] {
        case .some(let container as Container<T>): return container
        case .some(_): throw Error.incompatibleType
        case .none: return register(type)
        }
    }

    @discardableResult
    func register<T: Entity>(_ type: T.Type) -> Container<T> {
        let container = Container<T>(in: self)
        containers[Key(for: type)] = container
        return container
    }

    func makeSnapshot() throws {
        let writer = try Snapshot.Writer(to: settings.snapshot, encoder: coder)
        for (key, container) in containers {
            try writer.write(header: .init(name: key, count: container.count))
            var iterator = container.makeSnapshotIterator()
            while let next = iterator.next() {
                try writer.write(next)
            }
        }
        try writer.flush()
    }

    func restore() throws {
        if File.isExists(at: settings.path.appending("snapshot")) {
            let snapshot = settings.snapshot
            let reader = try Snapshot.Reader(from: snapshot, decoder: coder)
            while let header = try reader.readHeader() {
                guard let container = containers[header.name] else {
                    throw Error.unknownType
                }
                for _ in 0..<header.count {
                    guard let item = try reader.readNext(container.type) else {
                        throw Error.invalidSnapshot
                    }
                    try container.restore(item)
                }
            }
        }

        if File.isExists(at: settings.path.appending("wal")) {
            let reader = WAL.Reader(from: settings.wal, decoder: coder)
            let interator = try reader.makeRecoveryIterator()
            while let next = interator.next() {
                guard let container = containers[next.key] else {
                    throw Error.unknownType
                }
                try container.play(next)
            }
        }
    }
}

extension Storage.Key {
    init<T>(for type: T.Type) {
        self = "\(type)"
    }
}
