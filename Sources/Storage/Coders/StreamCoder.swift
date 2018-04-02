import Stream

protocol StreamEncoder {
    func write(_ action: Encodable, to writer: StreamWriter) throws
}

protocol StreamDecoder {
    func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader
    ) throws -> T?

    func next(
        _ type: Decodable.Type,
        from reader: StreamReader
    ) throws -> Decodable?
}

typealias TypeAccessor = (Storage.Key) throws -> Codable.Type

protocol AnyDecodable {
    init(from decoder: Decoder, typeAccessor: TypeAccessor) throws
}

protocol StreamAnyDecoder {
    init(typeAccessor: @escaping TypeAccessor)
    func next<T: AnyDecodable>(from reader: StreamReader) throws -> T?
}

protocol StreamCoder: StreamEncoder & StreamDecoder & StreamAnyDecoder {}
