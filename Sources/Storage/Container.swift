import File

extension Storage {
    public class Container<T: Entity> {
        let name: String
        let path: Path
        let coder: StreamCoder

        var items: [T.Key: T]
        var undo = Undo<T>()

        func onInsert(newValue: T) {
            undo.append(key: newValue.id, action: .delete)
        }

        func onUpsert(oldValue: T, newValue: T) {
            undo.append(key: oldValue.id, action: .restore(oldValue))
        }

        func onDelete(oldValue: T) {
            undo.append(key: oldValue.id, action: .restore(oldValue))
        }

        init(name: String, at path: Path, coder: StreamCoder) {
            self.name = name
            self.path = path
            self.coder = coder
            self.items = [:]
        }

        var count: Int {
            return items.count
        }

        enum Error: String, Swift.Error {
            case alreadyExist = "The primary key is already exists"
            case alreadyInSnapshot
        }

        public func insert(_ value: T) throws {
            guard items[value.id] == nil else {
                throw Error.alreadyExist
            }
            onInsert(newValue: value)
            items[value.id] = value
        }

        public func get(_ key: T.Key) -> T? {
            return items[key]
        }

        public func remove(_ key: T.Key) -> T? {
            guard let deleted = items.removeValue(forKey: key) else {
                return nil
            }
            onDelete(oldValue: deleted)
            return deleted
        }

        public func upsert(_ value: T) throws {
            let result = items.removeValue(forKey: value.id)
            switch result {
            case .some(let old):
                onUpsert(oldValue: old, newValue: value)
                items[value.id] = value
            case .none:
                onInsert(newValue: value)
                items[value.id] = value
            }
        }

        // MARK: secondary keys (not implemented) / fullscan

        public func first<C>(where key: KeyPath<T, C>, equals value: C) -> T?
            where C: Comparable
        {
            return items.values.first(where: { $0[keyPath: key] == value })
        }

        public func select<C>(where key: KeyPath<T, C>, equals value: C) -> [T]
            where C: Comparable
        {
            return items.values.filter({ $0[keyPath: key] == value })
        }

        public func remove<C>(where key: KeyPath<T, C>, equals value: C) -> [T]
            where C: Comparable
        {
            return items.values.compactMap { item in
                guard item[keyPath: key] == value else {
                    return nil
                }
                return remove(item.id)
            }
        }
    }
}
