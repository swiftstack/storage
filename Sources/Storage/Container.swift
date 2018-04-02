extension Storage {
    class Container<T: Entity> {
        unowned let storage: Storage
        var items: [T.Key: T]

        var undo = Undo<T>()

        init(in storage: Storage) {
            self.storage = storage
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
            undo.append(key: value.id, action: .delete)
            items[value.id] = value
        }

        public func get(_ key: T.Key) -> T? {
            return items[key]
        }

        public func remove(_ key: T.Key) -> T? {
            guard let deleted = items.removeValue(forKey: key) else {
                return nil
            }
            undo.append(key: key, action: .restore(deleted))
            return deleted
        }

        public func upsert(_ value: T) throws {
            let result = items.removeValue(forKey: value.id)
            switch result {
            case .some(let old):
                undo.append(key: value.id, action: .restore(old))
                items[value.id] = value
            case .none:
                undo.append(key: value.id, action: .delete)
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
