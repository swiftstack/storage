import Test
import File
import Fiber

@testable import Async
@testable import Storage

final class SharedStorageTests: TestCase {
    let temp = Path(string: "/tmp/SharedStorageTests")

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

            storage.registerFunction(name: "increment")
            { arguments -> Counter? in
                guard var counter = container.get("counter") else {
                    return nil
                }
                counter.value += 1
                try container.upsert(counter)
                return counter
            }

            storage.registerFunction(name: "read") { arguments in
                return container.get("counter")
            }

            let sharedStorage = SharedStorage(for: storage)

            async.task {
                scope {
                    let result = try sharedStorage.call("increment", with: [:])
                    guard let counter = result as? Counter else {
                        fail()
                        return
                    }
                    assertEqual(counter, Counter(id: "counter", value: 1))
                }
            }

            async.task {
                scope {
                    let result = try sharedStorage.call("increment", with: [:])
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
            let walFile = File(name: "wal", at: walDirectory)
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
