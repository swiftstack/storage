import File

typealias DefaultCoder = JsonCoder

extension Storage {
    convenience
    init(at path: Path) throws {
        try self.init(at: path, coder: DefaultCoder.self)
    }
}
