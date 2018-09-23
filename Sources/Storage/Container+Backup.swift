extension Storage.Container {
    struct Backup {
        enum Action: Equatable {
            case delete
            case restore(Entity)
        }
        var items: [Entity.Key : Action] = [:]

        mutating func append(key: Entity.Key, action: Action) {
            guard items[key] == nil else {
                return
            }
            items[key] = action
        }

        mutating func removeAll() {
            items.removeAll(keepingCapacity: true)
        }
    }
}

extension Storage.Container.Backup {
    typealias Entity = T

    func getLatestPersistentValue(forKey key: Entity.Key) -> Entity? {
        guard let undo = items[key] else {
            return nil
        }
        switch undo {
        case .delete: return nil
        case .restore(let model): return model
        }
    }
}
