import Test
import File
@testable import Storage

final class PersistenceTests: TestCase {
    let temp = Path("/tmp/PersistenceTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testContainerWriteLog() {
        struct User: Entity, Equatable {
            let name: String

            var id: String { return name }
        }

        let path = temp.appending(#function)

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
            assertEqual(container.undo.items.count, expected.count)
            for (key, value) in expected {
                assertEqual(container.undo.items[key], value)
            }
        }

        scope {
            try container.writeLog()
            assertEqual(container.undo.items.count, 0)
            assertEqual(container.remove(guest.id), guest)
            assertEqual(container.undo.items.count, 1)
            try container.writeLog()
        }

        scope {
            let path = path.appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Reader<User>(from: file)
            var records = [WAL.Record<User>]()
            while let next = try wal.readNext() {
                records.append(next)
            }
            assertEqual(records.sorted(by: id), [
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
            let path = temp.appending(#function).appending("User")
            let file = try File(name: "log", at: path)
            let wal = try WAL.Writer<User>(to: file)
            try records.forEach(wal.append)
        }

        scope {
            let storage = try Storage(at: temp.appending(#function))
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            assertEqual(users.count, 2)
            assertNil(users.get("guest"))
            let user = users.get("user")
            assertEqual(user?.name, "user")
        }
    }

    func testContainerSnapshot() {
        struct User: Entity {
            let name: String
            var id: String {
                return name
            }
        }

        let path = temp.appending(#function)
        let dataPath = path.appending("User")

        scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try storage.writeLog()
            assertTrue(File.isExists(at: dataPath.appending("log")))

            try storage.makeSnapshot()
            assertTrue(File.isExists(at: dataPath.appending("snapshot")))
            assertFalse(File.isExists(at: dataPath.appending("log")))
        }

        scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            assertEqual(users.count, 3)
        }
    }

    func testContainerSnapshotWithoutWAL() {
        struct User: Entity {
            let name: String
            var id: String {
                return name
            }
        }

        let path = temp.appending(#function)

        scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: User.self)
            try container.insert(User(name: "first"))
            try container.insert(User(name: "second"))
            try container.insert(User(name: "third"))

            try storage.makeSnapshot()
        }

        let containerPath = path.appending("User")
        assertTrue(File.isExists(at: containerPath.appending("snapshot")))

        scope {
            let storage = try Storage(at: path)
            try storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            assertEqual(users.count, 0)
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
