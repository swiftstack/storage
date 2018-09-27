extension Storage.Container {
    struct Undo {
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

extension Storage.Container.Undo {
    mutating func onInsert(newValue: T) {
        append(key: newValue.id, action: .delete)
    }

    mutating func onUpsert(oldValue: T, newValue: T) {
        append(key: oldValue.id, action: .restore(oldValue))
    }

    mutating func onDelete(oldValue: T) {
        append(key: oldValue.id, action: .restore(oldValue))
    }
}
