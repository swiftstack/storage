import FileSystem

protocol PersistentContainer {
    var isDirty: Bool { get }

    func restore() async throws
    func writeLog() async throws
    func makeSnapshot() async throws
}

extension Storage.Container: PersistentContainer {

    var isDirty: Bool {
        return undo.items.count > 0
    }

    // MARK: Log

    var logPath: Path { try! path.appending(name) }
    var logName: File.Name { try! .init("log") }
    var logBackupName: File.Name { try! .init("log.backup") }

    func writeLog() async throws {
        let log = File(name: logName, at: logPath)
        let writer = try WAL.Writer<T>(to: log, encoder: coder)
        for (key, action) in undo.items {
            switch action {
            case .delete:
                switch items[key] {
                case .some(let entity):
                    try await writer.append(.upsert(entity))
                case .none:
                    break
                }
            case .restore:
                switch items[key] {
                case .some(let entity):
                    try await writer.append(.upsert(entity))
                case .none:
                    try await writer.append(.delete(key))
                }
            }
        }
        undo.removeAll()
    }

    // MARK: Snapshot

    enum SnapshotError: String, Swift.Error {
        case alreadyInProgress = "Snapshot is already in progress"
    }

    var snapshotPath: Path { try! path.appending(name) }
    var snapshotName: File.Name { try! .init("snapshot") }
    var snapshotTempName: File.Name { try! .init("snapshot.temp") }

    func makeSnapshot() async throws {
        try startNewLog()
        let snapshot = File(name: snapshotTempName, at: snapshotPath)
        let writer = try Snapshot.Writer<T>(to: snapshot, encoder: coder)
        try await writer.write(header: .init(name: name, count: items.count))
        for (key, entity) in items {
            switch undo.items[key] {
            case .some(.delete): continue
            case .some(.restore(let value)): try await writer.write(value)
            case .none: try await writer.write(entity)
            }
        }
        try await writer.flush()
        try snapshot.close()
        try replaceSnapshot()
        try removeLog()
    }

    func startNewLog() throws {
        guard !File.isExists(name: logBackupName, at: logPath) else {
            throw SnapshotError.alreadyInProgress
        }

        let log = File(name: logName, at: logPath)
        if log.isExists {
            try log.rename(to: logBackupName)
        }
    }

    func removeLog() throws {
        let logBackup = File(name: logBackupName, at: logPath)
        if logBackup.isExists {
            try logBackup.remove()
        }
    }

    func replaceSnapshot() throws {
        let oldSnapshot = File(name: snapshotName, at: snapshotPath)
        let newSnapshot = File(name: snapshotTempName, at: snapshotPath)
        if oldSnapshot.isExists {
            try oldSnapshot.remove()
        }
        try newSnapshot.rename(to: snapshotName)
    }

    // MARK: Restore

    func restore() async throws {
        try await restoreSnapshot(name: snapshotName, at: snapshotPath)
        try await restoreLog(name: logBackupName, at: logPath)
        try await restoreLog(name: logName, at: logPath)
    }

    func restoreSnapshot(name: File.Name, at path: Path) async throws {
        let snapshot = File(name: name, at: path)
        if snapshot.isExists {
            let reader = try Snapshot.Reader<T>(from: snapshot, decoder: coder)
            let _ = try await reader.readHeader()
            while let next = try await reader.readNext() {
                items[next.id] = next
            }
        }
    }

    func restoreLog(name: File.Name, at path: Path) async throws {
        let log = File(name: name, at: path)
        if log.isExists {
            let reader = try WAL.Reader<T>(from: log, decoder: coder)
            while let record = try await reader.readNext() {
                switch record {
                case .upsert(let entity): items[entity.id] = entity
                case .delete(let key): items[key] = nil
                }
            }
        }
    }
}
