import Test
import HTTP
import Stream
import FileSystem
import MessagePack

@testable import Server

test.case("server") {
    try await withTempPath { path in
        let storage = try Storage(at: path)
        let sharedStorage = SharedStorage(for: storage)
        _ = try Server(for: sharedStorage)
    }
}

test.run()
