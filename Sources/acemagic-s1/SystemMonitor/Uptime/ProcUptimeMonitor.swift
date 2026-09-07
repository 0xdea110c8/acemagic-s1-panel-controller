#if os(Linux)
    import Glibc

    struct ProcUptimeMonitor: UptimeMonitor {
        var uptime: Double {
            let fileDescriptor = open("/proc/uptime", O_RDONLY | O_CLOEXEC)

            guard fileDescriptor >= 0 else {
                perror("open")
                return 0
            }

            defer {
                close(fileDescriptor)
            }

            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { buffer in
                let count = read(
                    fileDescriptor,
                    buffer.baseAddress,
                    buffer.count
                )

                guard count > 0 else {
                    if count < 0 {
                        perror("read")
                    }

                    return 0
                }

                var integer: UInt64 = 0
                var fraction: UInt64 = 0
                var divisor: UInt64 = 1
                var afterDot = false

                for index in 0..<count {
                    let byte = buffer[index]

                    if byte == 32 || byte == 10 {
                        break
                    }

                    if byte == 46 {
                        afterDot = true
                        continue
                    }

                    guard byte >= 48 && byte <= 57 else {
                        break
                    }

                    let digit = UInt64(byte - 48)

                    if afterDot {
                        fraction = fraction * 10 + digit
                        divisor *= 10
                    } else {
                        integer = integer * 10 + digit
                    }
                }

                return Double(integer) + Double(fraction) / Double(divisor)
            }
        }
    }
#endif
