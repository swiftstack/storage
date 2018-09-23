import File

protocol ContainerProtocol {
    var count: Int { get }

    func restore() throws
    func writeWAL() throws
    func makeSnapshot() throws
}

extension Storage.Container: ContainerProtocol {
    func restore() throws {
        let snapshot = File(name: "snapshot", at: path.appending(name))
        if snapshot.isExists {
            let reader = try Snapshot.Reader<T>(from: snapshot, decoder: coder)
            let _ = try reader.readHeader()
            while let next = try reader.readNext() {
                items[next.id] = next
            }
        }

        let wal = File(name: "wal", at: path.appending(name))
        if wal.isExists {
            let reader = try WAL.Reader<T>(from: wal, decoder: coder)
            while let record = try reader.readNext() {
                switch record {
                case .upsert(let entity): items[entity.id] = entity
                case .delete(let key): items[key] = nil
                }
            }
        }
    }

    func writeWAL() throws {
        let wal = File(name: "wal", at: path.appending(name))
        let writer = try WAL.Writer<T>(to: wal, encoder: coder)
        for (key, action) in backup.items {
            switch action {
            case .delete:
                switch items[key] {
                case .some(let entity):
                    try writer.append(.upsert(entity))
                case .none:
                    break
                }
            case .restore:
                switch items[key] {
                case .some(let entity):
                    try writer.append(.upsert(entity))
                case .none:
                    try writer.append(.delete(key))
                }
            }
        }
        backup.removeAll()
    }

    func makeSnapshot() throws {
        let snapshot = File(name: "snapshot", at: path.appending(name))
        let writer = try Snapshot.Writer<T>(to: snapshot, encoder: coder)
        try writer.write(header: .init(name: name, count: count))
        for (key, entity) in items {
            switch backup.getLatestPersistentValue(forKey: key) {
            case .some(let value): try writer.write(value)
            case .none: try writer.write(entity)
            }
        }
        try writer.flush()
    }
}
