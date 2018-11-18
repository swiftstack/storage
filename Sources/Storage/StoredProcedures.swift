public typealias Result = Encodable?
public typealias StoredProcedure = (Decoder?) throws -> Result

public final class StoredProcedures {
    let storage: Storage
    var items: [String : StoredProcedure]

    public enum Error: String, Swift.Error {
        case notFound = "procedure not found"
        case missingDecoder = "the procedure requires decoder"
    }

    public init(for storage: Storage) {
        self.storage = storage
        self.items = [:]
    }

    public func register<T: Entity>(
        name: String,
        requires container: T.Type,
        body: @escaping (Storage.Container<T>) throws -> Result)
    {
        items[name] = { [unowned self] _ in
            let container = try self.storage.container(for: container)
            return try body(container)
        }
    }

    public func register<Arguments: Decodable, T: Entity>(
        name: String,
        arguments: Arguments.Type,
        requires container: T.Type,
        body: @escaping (Arguments, Storage.Container<T>) throws -> Result)
    {
        func unwrapDecoder(_ decoder: Decoder?) throws -> Decoder {
            guard let decoder = decoder else {
                throw Error.missingDecoder
            }
            return decoder
        }
        items[name] = { [unowned self] decoder in
            let decoder = try unwrapDecoder(decoder)
            let arguments = try Arguments(from: decoder)
            let container = try self.storage.container(for: container)
            return try body(arguments, container)
        }
    }

    public func call(
        _ name: String,
        using decoder: Decoder?) throws -> Result
    {
        switch items[name] {
        case .none: throw Error.notFound
        case .some(let function): return try function(decoder)
        }
    }
}
