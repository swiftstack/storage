import Test
import FileSystem
import struct Foundation.UUID

@testable import Storage

extension UUID: Comparable {
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
}

final class ContainerTests: TestCase {
    let temp = try! Path("/tmp/ContainerTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    struct User: Entity, Equatable, Comparable {
        let id: UUID
        var name: String

        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
        }

        static func < (
            lhs: ContainerTests.User,
            rhs: ContainerTests.User) -> Bool
        {
            return lhs.id < rhs.id
        }
    }

    func testInit() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        expect(users.count == 0)
    }

    func testInsert() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        expect(users.count == 0)
        try users.insert(User(name: "Tony"))
        expect(users.count == 1)
    }

    func testFirst() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        try users.insert(User(name: "Tony"))

        let user = users.first(where: \.name, equals: "Tony")
        expect(user?.name == "Tony")
    }

    func testSelect() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        let tonies = [
            User(name: "Tony"),
            User(name: "Tony")
        ]
        try users.insert(tonies[0])
        try users.insert(tonies[1])
        expect(users.count == 2)

        let result = users.select(where: \.name, equals: "Tony")
        expect(result.sorted() == tonies.sorted())
    }

    func testRemove() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        let tonies = [
            User(name: "Tony"),
            User(name: "Tony")
        ]
        try users.insert(tonies[0])
        try users.insert(tonies[1])

        let removed = users.remove(where: \.name, equals: "Tony")
        expect(removed.sorted() == tonies.sorted())
        expect(users.count == 0)
    }

    func testUpdate() throws {
        let storage = try Storage(at: temp.appending(#function))
        let users = try storage.container(for: User.self)
        let tonies = [
            User(name: "First"),
            User(name: "Second")
        ]
        try users.insert(tonies[0])
        try users.insert(tonies[1])

        guard var first = users.first(where: \.name, equals: "First") else {
            fail()
            return
        }
        first.name = "New"
        let unmodified = users.first(where: \.name, equals: "First")
        expect(unmodified?.name == "First")

        try users.upsert(first)
        let notfound = users.first(where: \.name, equals: "First")
        expect(notfound == nil)
    }
}
