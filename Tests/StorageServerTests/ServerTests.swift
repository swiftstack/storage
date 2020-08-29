import Test
import HTTP
import Async
import Stream
import FileSystem
import MessagePack
import struct Foundation.UUID

@testable import Server

extension String: Swift.Error {}

final class ServerTests: TestCase {
    let temp = try! Path("/tmp/ServerTests")

    func testServer() throws {
        let storage = try Storage(at: temp.appending(#function))
        let sharedStorage = SharedStorage(for: storage)
        _ = try Server(for: sharedStorage)
    }
}
