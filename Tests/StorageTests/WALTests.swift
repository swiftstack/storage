import Test
import FileSystem
@testable import Storage

final class WALTests: TestCase {
    let temp = try! Path("/tmp/WALTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() throws {
        struct User: Entity, Equatable {
            var id: String
            let name: String
        }
        let wal = try File(name: "log", at: temp.appending(#function))
        try wal.create()
        _ = try WAL.Reader<User>(from: wal)
    }

    func testWrite() {
        struct User: Entity, Equatable {
            var id: String
            let name: String
        }

        let user = User(id: "1", name: "Tony")

        var wal: File {
            return try! File(name: "log", at: temp.appending(#function))
        }

        scope {
            let writer = try WAL.Writer<User>(to: wal)
            try writer.append(.upsert(user))
        }

        scope {
            let reader = try WAL.Reader<User>(from: wal)
            var records = [WAL.Record<User>]()
            while let next = try reader.readNext() {
                records.append(next)
            }
            expect(records.count == 1)
            if let record = records.first {
                expect(record == .upsert(user))
            }
        }
    }

    func testRestore() {
        struct User: Entity, Equatable {
            let id: Int
            let name: String
        }

        let user = User(id: 0, name: "User")
        let guest = User(id: 1, name: "Guest")
        let admin = User(id: 2, name: "Admin")

        let records: [WAL.Record<User>] = [
            .upsert(user),
            .upsert(guest),
            .upsert(admin),
            .delete(guest.id)
        ]

        var wal: File {
            return try! File(name: "log", at: temp.appending(#function))
        }

        scope {
            let writer = try WAL.Writer<User>(to: wal)
            try records.forEach(writer.append)
        }

        scope {
            let reader = try WAL.Reader<User>(from: wal)
            var records = [WAL.Record<User>]()
            while let next = try reader.readNext() {
                records.append(next)
            }
            expect(records.count == 4)
            if records.count == 4 {
                expect(records[0] == .upsert(user))
            }
        }
    }
}

extension WAL.Reader {
    convenience
    init(from file: File) throws {
        try self.init(from: file, decoder: DefaultCoder())
    }
}

extension WAL.Writer {
    convenience
    init(to file: File) throws {
        try self.init(to: file, encoder: DefaultCoder())
    }
}
