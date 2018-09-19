import File

class Persistence {
    enum Error: String, Swift.Error {
        case invalidSnapshot
        case unknownType
    }

    class Settings {
        let wal: Path
        let data: Path

        init(wal: Path, data: Path) {
            self.wal = wal
            self.data = data
        }

        convenience init(at path: Path) {
            self.init(wal: path, data: path)
        }
    }

    let storage: Storage
    let settings: Settings

    lazy var walWriter: WAL.Writer = {
        let wal = File(name: "wal", at: settings.wal)
        return WAL.Writer(to: wal, encoder: coder)
    }()

    let coderType: StreamCoder.Type

    lazy var coder: StreamCoder = {
        return coderType.init(typeAccessor: { [unowned self] key in
            guard let container = self.storage.containers[key] else {
                throw Error.unknownType
            }
            return container.type
        })
    }()

    init(for storage: Storage, settings: Settings, coder: StreamCoder.Type) {
        self.storage = storage
        self.settings = settings
        self.coderType = coder
    }

    convenience
    init(for storage: Storage, at path: Path, coder: StreamCoder.Type) {
        self.init(for: storage, settings: .init(at: path), coder: coder)
    }

    func makeSnapshot() throws {
        let snapshot = File(name: "snapshot", at: settings.data)
        let writer = try Snapshot.Writer(to: snapshot, encoder: coder)
        for (key, container) in storage.containers {
            try writer.write(header: .init(name: key, count: container.count))
            var iterator = container.makeSnapshotIterator()
            while let next = iterator.next() {
                try writer.write(next)
            }
        }
        try writer.flush()
    }

    func restore() throws {
        let snapshot = File(name: "snapshot", at: settings.data)
        let wal = File(name: "wal", at: settings.wal)

        if snapshot.isExists {
            let reader = try Snapshot.Reader(from: snapshot, decoder: coder)
            while let header = try reader.readHeader() {
                guard let container = storage.containers[header.name] else {
                    throw Error.unknownType
                }
                for _ in 0..<header.count {
                    guard let item = try reader.readNext(container.type) else {
                        throw Error.invalidSnapshot
                    }
                    try container.restore(item)
                }
            }
        }

        if wal.isExists {
            let reader = WAL.Reader(from: wal, decoder: coder)
            let interator = try reader.makeRecoveryIterator()
            while let next = interator.next() {
                guard let container = storage.containers[next.key] else {
                    throw Error.unknownType
                }
                try container.play(next)
            }
        }
    }
}
