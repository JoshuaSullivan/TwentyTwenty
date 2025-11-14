import Foundation

/// Tracks performance metrics for Vision model execution
struct PerformanceTracker {
    /// Start time of the operation
    private var startTime: CFAbsoluteTime?

    /// End time of the operation
    private var endTime: CFAbsoluteTime?

    /// Memory used before the operation (bytes)
    private var memoryBefore: UInt64?

    /// Memory used after the operation (bytes)
    private var memoryAfter: UInt64?

    // MARK: - Initialization

    init() {
        self.startTime = nil
        self.endTime = nil
        self.memoryBefore = nil
        self.memoryAfter = nil
    }

    // MARK: - Tracking Methods

    /// Starts tracking performance
    mutating func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        memoryBefore = getCurrentMemoryUsage()
    }

    /// Stops tracking performance
    mutating func stop() {
        endTime = CFAbsoluteTimeGetCurrent()
        memoryAfter = getCurrentMemoryUsage()
    }

    // MARK: - Computed Properties

    /// Elapsed time in seconds
    var elapsedTime: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end - start
    }

    /// Elapsed time formatted as a string
    var elapsedTimeString: String {
        guard let elapsed = elapsedTime else { return "N/A" }

        if elapsed < 1.0 {
            return String(format: "%.0f ms", elapsed * 1000)
        } else {
            return String(format: "%.2f s", elapsed)
        }
    }

    /// Memory delta in bytes (can be negative if memory was freed)
    var memoryDelta: Int64? {
        guard let before = memoryBefore, let after = memoryAfter else { return nil }
        return Int64(after) - Int64(before)
    }

    /// Memory delta formatted as a string
    var memoryDeltaString: String {
        guard let delta = memoryDelta else { return "N/A" }

        let absDelta = abs(delta)
        let sign = delta >= 0 ? "+" : "-"

        if absDelta < 1024 {
            return "\(sign)\(absDelta) B"
        } else if absDelta < 1024 * 1024 {
            return String(format: "%@%.1f KB", sign, Double(absDelta) / 1024.0)
        } else {
            return String(format: "%@%.1f MB", sign, Double(absDelta) / (1024.0 * 1024.0))
        }
    }

    /// Current memory usage in bytes
    var currentMemoryUsage: UInt64 {
        getCurrentMemoryUsage()
    }

    /// Current memory usage formatted as a string
    var currentMemoryString: String {
        formatBytes(currentMemoryUsage)
    }

    // MARK: - Private Helpers

    /// Gets the current memory usage of the app
    /// - Returns: Memory usage in bytes
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }

    /// Formats bytes into a human-readable string
    /// - Parameter bytes: Number of bytes
    /// - Returns: Formatted string
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - Async Wrapper

extension PerformanceTracker {
    /// Executes an async operation and tracks its performance
    /// - Parameter operation: The async operation to perform
    /// - Returns: Tuple containing the operation result and performance metrics
    static func measure<T>(_ operation: () async throws -> T) async rethrows -> (result: T, tracker: PerformanceTracker) {
        var tracker = PerformanceTracker()
        tracker.start()
        let result = try await operation()
        tracker.stop()
        return (result, tracker)
    }
}

// MARK: - Performance Statistics

/// Statistics from a Vision model execution
struct PerformanceStatistics {
    /// Inference time
    let inferenceTime: TimeInterval

    /// Memory delta
    let memoryDelta: Int64

    /// Formatted inference time string
    var inferenceTimeString: String {
        if inferenceTime < 1.0 {
            return String(format: "%.0f ms", inferenceTime * 1000)
        } else {
            return String(format: "%.2f s", inferenceTime)
        }
    }

    /// Formatted memory delta string
    var memoryDeltaString: String {
        let absDelta = abs(memoryDelta)
        let sign = memoryDelta >= 0 ? "+" : "-"

        if absDelta < 1024 {
            return "\(sign)\(absDelta) B"
        } else if absDelta < 1024 * 1024 {
            return String(format: "%@%.1f KB", sign, Double(absDelta) / 1024.0)
        } else {
            return String(format: "%@%.1f MB", sign, Double(absDelta) / (1024.0 * 1024.0))
        }
    }

    init(from tracker: PerformanceTracker) {
        self.inferenceTime = tracker.elapsedTime ?? 0
        self.memoryDelta = tracker.memoryDelta ?? 0
    }
}
