import Test
import File
import Fiber

@testable import Async
@testable import Storage

final class SharedStorageTests: TestCase {
    let temp = Path("/tmp/SharedStorageTests")

    override func setUp() {
        async.setUp(Fiber.self)
    }

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testInit() {
        scope {
            let storage = try Storage(at: temp.appending(#function))
            assertNotNil(storage)
        }
    }

    func testSharedStorage() {
        struct Counter: Codable, Equatable, Entity {
            let id: String
            var value: Int
        }

        scope {
            let storage = try Storage(at: self.temp.appending(#function))
            let container = try storage.container(for: Counter.self)
            try container.insert(Counter(id: "counter", value: 0))

            let shared = SharedStorage(for: storage)

            shared.registerProcedure(name: "increment", requires: Counter.self)
            { container -> Counter? in
                guard var counter = container.get("counter") else {
                    return nil
                }
                counter.value += 1
                try container.upsert(counter)
                return counter
            }

            shared.registerProcedure(name: "read", requires: Counter.self)
            { container in
                return container.get("counter")
            }

            async.task {
                scope {
                    let result = try shared.call("increment")
                    guard let counter = result as? Counter else {
                        fail()
                        return
                    }
                    assertEqual(counter, Counter(id: "counter", value: 1))
                }
            }

            async.task {
                scope {
                    let result = try shared.call("increment")
                    guard let counter = result as? Counter else {
                        fail()
                        return
                    }
                    assertEqual(counter, Counter(id: "counter", value: 2))
                }
                async.loop.terminate()
            }
        }

        async.loop.run()

        scope {
            let walDirectory = temp.appending(#function).appending("Counter")
            let walFile = try File(name: "log", at: walDirectory)
            let reader = try WAL.Reader<Counter>(from: walFile)
            var records = [WAL.Record<Counter>]()
            while let record = try reader.readNext() {
                records.append(record)
            }
            assertEqual(records.count, 1)
            assertEqual(records, [.upsert(.init(id: "counter", value: 2))])
        }
    }
}
