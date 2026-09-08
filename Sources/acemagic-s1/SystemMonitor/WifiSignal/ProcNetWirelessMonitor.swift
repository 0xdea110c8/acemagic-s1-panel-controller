#if os(Linux)
    import Glibc

    struct ProcNetWirelessMonitor: WifiSignalMonitor {
        var wifiSignal: Int {
            let fileDescriptor = open("/proc/net/wireless", O_RDONLY | O_CLOEXEC)

            guard fileDescriptor >= 0 else {
                perror("open /proc/net/wireless")
                return 0
            }

            defer {
                close(fileDescriptor)
            }

            var buffer = [UInt8](repeating: 0, count: 1024)

            let count = read(fileDescriptor, &buffer, buffer.count)

            guard count > 0 else {
                perror("read /proc/net/wireless")
                return 0
            }

            var i = 0

            var newlines = 0
            while i < count && newlines < 2 {
                if buffer[i] == 10 {
                    newlines += 1
                }
                i += 1
            }

            while i < count && buffer[i] != 58 {
                i += 1
            }

            guard i < count else {
                return 0
            }

            i += 1

            skipField(buffer, count, &i)
            skipField(buffer, count, &i)
            skipSpaces(buffer, count, &i)

            var sign = 1

            if i < count && buffer[i] == 45 {
                sign = -1
                i += 1
            }

            var value = 0

            while i < count {
                let byte = buffer[i]

                guard byte >= 48 && byte <= 57 else {
                    break
                }

                value = value * 10 + Int(byte - 48)
                i += 1
            }

            return value * sign
        }

        private func skipSpaces(
            _ buffer: [UInt8],
            _ count: Int,
            _ index: inout Int
        ) {
            while index < count && buffer[index] == 32 {
                index += 1
            }
        }

        private func skipField(
            _ buffer: [UInt8],
            _ count: Int,
            _ index: inout Int
        ) {
            skipSpaces(buffer, count, &index)

            while index < count && buffer[index] != 32 {
                index += 1
            }
        }
    }
#endif
