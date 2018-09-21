import File

typealias DefaultCoder = JsonCoder

extension Storage {
    convenience
    public init(at path: Path) throws {
        try self.init(at: path, coder: DefaultCoder())
    }
}
