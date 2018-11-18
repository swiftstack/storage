import File

protocol PersistentContainer {
    var isDirty: Bool { get }

    func restore() throws
    func writeLog() throws
    func makeSnapshot() throws
}

extension Storage.Container: PersistentContainer {

    var isDirty: Bool {
        return undo.items.count > 0
    }

    // MARK: Log

    var logPath: Path { return path.appending(name) }
    var logName: String { return "log" }
    var logBackupName: String { return "log.backup" }

    func writeLog() throws {
        let log = try File(name: logName, at: logPath)
        let writer = try WAL.Writer<T>(to: log, encoder: coder)
        for (key, action) in undo.items {
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
        undo.removeAll()
    }

    // MARK: Snapshot

    enum SnapshotError: String, Swift.Error {
        case alreadyInProgress = "Snapshot is already in progress"
    }

    var snapshotPath: Path { return path.appending(name) }
    var snapshotName: String { return "snapshot" }
    var snapshotTempName: String { return "snapshot.temp" }

    func makeSnapshot() throws {
        try startNewLog()
        let snapshot = try File(name: snapshotTempName, at: snapshotPath)
        let writer = try Snapshot.Writer<T>(to: snapshot, encoder: coder)
        try writer.write(header: .init(name: name, count: items.count))
        for (key, entity) in items {
            switch undo.items[key] {
            case .some(.delete): continue
            case .some(.restore(let value)): try writer.write(value)
            case .none: try writer.write(entity)
            }
        }
        try writer.flush()
        try snapshot.close()
        try replaceSnapshot()
        try removeLog()
    }

    func startNewLog() throws {
        guard !File.isExists(at: logPath.appending(logBackupName)) else {
            throw SnapshotError.alreadyInProgress
        }

        let log = try File(name: logName, at: logPath)
        if log.isExists {
            try log.rename(to: logBackupName)
        }
    }

    func removeLog() throws {
        let logBackup = try File(name: logBackupName, at: logPath)
        if logBackup.isExists {
            try logBackup.remove()
        }
    }

    func replaceSnapshot() throws {
        let oldSnapshot = try File(name: snapshotName, at: snapshotPath)
        let newSnapshot = try File(name: snapshotTempName, at: snapshotPath)
        if oldSnapshot.isExists {
            try oldSnapshot.remove()
        }
        try newSnapshot.rename(to: snapshotName)
    }

    // MARK: Restore

    func restore() throws {
        try restoreSnapshot(name: snapshotName, at: snapshotPath)
        try restoreLog(name: logBackupName, at: logPath)
        try restoreLog(name: logName, at: logPath)
    }

    func restoreSnapshot(name: String, at path: Path) throws {
        let snapshot = try File(name: name, at: path)
        if snapshot.isExists {
            let reader = try Snapshot.Reader<T>(from: snapshot, decoder: coder)
            let _ = try reader.readHeader()
            while let next = try reader.readNext() {
                items[next.id] = next
            }
        }
    }

    func restoreLog(name: String, at path: Path) throws {
        let log = try File(name: name, at: path)
        if log.isExists {
            let reader = try WAL.Reader<T>(from: log, decoder: coder)
            while let record = try reader.readNext() {
                switch record {
                case .upsert(let entity): items[entity.id] = entity
                case .delete(let key): items[key] = nil
                }
            }
        }
    }
}
