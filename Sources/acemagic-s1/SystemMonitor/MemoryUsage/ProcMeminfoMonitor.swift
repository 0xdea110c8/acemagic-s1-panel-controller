#if os(Linux)
    import Glibc

    actor ProcMeminfoMonitor {
        private(set) var currentUsage: (total: UInt64, available: UInt64)

        init() {
            currentUsage = (0, 0)
        }

        func getCurrentMemoryUsage() -> (total: UInt64, available: UInt64) {
            let fileDescriptor = open("/proc/meminfo", O_RDONLY | O_CLOEXEC)

            guard fileDescriptor >= 0 else {
                perror("open")
                return (0, 0)
            }

            defer {
                close(fileDescriptor)
            }

            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 4096) { buffer in
                let count = read(
                    fileDescriptor,
                    buffer.baseAddress,
                    buffer.count
                )

                guard count > 0 else {
                    if count < 0 {
                        perror("read")
                    }

                    return (0, 0)
                }

                let text = String(
                    decoding: UnsafeBufferPointer(
                        start: buffer.baseAddress,
                        count: count
                    ),
                    as: UTF8.self
                )

                var total: UInt64 = 0
                var available: UInt64 = 0

                for line in text.split(separator: "\n") {
                    if line.hasPrefix("MemTotal:") {
                        total =
                            UInt64(
                                line.split(whereSeparator: \.isWhitespace)[1]
                            ) ?? 0
                    } else if line.hasPrefix("MemAvailable:") {
                        available =
                            UInt64(
                                line.split(whereSeparator: \.isWhitespace)[1]
                            ) ?? 0
                    }

                    if total > 0 && available > 0 {
                        break
                    }
                }

                return (total, available)
            }
        }
    }

    extension ProcMeminfoMonitor: MemoryUsageMonitor {
        @inline(__always)
        var memoryUsage: Double {
            guard currentUsage.total > 0 else {
                return 0
            }

            return Double(currentUsage.total - currentUsage.available) / Double(currentUsage.total)
        }

        @inline(__always)
        func updateMemoryUsage() async {
            currentUsage = getCurrentMemoryUsage()
        }
    }
#endif    // os(Linux)
