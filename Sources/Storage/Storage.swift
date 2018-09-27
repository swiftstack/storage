import Time
import File
import Async

public class Storage {
    public typealias Key = String

    var containers: [Key : PersistentContainer] = [:]
    var functions: [String : StoredProcedure] = [:]

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
    enum Error: String, Swift.Error {
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
        case .none: return register(type)
        }
    }

    @discardableResult
    func register<T: Entity>(_ type: T.Type) -> Container<T> {
        let name = String(describing: type)
        let container = Container<T>(name: name, at: path, coder: coder)
        containers[Key(for: type)] = container
        return container
    }
}

// MARK: Stored procedures

extension Storage {
    public func registerFunction(
        name: String,
        body: @escaping StoredProcedure)
    {
        functions[name] = body
    }

    public func call(
        _ name: String,
        with arguments: [String : String]) throws -> Encodable?
    {
        guard let function = functions[name] else {
            return nil
        }
        return try function(arguments)
    }
}

extension Storage {
    func writeWAL() throws {
        for (_, container) in containers {
            try container.writeWAL()
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
