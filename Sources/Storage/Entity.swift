protocol Entity: Codable {
    associatedtype Key: Hashable
    var id: Key { get }
}
