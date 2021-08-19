# Storage

Swift-oriented DBMS. Embedded and Not. Yet.

## Package.swift

```swift
.package(url: "https://github.com/swiftstack/storage.git", .branch("dev"))
```

## Usage

```swift
struct User: Entity {
    let id: String
    let name: String
    var age: Int
}

let storage = try Storage(at: path)

let users = try storage.container(for: User.self)

try users.insert(User(id: "first", name: "First User", age: 17))
try users.insert(User(id: "second", name: "Second User", age: 18))
try users.insert(User(id: "third", name: "Third User", age: 19))

expect(users.count == 3)

if var second = users.get("second") {
    second.name = "New Name"
    try users.upsert(second)
}

let secondaryKeys = users.select(where: \.name, equal: "Anonymous")

let fullscan = users.select(where: { $0.age > 18 })
```
