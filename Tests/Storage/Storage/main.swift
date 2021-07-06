import Test
import FileSystem

@testable import Storage

test.case("init") {
    try withTempPath { path in
        _ = try Storage(at: path)
    }
}

final class Class: Entity {
    let id: String

    static func == (lhs: Class, rhs: Class) -> Bool {
        return lhs.id == rhs.id
    }
}

test.case("ClassType") {
    try withTempPath { path in
        let storage = try Storage(at: path)
        expect(throws: Storage.Error.invalidKind) {
            try storage.container(for: Class.self)
        }
    }
}

test.case("Storage") {
    try withTempPath { path in
        let storage = try Storage(at: path)
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
}

test.case("storage.isDirty") {
    try withTempPath { path in
        let storage = try Storage(at: path)
        struct User: Entity {
            var id: String
        }
        expect(storage.isDirty == false)
        try storage.container(for: User.self).insert(User(id: "first"))
        expect(storage.isDirty == true)
    }
}

test.case("Container") {
    try withTempPath { path in
        let storage = try Storage(at: path)
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

test.run()
