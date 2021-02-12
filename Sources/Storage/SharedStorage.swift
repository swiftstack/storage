import Log
import IPC

public actor class SharedStorage {
    let storage: Storage
    let broadcast: Broadcast<Bool>
    let procedures: StoredProcedures

    public init(for storage: Storage) {
        self.storage = storage
        self.broadcast = .init()
        self.procedures = .init(for: storage)
    }

    var isNewCycle: Bool = true

    func scheduleWALWriter() {
        if isNewCycle {
            isNewCycle = false
            _ = Task.runDetached(priority: .background) {
                defer { self.isNewCycle = true }
                // move the task to the end of the loop cycle
                // so it runs after all the clients have been processed
                // yield()

                guard self.storage.isDirty else {
                    await self.broadcast.dispatch(true)
                    return
                }
                do {
                    await Log.debug("writing log")
                    try await self.storage.writeLog()
                    await self.broadcast.dispatch(true)
                } catch {
                    await Log.error("can't write log: \(error)")
                    await self.broadcast.dispatch(false)
                }
            }
        }
    }

    func syncronized<T>(_ task: () throws -> T?) async rethrows -> T? {
        scheduleWALWriter()

        let result = try task()

        let success = await broadcast.wait()

        if await Task.isCancelled() {
            await Log.error("the task was canceled")
            return nil
        }

        guard success else {
            await Log.error("the task failed")
            return nil
        }

        return result
    }

    public func call(
        _ function: String,
        using decoder: Decoder? = nil) async throws -> Result
    {
        return try await syncronized {
            return try procedures.call(function, using: decoder)
        }
    }
}

extension SharedStorage {
    public func registerProcedure<T: Entity>(
        name: String,
        requires container: T.Type,
        body: @escaping (Storage.Container<T>) throws -> Result)
    {
        procedures.register(
            name: name,
            requires: container,
            body: body)
    }

    public func registerProcedure<Arguments: Decodable, T: Entity>(
        name: String,
        arguments: Arguments.Type,
        requires container: T.Type,
        body: @escaping (Arguments, Storage.Container<T>) throws -> Result)
    {
        procedures.register(
            name: name,
            arguments: arguments,
            requires: container,
            body: body)
    }
}

extension SharedStorage {
    public func register<T: Entity>(_ type: T.Type) throws {
        try storage.register(type)
    }
}

extension SharedStorage: PersistentContainer {
    @actorIndependent var isDirty: Bool {
        return storage.isDirty
    }

    public func restore() async throws {
        try await storage.restore()
    }

    func writeLog() async throws {
        try await storage.writeLog()
    }

    func makeSnapshot() async throws {
        try await storage.makeSnapshot()
    }
}
