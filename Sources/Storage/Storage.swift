import Time
import File
import Async

import Platform

public class Storage {
    enum Error: String, Swift.Error {
        case invalidKind = "invalid kind, please use struct or enum"
        case incompatibleType = "the container was created for another type"
    }

    public typealias Key = String

    var containers: [Key : ContainerProtocol] = [:]
    var persistense: Persistence? = nil

    public init(at path: Path, coder: StreamCoder.Type) throws {
        // FIXME: ref cycle
        self.persistense = Persistence(for: self, at: path, coder: coder)
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
}

extension Storage {
    func makeSnapshot() throws {
        try persistense?.makeSnapshot()
    }

    func restore() throws {
        try persistense?.restore()
    }
}

extension Storage.Key {
    init<T>(for type: T.Type) {
        self = "\(type)"
    }
}
