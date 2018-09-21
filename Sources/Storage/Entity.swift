public protocol Entity: Codable, Equatable {
    associatedtype Key: Hashable & Codable
    var id: Key { get }
}
