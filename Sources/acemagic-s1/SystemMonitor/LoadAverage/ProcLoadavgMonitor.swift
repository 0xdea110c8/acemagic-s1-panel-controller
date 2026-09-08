#if os(Linux)
    import Glibc

    struct ProcLoadavgMonitor: LoadAverageMonitor {
        var loadAverage: Double {
            let fileDescriptor = open("/proc/loadavg", O_RDONLY | O_CLOEXEC)

            guard fileDescriptor >= 0 else {
                perror("open")
                return 0.0
            }

            defer { close(fileDescriptor) }

            var buffer = [UInt8](repeating: 0, count: 32)

            let count = read(fileDescriptor, &buffer, buffer.count)
            guard count > 0 else {
                perror("read")
                return 0.0
            }

            let cpuCount = sysconf(Int32(_SC_NPROCESSORS_ONLN))
            guard cpuCount > 0 else {
                return 0
            }

            return buffer.withUnsafeBufferPointer {
                strtod($0.baseAddress!, nil) / Double(cpuCount)
            }
        }
    }
#endif
