#if os(Linux)
    import Glibc

    actor ProcStatMonitor {
        private(set) var previousCPUUsage: (total: UInt64, idle: UInt64)
        private(set) var currentCPUUsage: (total: UInt64, idle: UInt64)

        init() {
            currentCPUUsage = (0, 0)
            previousCPUUsage = (0, 0)
        }

        func getCurrentCPUUsage() -> (total: UInt64, idle: UInt64) {
            let fileDescriptor = open("/proc/stat", O_RDONLY | O_CLOEXEC)

            guard fileDescriptor >= 0 else {
                perror("open")
                return (0, 0)
            }

            defer {
                close(fileDescriptor)
            }

            return withUnsafeTemporaryAllocation(
                of: UInt8.self,
                capacity: 4096
            ) { buffer in
                let count = read(
                    fileDescriptor,
                    buffer.baseAddress,
                    buffer.count
                )

                guard count > 0 else {
                    perror("read")
                    return (0, 0)
                }

                var total: UInt64 = 0
                var idle: UInt64 = 0
                var index = 3

                for field in 0..<8 {
                    while index < count, buffer[index] == 32 || buffer[index] == 9 {
                        index += 1
                    }

                    var value: UInt64 = 0

                    while index < count {
                        let byte = buffer[index]
                        guard byte >= 48 && byte <= 57 else {
                            break
                        }

                        value = value * 10 + UInt64(byte - 48)
                        index += 1
                    }

                    total += value

                    if field == 3 || field == 4 {
                        idle += value
                    }
                }
                return (total, idle)
            }
        }
    }

    extension ProcStatMonitor: CPUUsageMonitor {
        @inline(__always)
        var cpuUsage: Double {
            let totalDelta = currentCPUUsage.total - previousCPUUsage.total
            let idleDelta = currentCPUUsage.idle - previousCPUUsage.idle

            guard totalDelta > 0 else {
                return .zero
            }

            return Double(totalDelta - idleDelta) / Double(totalDelta)
        }

        @inline(__always)
        func updateCPUUsage() {
            previousCPUUsage = currentCPUUsage
            currentCPUUsage = getCurrentCPUUsage()
        }
    }
#endif    // os(Linux)
