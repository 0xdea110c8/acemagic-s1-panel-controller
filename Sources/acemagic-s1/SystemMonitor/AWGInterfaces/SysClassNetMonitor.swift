#if os(Linux)
    import Glibc

    struct SysClassNetMonitor: AWGInterfacesMonitor {
        var awgInterfaces: [String] {
            guard let directory = opendir("/sys/class/net") else {
                perror("opendir")
                return []
            }
            
            defer {
                closedir(directory)
            }
            
            var result: [String] = []
            
            while let entry = readdir(directory) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                        String(cString: $0)
                    }
                }
                
                guard name != ".", name != ".." else {
                    continue
                }
                
                let path = "/sys/class/net/\(name)/uevent"
                
                let fd = open(path, O_RDONLY | O_CLOEXEC)
                
                guard fd >= 0 else {
                    continue
                }
                
                defer {
                    close(fd)
                }
                
                var buffer = [UInt8](repeating: 0, count: 256)
                
                let count = buffer.withUnsafeMutableBytes {
                    read(fd, $0.baseAddress, $0.count)
                }
                
                guard count > 0 else {
                    continue
                }
                
                let text = String(
                    decoding: buffer.prefix(count),
                    as: UTF8.self
                )
                
                if text.contains("DEVTYPE=amneziawg") {
                    result.append(name)
                }
            }
            
            return result
        }
        
        var isAWGModuleLoaded: Bool {
            access("/sys/module/amneziawg", F_OK) == 0
        }
    }
#endif // os(Linux)
