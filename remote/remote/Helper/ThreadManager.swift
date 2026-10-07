import Foundation

public enum ThreadManager {
    
    public static let backgroundQueue = DispatchQueue(label: "com.iOS.tvRemoteDemo.threadmanager.background", qos: .userInitiated)
    
    public static let heavyWorkQueue = DispatchQueue(label: "com.iOS.tvRemoteDemo.threadmanager.heavy", qos: .utility)

    /// High-priority serial queue reserved for the frame the user is currently looking at
    /// (interactive scrub display decode / seed). Kept separate from `heavyWorkQueue` so the
    /// current-position decode never waits behind background prefetch / warm-cache work.
    public static let scrubDisplayQueue = DispatchQueue(label: "com.iOS.tvRemoteDemo.threadmanager.scrubdisplay", qos: .userInteractive)

    public static let serialSyncQueue = DispatchQueue(label: "com.iOS.tvRemoteDemo.threadmanager.serial")
    
    public static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
    
    public static func onMain(after delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    
    public static func onMainSync<T>(_ work: () throws -> T) rethrows -> T {
        if Thread.isMainThread {
            return try work()
        }
        return try DispatchQueue.main.sync(execute: work)
    }
    
    public static func onBackground(_ work: @escaping () -> Void) {
        backgroundQueue.async(execute: work)
    }
    
    public static func onBackground(thenOnMain completion: @escaping () -> Void, background work: @escaping () -> Void) {
        backgroundQueue.async {
            work()
            onMain(completion)
        }
    }
    
    public static func onHeavyBackground(_ work: @escaping () -> Void) {
        heavyWorkQueue.async(execute: work)
    }

    /// Runs interactive-priority display decode work off the main thread on `scrubDisplayQueue`.
    public static func onScrubDisplay(_ work: @escaping () -> Void) {
        scrubDisplayQueue.async(execute: work)
    }
    
    public static func onGlobal(qos: DispatchQoS.QoSClass = .userInitiated, _ work: @escaping () -> Void) {
        DispatchQueue.global(qos: qos).async(execute: work)
    }
    
    @discardableResult
    public static func after(_ delay: TimeInterval, on queue: DispatchQueue = .main, _ work: @escaping () -> Void) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: work)
        queue.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }
    
    public static func delay(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    public static func runAsync<T>(
        on queue: DispatchQueue = ThreadManager.backgroundQueue,
        work: @escaping () throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        queue.async {
            let result: Result<T, Error>
            do {
                result = .success(try work())
            } catch {
                result = .failure(error)
            }
            onMain { completion(result) }
        }
    }
    
    @MainActor
    public static func runOnMainActor<T>(_ work: @escaping () async throws -> T) async rethrows -> T {
        try await work()
    }
    
    public static func sync<T>(_ work: () throws -> T) rethrows -> T {
        try serialSyncQueue.sync(execute: work)
    }
    
    public static func debounce(interval: TimeInterval, queue: DispatchQueue = .main, action: @escaping () -> Void) -> () -> Void {
        var workItem: DispatchWorkItem?
        return {
            workItem?.cancel()
            workItem = DispatchWorkItem(block: action)
            queue.asyncAfter(deadline: .now() + interval, execute: workItem!)
        }
    }
    
    public static func throttle(interval: TimeInterval, queue: DispatchQueue = .main, action: @escaping () -> Void) -> () -> Void {
        var lastRun = Date.distantPast
        let lock = NSLock()
        return {
            lock.lock()
            let now = Date()
            let elapsed = now.timeIntervalSince(lastRun)
            lock.unlock()
            if elapsed >= interval {
                lock.lock()
                lastRun = now
                lock.unlock()
                queue.async(execute: action)
            }
        }
    }
    
    public static func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        useBackoff: Bool = false,
        work: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        for attempt in 1...maxAttempts {
            do {
                return try await work()
            } catch {
                lastError = error
                if attempt == maxAttempts { throw error }
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                if useBackoff { currentDelay *= 2 }
            }
        }
        throw lastError ?? NSError(domain: "ThreadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Retry failed"])
    }
    
    
    private static var onceTokens = [String: Bool]()
    private static let onceLock = NSLock()
    
    public static func once(token: String, _ block: () -> Void) {
        onceLock.lock()
        let alreadyRun = onceTokens[token] == true
        if !alreadyRun {
            onceTokens[token] = true
        }
        onceLock.unlock()
        if !alreadyRun {
            block()
        }
    }
}


extension ThreadManager {
    
    public static func onMainIfNeeded(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
    
    public static func asyncOnBackground<T>(
        work: @escaping () throws -> T,
        completionOnMain: @escaping (T) -> Void,
        onFailure: ((Error) -> Void)? = nil
    ) {
        runAsync(work: work) { result in
            switch result {
            case .success(let value):
                completionOnMain(value)
            case .failure(let error):
                onFailure?(error)
            }
        }
    }
}
