import Stream

public protocol StreamEncoder {
    func write<T>(_ action: T, to writer: StreamWriter) async throws
        where T: Encodable
}

public protocol StreamDecoder {
    func next<T>(_ type: T.Type, from reader: StreamReader) async throws -> T?
        where T: Decodable
}

public  protocol StreamCoder: StreamEncoder & StreamDecoder {}
