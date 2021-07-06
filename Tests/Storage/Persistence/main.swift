import Test
import FileSystem

@testable import Storage

test.case("container write log") {
    struct User: Entity, Equatable {
        let name: String

        var id: String { return name }
    }

    try await withTempPath { path in
        typealias Container = Storage.Container

        let container = Container<User>(
            name: "User",
            at: path,
            coder: TestCoder())

        let user = User(name: "user")
        let guest = User(name: "guest")
        let admin = User(name: "admin")

        await scope {
            try container.insert(user)
            try container.insert(guest)
            try container.insert(admin)
            let expected: [User.Key : Container<User>.Undo.Action] = [
                user.id : .delete,
                guest.id : .delete,
                admin.id : .delete,
            ]
            expect(container.undo.items.count == expected.count)
            for (key, value) in expected {
                expect(container.undo.items[key] == value)
            }
        }

        await scope {
            try await container.writeLog()
            expect(container.undo.items.count == 0)
            expect(container.remove(guest.id) == guest)
            expect(container.undo.items.count == 1)
            try await container.writeLog()
        }

        await scope {
            let path = try path.appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Reader<User>(from: file, decoder: TestCoder())
            var records = [WAL.Record<User>]()
            while let next = try await wal.readNext() {
                records.append(next)
            }
            expect(records.sorted(by: id) == [
                .upsert(user),
                .upsert(guest),
                .upsert(admin),
                .delete(guest.id)
            ].sorted(by: id))
        }
    }
}

test.case("container recovery from log") {
    struct User: Entity, Equatable {
        let name: String
        var id: String {
            return name
        }
    }

    let user = User(name: "user")
    let guest = User(name: "guest")
    let admin = User(name: "admin")

    let records: [WAL.Record<User>] = [
        .upsert(user),
        .upsert(guest),
        .upsert(admin),
        .delete(guest.id)
    ]

    try await withTempPath { path in
        await scope {
            let path = try path.appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Writer<User>(to: file, encoder: TestCoder())
            for record in records {
                try await wal.append(record)
            }
            try await wal.flush()
        }

        await scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try await storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 2)
            expect(users.get("guest") == nil)
            let user = users.get("user")
            expect(user?.name == "user")
        }
    }
}

test.case("container snapshot") {
    struct User: Entity {
        let name: String
        var id: String {
            return name
        }
    }

    try await withTempPath { path in
        await scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try await storage.writeLog()

            let log = try File.Name("log")
            let dataPath = try path.appending("User")
            expect(File.isExists(name: log, at: dataPath))

            try await storage.makeSnapshot()

            let snapshot = try File.Name("snapshot")
            expect(File.isExists(name: snapshot, at: dataPath))
            expect(!File.isExists(name: log, at: dataPath))
        }

        await scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try await storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 3)
        }
    }
}

test.case("container snapshot without wal") {
    struct User: Entity {
        let name: String
        var id: String {
            return name
        }
    }

    try await withTempPath { path in
        await scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try await storage.makeSnapshot()
        }

        let containerPath = try path.appending("User")
        let snapshot = try File.Name("snapshot")
        expect(File.isExists(name: snapshot, at: containerPath))

        await scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try await storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 0)
        }
    }
}

test.run()

// MARK: utils

// Sort WAL records
func id<T>(lhs: WAL.Record<T>, rhs: WAL.Record<T>) -> Bool
    where T.Key: Comparable
{
    switch (lhs, rhs) {
    case let (.upsert(lhse), .upsert(rhse)): return lhse.id < rhse.id
    case let (.delete(lhsk), .delete(rhsk)): return lhsk < rhsk
    case let (.upsert(lhse), .delete(rhsk)): return lhse.id < rhsk
    case let (.delete(lhsk), .upsert(rhse)): return lhsk < rhse.id
    }
}
