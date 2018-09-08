import Stream

public protocol StreamEncoder {
    func write(_ action: Encodable, to writer: StreamWriter) throws
}

public protocol StreamDecoder {
    func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader
    ) throws -> T?

    func next(
        _ type: Decodable.Type,
        from reader: StreamReader
    ) throws -> Decodable?
}

public typealias TypeAccessor = (Storage.Key) throws -> Codable.Type

public protocol AnyDecodable {
    init(from decoder: Decoder, typeAccessor: TypeAccessor) throws
}

public protocol StreamAnyDecoder {
    init(typeAccessor: @escaping TypeAccessor)
    func next<T: AnyDecodable>(from reader: StreamReader) throws -> T?
}

public  protocol StreamCoder: StreamEncoder & StreamDecoder & StreamAnyDecoder {}
