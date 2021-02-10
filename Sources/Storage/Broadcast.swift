actor class Broadcast<T> {
    var continuations: [UnsafeContinuation<T>] = []

    func wait() async -> T {
        await withUnsafeContinuation { continutaion in
            continuations.append(continutaion)
        }
    }

    func dispatch(_ result: T) {
        // print(continuations.count, "continuations")
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }
}
