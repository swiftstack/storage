import Test
import FileSystem

@testable import Storage

struct User: Entity, Equatable, Comparable {
    let id: Int
    var name: String

    init(id: Int = .random(in: (Int.min...Int.max)), name: String) {
        self.id = id
        self.name = name
    }

    static func < (lhs: User, rhs: User) -> Bool {
        return lhs.id < rhs.id
    }
}

test.case("container init") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("init"))
        let users = try storage.container(for: User.self)
        expect(users.count == 0)
    }
}

test.case("container insert") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("insert"))
        let users = try storage.container(for: User.self)
        expect(users.count == 0)
        try users.insert(User(name: "Tony"))
        expect(users.count == 1)
    }
}

test.case("container first") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("first"))
        let users = try storage.container(for: User.self)
        try users.insert(User(name: "Tony"))

        let user = users.first(where: \.name, equals: "Tony")
        expect(user?.name == "Tony")
    }
}

test.case("container select") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("select"))
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
}

test.case("container remove") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("remove"))
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
}

test.case("container update") {
    try await withTempPath { path in
        let storage = try Storage(at: path.appending("update"))
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

test.run()
