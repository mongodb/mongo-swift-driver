import Foundation

/// Threadsafe counter that generates an increasing sequence of integers.
internal class Counter {
    internal init(label: String) {
        self.queue = DispatchQueue(label: label)
    }

    private let queue: DispatchQueue
    /// Current count. This variable must only be read and written within `queue.sync` blocks.
    private var count = 0

    /// Returns the next value in the counter.
    internal func next() -> Int {
        self.queue.sync {
            self.count += 1
            return self.count
        }
    }
}
