import Test
import File

@testable import Storage

final class StorageTests: TestCase {
    let temp = Path("/tmp/StorageTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            assertNotNil(storage)
        }
    }

    final class Class: Entity {
        let id: String = ""

        static func == (
            lhs: StorageTests.Class,
            rhs: StorageTests.Class) -> Bool
        {
            return lhs.id == rhs.id
        }
    }

    func testClassType() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            assertThrowsError(try storage.container(for: Class.self)) { error in
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

    func testContainer() {
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
}
