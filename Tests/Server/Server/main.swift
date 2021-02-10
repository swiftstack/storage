import Test
import HTTP
import Stream
import FileSystem
import MessagePack

@testable import Server

test.case("server") {
    let path = try Path("/tmp/Tests/Storage/Server")

    let storage = try Storage(at: path)
    let sharedStorage = SharedStorage(for: storage)
    _ = try Server(for: sharedStorage)

    try Directory.remove(at: path)
}

test.run()
