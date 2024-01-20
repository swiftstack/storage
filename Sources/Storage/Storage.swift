import Time
import FileSystem

public class Storage {
    public typealias Key = String

    var containers: [Key: PersistentContainer] = [:]

    let path: Path
    let coder: StreamCoder

    public init(at path: Path, coder: StreamCoder) throws {
        self.path = path
        self.coder = coder
    }
}

// MARK: Key shim

extension Storage.Key {
    init<T>(for type: T.Type) {
        self = "\(type)"
    }
}

// MARK: Containers

extension Storage {
    public enum Error: String, Swift.Error {
        case alreadyExists = "a container for the type is already exists"
        case invalidKind = "invalid kind, please use struct or enum"
        case incompatibleType = "the container was created for another type"
    }

    public func container<T: AnyObject & Codable>(
        for type: T.Type
    ) throws -> Container<T> {
        throw Error.invalidKind
    }

    public func container<T: Codable>(
        for type: T.Type
    ) throws -> Container<T> {
        switch containers[Key(for: type)] {
        case .some(let container as Container<T>): return container
        case .some: throw Error.incompatibleType
        case .none: return createContainer(for: type)
        }
    }

    public func register<T: Entity>(_ type: T.Type) throws {
        guard containers[Key(for: type)] == nil else {
            throw Error.alreadyExists
        }
        createContainer(for: type)
    }

    @discardableResult
    func createContainer<T: Entity>(for type: T.Type) -> Container<T> {
        let name = String(describing: type)
        let container = Container<T>(name: name, at: path, coder: coder)
        containers[Key(for: type)] = container
        return container
    }
}

extension Storage: PersistentContainer {
    var isDirty: Bool {
        containers.values.contains { $0.isDirty }
    }

    func writeLog() async throws {
        for (_, container) in containers {
            try await container.writeLog()
        }
    }

    func makeSnapshot() async throws {
        for (_, container) in containers {
            try await container.makeSnapshot()
        }
    }

    func restore() async throws {
        for (_, container) in containers {
            try await container.restore()
        }
    }
}
