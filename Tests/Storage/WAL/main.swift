import Test
import FileSystem
@testable import Storage

test.case("wal init") {
    struct User: Entity, Equatable {
        var id: String
        let name: String
    }
    try await withTempPath(for: "init") { path in
        let wal = try File(name: "log", at: path)
        try wal.create()
        _ = try WAL.Reader<User>(from: wal, decoder: TestCoder())
    }
}

test.case("wal write") {
    struct User: Entity, Equatable {
        var id: String
        let name: String
    }

    let user = User(id: "1", name: "Tony")

    try await withTempPath(for: "write") { path in

        var wal: File {
            return try! File(name: "log", at: path)
        }

        await scope {
            let writer = try WAL.Writer<User>(to: wal, encoder: TestCoder())
            try await writer.append(.upsert(user))
        }

        await scope {
            let reader = try WAL.Reader<User>(from: wal, decoder: TestCoder())
            var records = [WAL.Record<User>]()
            while let next = try await reader.readNext() {
                records.append(next)
            }
            expect(records.count == 1)
            if let record = records.first {
                expect(record == .upsert(user))
            }
        }
    }
}

test.case("wal restore") {
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

    try await withTempPath(for: "restore") { path in
        var wal: File {
            return try! File(name: "log", at: path)
        }

        await scope {
            let writer = try WAL.Writer<User>(to: wal, encoder: TestCoder())
            for record in records {
                try await writer.append(record)
            }
        }

        await scope {
            let reader = try WAL.Reader<User>(from: wal, decoder: TestCoder())
            var records = [WAL.Record<User>]()
            while let next = try await reader.readNext() {
                records.append(next)
            }
            expect(records.count == 4)
            if records.count == 4 {
                expect(records[0] == .upsert(user))
            }
        }
    }
}

test.run()

// FIXME: move to Test
func withTempPath(for case: String, task: (Path) async throws -> Void) async throws {
    let directory = try Directory(at: "/tmp/Tests/Storage/WAL/\(`case`)")
    if directory.isExists {
        try directory.remove()
    }
    try directory.create()
    try await task(directory.path)
    try directory.remove()
}
