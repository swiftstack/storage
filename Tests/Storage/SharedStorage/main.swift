import Test
import Event
import FileSystem

@testable import Storage

test.case("init") {
    try withTempPath { path in
        _ = try Storage(at: path)
    }
}

test.case("SharedStorage") {
    struct Counter: Codable, Equatable, Entity {
        let id: String
        var value: Int
    }

    try await withTempPath { path in
        await scope {
            let storage = try Storage(at: path)
            let container = try storage.container(for: Counter.self)
            try container.insert(Counter(id: "counter", value: 0))

            let shared = SharedStorage(for: storage)

            await shared.registerProcedure(
                name: "increment",
                requires: Counter.self
            ) { container -> Counter? in
                guard var counter = container.get("counter") else {
                    return nil
                }
                counter.value += 1
                try container.upsert(counter)
                return counter
            }

            await shared.registerProcedure(
                name: "read",
                requires: Counter.self
            ) { container in
                return container.get("counter")
            }

            asyncTask {
                await scope {
                    let result = try await shared.call("increment")
                    guard let counter = result as? Counter else {
                        fail()
                        return
                    }
                    expect(counter == Counter(id: "counter", value: 1))
                }
            }

            let handle = asyncTask {
                await scope {
                    let result = try await shared.call("increment")
                    guard let counter = result as? Counter else {
                        fail()
                        return
                    }
                    expect(counter == Counter(id: "counter", value: 2))
                }
            }

            try await handle.value
        }

        await scope {
            let walDirectory = try path.appending("Counter")
            let walFile = try File(name: "log", at: walDirectory)
            let reader = try WAL.Reader<Counter>(from: walFile, decoder: TestCoder())
            var records = [WAL.Record<Counter>]()
            while let record = try await reader.readNext() {
                records.append(record)
            }
            expect(records.count == 1)
            expect(records == [.upsert(.init(id: "counter", value: 2))])
        }
    }
}

test.run()
