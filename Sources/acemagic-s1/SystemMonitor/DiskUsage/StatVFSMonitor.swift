#if os(Linux)
    import Glibc

    struct StatVFSMonitor: DiskUsageMonitor {
        var diskUsage: Double {
            var stats = statvfs()
            let path = "/"

            guard statvfs(path, &stats) == 0 else {
                perror("statvfs")
                return 0
            }

            let total = UInt64(stats.f_blocks) * UInt64(stats.f_frsize)
            let available = UInt64(stats.f_bavail) * UInt64(stats.f_frsize)

            guard total > 0 else {
                return 0
            }

            let used = total - available

            return Double(used) / Double(total)
        }
    }
#endif    // os(Linux)
