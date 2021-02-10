import FileSystem

typealias DefaultCoder = MessagePackCoder
typealias TestCoder = MessagePackCoder

extension Storage {
    convenience
    public init(at path: Path) throws {
        try self.init(at: path, coder: DefaultCoder())
    }
}
