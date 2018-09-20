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
            throw Persistence.Error.unknownType
        }
        items[item.id] = item
    }

    func play(_ record: WAL.Record) throws {
        guard let item = record.object as? T else {
            throw Persistence.Error.unknownType
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
    var iterator: IndexingIterator<Dictionary<Model.Key, Model>.Keys>

    init(for container: Storage.Container<Model>) {
        self.container = container
        self.iterator = container.items.keys.makeIterator()
    }

    mutating func next() -> Encodable? {
        guard let key = iterator.next() else {
            return nil
        }
        return container.getLatestPersistentValue(forKey: key)
    }
}
