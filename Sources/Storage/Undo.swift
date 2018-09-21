struct Undo<Model: Entity> {
    enum Action: Equatable {
        case delete
        case restore(Model)
    }
    var items: [Model.Key : Action] = [:]

    mutating func append(key: Model.Key, action: Action) {
        guard items[key] == nil else {
            return
        }
        items[key] = action
    }

    mutating func reset() {
        items.removeAll(keepingCapacity: true)
    }
}

extension Undo {
    func getLatestPersistentValue(forKey key: Model.Key) -> Model? {
        guard let undo = items[key] else {
            return nil
        }
        switch undo {
        case .delete: return nil
        case .restore(let model): return model
        }
    }
}
