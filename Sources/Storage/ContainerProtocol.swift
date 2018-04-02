protocol ContainerProtocol {
    var count: Int { get }
    var type: Codable.Type { get }
    func restore(_ item: Decodable) throws
    func play(_ record: WAL.Record) throws

    func makeSnapshotIterator() -> SnapshotIteratorProtocol
}

protocol SnapshotIteratorProtocol {
    mutating func next() -> Encodable?
}

extension Storage.Container: ContainerProtocol {
    var type: Codable.Type {
        return T.self
    }

    func restore(_ item: Decodable) throws {
        guard let item = item as? T else {
            throw Storage.Error.unknownType
        }
        items[item.id] = item
    }

    func play(_ record: WAL.Record) throws {
        guard let item = record.object as? T else {
            throw Storage.Error.unknownType
        }
        switch record.action {
        case .insert, .upsert:
            items[item.id] = item
        default:
            items[item.id] = nil
        }
    }

    // MARK: make snapshot

    func getLatestPersistentValue(forKey key: T.Key) -> T? {
        return undo.getLatestPersistentValue(forKey: key) ?? items[key]
    }

    func makeSnapshotIterator() -> SnapshotIteratorProtocol {
        return SnapshotIterator(for: self)
    }
}

struct SnapshotIterator<Model: Entity>: SnapshotIteratorProtocol {
    let container: Storage.Container<Model>
    var keys: [Model.Key]
    var position: Int = 0

    init(for container: Storage.Container<Model>) {
        self.container = container
        self.keys = [Model.Key](container.items.keys)
    }

    mutating func next() -> Encodable? {
        guard position < keys.count else {
            return nil
        }
        defer { position += 1 }
        return container.getLatestPersistentValue(forKey: keys[position])
    }
}
