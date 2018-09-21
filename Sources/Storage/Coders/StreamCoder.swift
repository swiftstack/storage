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

public  protocol StreamCoder: StreamEncoder & StreamDecoder {}
