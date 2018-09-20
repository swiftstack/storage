import Test
import File
@testable import Storage

final class WALTests: TestCase {
    let temp = Path(string: "/tmp/WALTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() {
        scope {
            let wal = File(name: "wal", at: temp.appending(#function))
            let reader = try WAL.Reader(from: wal)
            assertNotNil(reader)
        }
    }

    func testWrite() {
        struct User: Codable, Equatable {
            let name: String
        }

        let user = User(name: "Tony")

        var wal: File {
            return File(name: "wal", at: temp.appending(#function))
        }

        scope {
            let writer = try WAL.Writer(to: wal)
            try writer.open()

            let record = WAL.Record(
                key: "User",
                action: .upsert,
                object: user)

            try writer.append(record)

            assertNotNil(wal)
        }

        scope {
            let reader = try WAL.Reader(from: wal) { _ in
                return User.self
            }
            let iterator = try reader.makeRecoveryIterator()
            var records = [WAL.Record]()
            while let next = iterator.next() {
                records.append(next)
            }
            assertEqual(records.count, 1)
            if let record = records.first {
                assertEqual(record.key, "User")
                assertEqual(record.action, .upsert)
                assertEqual(record.object as? User, user)
            }
        }
    }

    func testRestore() {
        struct User: Codable, Equatable {
            let name: String
        }

        let user = User(name: "User")
        let guest = User(name: "Guest")
        let admin = User(name: "Admin")

        let records: [WAL.Record] = [
            .init(key: "Users", action: .upsert, object: user),
            .init(key: "Users", action: .upsert, object: guest),
            .init(key: "Users", action: .upsert, object: admin),
            .init(key: "Users", action: .remove, object: guest)
        ]

        var wal: File {
            return File(name: "wal", at: temp.appending(#function))
        }

        scope {
            let writer = try WAL.Writer(to: wal)
            try writer.open()
            try records.forEach(writer.append)
        }

        scope {
            let wal = try WAL.Reader(from: wal) { _ in
                return User.self
            }
            let iterator = try wal.makeRecoveryIterator()
            assertNotNil(iterator)
            var records = [WAL.Record]()
            while let next = iterator.next() {
                records.append(next)
            }
            assertEqual(records.count, 4)
            if records.count == 4 {
                assertEqual(records[0].key, "Users")
                assertEqual(records[0].action, .upsert)
                assertEqual(records[0].object as? User, user)
            }
        }
    }
}

extension WAL.Reader {
    convenience
    init(from file: File, typeAccessor: TypeAccessor? = nil) throws {
        let typeAccessor: TypeAccessor = typeAccessor ?? { _ in fatalError() }
        self.init(from: file, decoder: DefaultCoder(typeAccessor: typeAccessor))
    }
}

extension WAL.Writer {
    convenience
    init(to file: File) throws {
        self.init(to: file, encoder: DefaultCoder { _ in fatalError() })
    }
}
