import Test
import File

@testable import Storage

final class StorageTests: TestCase {
    let temp = Path(string: "/tmp/StorageTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            assertNotNil(storage)
        }
    }

    func testClassType() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            class User: Entity { let id: String = "" }
            assertThrowsError(try storage.container(for: User.self)) { error in
                assertEqual(error as? Storage.Error, .invalidKind)
            }
        }
    }

    func testStorage() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            struct User: Entity {
                let id: String
            }
            assertEqual(storage.containers.count, 0)
            let users1 = try storage.container(for: User.self)
            assertEqual(storage.containers.count, 1)
            let users2 = try storage.container(for: User.self)
            assertEqual(storage.containers.count, 1)
            let pointer1 = Unmanaged.passUnretained(users1).toOpaque()
            let pointer2 = Unmanaged.passUnretained(users2).toOpaque()
            assertEqual(pointer1, pointer2)
        }
    }

    func testStoragePersistence() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            struct User: Entity {
                let name: String
                var id: String {
                    return name
                }
            }
            try storage.container(for: User.self).insert(User(name: "first"))
            let users = try storage.container(for: User.self)
            let user = users.get("first")
            assertEqual(user?.name, "first")
        }
    }

    func testRecovery() {
        struct User: Entity, Equatable {
            let name: String
            var id: String {
                return name
            }
        }

        let user = User(name: "user")
        let guest = User(name: "guest")
        let admin = User(name: "admin")

        let usersKey = Storage.Key(for: User.self)

        let records: [WAL.Record] = [
            .init(key: usersKey, action: .insert, object: user),
            .init(key: usersKey, action: .insert, object: guest),
            .init(key: usersKey, action: .insert, object: admin),
            .init(key: usersKey, action: .remove, object: guest)
        ]

        scope {
            let file = File(name: "wal", at: temp.appending(#function))
            let wal = try WAL.Writer(to: file)
            try wal.open()
            try records.forEach(wal.append)
        }

        scope {
            let storage = try Storage(at: temp.appending(#function))
            storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            assertEqual(users.count, 2)
            assertNil(users.get("guest"))
            let user = users.get("user")
            assertEqual(user?.name, "user")
        }
    }

    func testSnapshot() {
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

        assertTrue(File.isExists(at: path.appending("snapshot")))

        scope {
            let storage = try Storage(at: path)
            storage.register(User.self)
            try storage.restore()

            let users = try storage.container(for: User.self)
            assertEqual(users.count, 3)
        }
    }
}
