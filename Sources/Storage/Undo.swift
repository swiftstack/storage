struct Undo<Model: Entity> {
    enum Action {
        case delete
        case restore(Model)
    }
    var current: [Model.Key : Action] = [:]
    var pending: [Model.Key : Action] = [:]

    mutating func append(key: Model.Key, action: Action) {
        guard current[key] == nil else {
            return
        }
        current[key] = action
    }

    mutating func snapshot() {
        pending = current
        current.removeAll(keepingCapacity: true)
    }

    mutating func reset() {
        current.removeAll(keepingCapacity: true)
        pending.removeAll(keepingCapacity: true)
    }
}

extension Undo {
    func getLatestPersistentValue(forKey key: Model.Key) -> Model? {
        guard let undo = pending[key] ?? current[key] else {
            return nil
        }
        switch undo {
        case .delete: return nil
        case .restore(let model): return model
        }
    }
}
