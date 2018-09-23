import Log
import Fiber

public class SharedStorage: StorageProtocol {
    let storage: Storage
    let broadcast: Broadcast<Bool>

    public init(for storage: Storage) {
        self.storage = storage
        self.broadcast = .init()
    }

    var isNewCycle: Bool = true

    func scheduleWALWriter() {
        if isNewCycle {
            isNewCycle = false
            async.task { [unowned self] in
                // reschedule
                async.yield()
                do {
                    Log.debug("WRITING WAL")
                    try self.storage.writeWAL()
                    self.broadcast.dispatch(true)
                } catch {
                    Log.error("can't write log: \(error)")
                    self.broadcast.dispatch(false)
                }
                self.isNewCycle = true
            }
        }
    }

    func syncronized<T>(_ task: () throws -> T?) rethrows -> T? {
        scheduleWALWriter()

        let result = try task()

        guard let success = broadcast.wait() else {
            Log.error("the task was canceled")
            return nil
        }

        guard success else {
            Log.error("the task failed")
            return nil
        }

        return result
    }


    public func call(
        _ function: String,
        with arguments: [String : String]) throws -> Encodable?
    {
        return try syncronized {
            try storage.call(function, with: arguments)
        }
    }
}
