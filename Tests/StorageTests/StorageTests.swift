import Test
import FileSystem

@testable import Storage

final class StorageTests: TestCase {
    let temp = try! Path("/tmp/StorageTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() throws {
        _ = try Storage(at: temp.appending(#function))
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

    func testClassType() throws {
        let storage = try Storage(at: temp.appending(#function))
        expect(throws: Storage.Error.invalidKind) {
            try storage.container(for: Class.self)
        }
    }

    func testStorage() throws {
        let storage = try Storage(at: temp.appending(#function))
        struct User: Entity {
            let id: String
        }
        expect(storage.containers.count == 0)
        let users1 = try storage.container(for: User.self)
        expect(storage.containers.count == 1)
        let users2 = try storage.container(for: User.self)
        expect(storage.containers.count == 1)
        let pointer1 = Unmanaged.passUnretained(users1).toOpaque()
        let pointer2 = Unmanaged.passUnretained(users2).toOpaque()
        expect(pointer1 == pointer2)
    }

    func testContainer() throws {
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
        expect(user?.name == "first")
    }
}
