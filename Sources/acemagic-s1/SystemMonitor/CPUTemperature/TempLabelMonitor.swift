#if os(Linux)
    import Glibc

    struct TempLabelMonitor {
        func getCurrentCPUTemperature() -> Double {
            guard let directory = opendir("/sys/class/hwmon") else {
                perror("opendir")
                return 0
            }

            defer {
                closedir(directory)
            }

            while let entry = readdir(directory) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                        String(cString: $0)
                    }
                }

                guard name.hasPrefix("hwmon") else {
                    continue
                }

                let basePath = "/sys/class/hwmon/\(name)"

                guard let driver = readString("\(basePath)/name") else {
                    continue
                }

                guard driver == "coretemp" || driver == "k10temp" else {
                    continue
                }

                guard let hwmonDirectory = opendir(basePath) else {
                    continue
                }

                defer {
                    closedir(hwmonDirectory)
                }

                while let fileEntry = readdir(hwmonDirectory) {
                    let fileName = withUnsafePointer(to: &fileEntry.pointee.d_name) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                            String(cString: $0)
                        }
                    }

                    guard
                        fileName.hasPrefix("temp"),
                        fileName.hasSuffix("_label")
                    else {
                        continue
                    }

                    guard let label = readString("\(basePath)/\(fileName)") else {
                        continue
                    }

                    guard label == "Package id 0" || label == "Tctl" else {
                        continue
                    }

                    let inputFile = fileName.replacingOccurrences(
                        of: "_label",
                        with: "_input"
                    )

                    guard let raw = readUInt("\(basePath)/\(inputFile)") else {
                        continue
                    }

                    return Double(raw) / 1000
                }
            }

            return 0
        }

        func readString(_ path: String) -> String? {
            let fd = open(path, O_RDONLY | O_CLOEXEC)

            guard fd >= 0 else {
                return nil
            }

            defer {
                close(fd)
            }

            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 256) { buffer in
                let count = read(fd, buffer.baseAddress, buffer.count)

                guard count > 0 else {
                    return nil
                }

                return String(
                    decoding: UnsafeBufferPointer(
                        start: buffer.baseAddress,
                        count: count
                    ),
                    as: UTF8.self
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        func readUInt(_ path: String) -> UInt64? {
            let fd = open(path, O_RDONLY | O_CLOEXEC)

            guard fd >= 0 else {
                return nil
            }

            defer {
                close(fd)
            }

            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { buffer in
                let count = read(fd, buffer.baseAddress, buffer.count)

                guard count > 0 else {
                    return nil
                }

                var value: UInt64 = 0

                for index in 0..<count {
                    let byte = buffer[index]

                    guard byte >= 48 && byte <= 57 else {
                        break
                    }

                    value = value * 10 + UInt64(byte - 48)
                }

                return value
            }
        }
    }

    extension TempLabelMonitor: CPUTemperatureMonitor {
        @inline(__always)
        var cpuTemperature: Double {
            getCurrentCPUTemperature()
        }

    }
#endif    // os(Linux)
