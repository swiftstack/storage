public protocol StorageProtocol {
    func call(
        _ function: String,
        with arguments: [String : String]
    ) throws -> Encodable?
}
