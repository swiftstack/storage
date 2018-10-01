public enum StoredProcedure {
    case simple(() throws -> Encodable?)
    case complex((Decoder) throws -> Encodable?)
}

public final class StoredProcedures {
    let storage: Storage
    var items: [String : StoredProcedure]

    public enum Error: String, Swift.Error {
        case notFound = "procedure not found"
        case extraArguments = "simple procedure called with arguments"
        case missingArguments = "complex procedure called without arguments"
    }

    public init(for storage: Storage) {
        self.storage = storage
        self.items = [:]
    }

    public func register<T: Entity>(
        name: String,
        requires container: T.Type,
        body: @escaping (Storage.Container<T>) throws -> Encodable)
    {
        items[name] = .simple { [unowned self] in
            let container = try self.storage.container(for: container)
            return try body(container)
        }
    }

    public func register<Arguments: Decodable, T: Entity>(
        name: String,
        arguments: Arguments.Type,
        requires container: T.Type,
        body: @escaping (Arguments, Storage.Container<T>) throws -> Encodable)
    {
        items[name] = .complex { [unowned self] decoder in
            let arguments = try Arguments(from: decoder)
            let container = try self.storage.container(for: container)
            return try body(arguments, container)
        }
    }

    public func call(_ name: String) throws -> Encodable?
    {
        switch items[name] {
        case .none: throw Error.notFound
        case .some(.simple(let function)): return try function()
        case .some(.complex): throw Error.missingArguments
        }
    }

    public func call(
        _ name: String,
        using decoder: Decoder) throws -> Encodable?
    {
        switch items[name] {
        case .none: throw Error.notFound
        case .some(.simple): throw Error.extraArguments
        case .some(.complex(let function)): return try function(decoder)
        }
    }
}
