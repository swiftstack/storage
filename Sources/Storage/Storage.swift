import Time
import File
import Async

public class Storage {
    public typealias Key = String

    var containers: [Key : PersistentContainer] = [:]

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
        case alreadyExista = "a container for the type is already exists"
        case invalidKind = "invalid kind, please use struct or enum"
        case incompatibleType = "the container was created for another type"
    }

    public func container<T>(for type: T.Type) throws -> Container<T>
        where T: AnyObject & Codable
    {
        throw Error.invalidKind
    }

    public func container<T>(for type: T.Type) throws -> Container<T>
        where T: Codable
    {
        switch containers[Key(for: type)] {
        case .some(let container as Container<T>): return container
        case .some(_): throw Error.incompatibleType
        case .none: return createContainer(for: type)
        }
    }

    public func register<T: Entity>(_ type: T.Type) throws {
        guard containers[Key(for: type)] == nil else {
            throw Error.alreadyExista
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
        for (_, container) in containers {
            if container.isDirty {
                return true
            }
        }
        return false
    }

    func writeLog() throws {
        for (_, container) in containers {
            try container.writeLog()
        }
    }

    func makeSnapshot() throws {
        for (_, container) in containers {
            try container.makeSnapshot()
        }
    }

    func restore() throws {
        for (_, container) in containers {
            try container.restore()
        }
    }
}
