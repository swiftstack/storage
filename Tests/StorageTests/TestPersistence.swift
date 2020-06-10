import Test
import FileSystem
@testable import Storage

final class PersistenceTests: TestCase {
    let temp = try! Path("/tmp/PersistenceTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testContainerWriteLog() throws {
        struct User: Entity, Equatable {
            let name: String

            var id: String { return name }
        }

        let path = try temp.appending(#function)

        typealias Container = Storage.Container

        let container = Container<User>(
            name: "User",
            at: path,
            coder: JsonCoder())

        let user = User(name: "user")
        let guest = User(name: "guest")
        let admin = User(name: "admin")

        scope {
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

        scope {
            try container.writeLog()
            expect(container.undo.items.count == 0)
            expect(container.remove(guest.id) == guest)
            expect(container.undo.items.count == 1)
            try container.writeLog()
        }

        scope {
            let path = try path.appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Reader<User>(from: file)
            var records = [WAL.Record<User>]()
            while let next = try wal.readNext() {
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

    func testContainerRecoveryFromLog() {
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

        scope {
            let path = try temp.appending(#function).appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Writer<User>(to: file)
            try records.forEach(wal.append)
        }

        scope {
            let storage = try Storage(at: temp.appending(#function))
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 2)
            expect(users.get("guest") == nil)
            let user = users.get("user")
            expect(user?.name == "user")
        }
    }

    func testContainerSnapshot() throws {
        struct User: Entity {
            let name: String
            var id: String {
                return name
            }
        }

        let path = try temp.appending(#function)
        let dataPath = try path.appending("User")

        scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try storage.writeLog()

            let log = try File.Name("log")
            expect(File.isExists(name: log, at: dataPath))

            try storage.makeSnapshot()

            let snapshot = try File.Name("snapshot")
            expect(File.isExists(name: snapshot, at: dataPath))
            expect(!File.isExists(name: log, at: dataPath))
        }

        scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 3)
        }
    }

    func testContainerSnapshotWithoutWAL() throws {
        struct User: Entity {
            let name: String
            var id: String {
                return name
            }
        }

        let path = try temp.appending(#function)

        scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try storage.makeSnapshot()
        }

        let containerPath = try path.appending("User")
        let snapshot = try File.Name("snapshot")
        expect(File.isExists(name: snapshot, at: containerPath))

        scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            expect(users.count == 0)
        }
    }
}


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
