import Dispatch

extension DispatchQueue {
    func await<T>(_ body: @escaping () throws -> T) async throws -> sending T {
        let box = Synchronized(body)
        return try await withCheckedThrowingContinuation { continuation in
            self.async {
                let unwrapped = box.wrappedValue
                let result = Result(catching: unwrapped)
                continuation.resume(with: result)
            }
        }
    }

    func await<T>(_ body: @escaping () -> T) async -> sending T {
        let box = Synchronized(body)
        return await withCheckedContinuation { continuation in
            self.async {
                let unwrapped = box.wrappedValue
                let result = Result(catching: unwrapped)
                continuation.resume(with: result)
            }
        }
    }

}
