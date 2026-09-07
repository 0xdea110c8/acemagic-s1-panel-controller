actor LinuxSystemMonitor {
    let cpuUsageMonitor: CPUUsageMonitor
    let cpuTemperatureMonitor: CPUTemperatureMonitor
    let memoryUsageMonitor: MemoryUsageMonitor
    let diskUsageMonitor: DiskUsageMonitor
    let uptimeMonitor: UptimeMonitor
    let awgInterfacesMonitor: AWGInterfacesMonitor

    var updateMetricsTask: Task<Void, any Error>?

    init(
        cpuUsageMonitor: CPUUsageMonitor = ProcStatMonitor(),
        cpuTemperatureMonitor: CPUTemperatureMonitor = TempLabelMonitor(),
        memoryUsageMonitor: MemoryUsageMonitor = ProcMeminfoMonitor(),
        diskUsageMonitor: DiskUsageMonitor = StatVFSMonitor(),
        uptimeMonitor: UptimeMonitor = ProcUptimeMonitor(),
        awgInterfacesMonitor: AWGInterfacesMonitor = SysClassNetMonitor()

    ) {
        self.cpuUsageMonitor = cpuUsageMonitor
        self.cpuTemperatureMonitor = cpuTemperatureMonitor
        self.memoryUsageMonitor = memoryUsageMonitor
        self.diskUsageMonitor = diskUsageMonitor
        self.uptimeMonitor = uptimeMonitor
        self.awgInterfacesMonitor = awgInterfacesMonitor
    }

    deinit {
        updateMetricsTask?.cancel()
        updateMetricsTask = nil
    }
}

extension LinuxSystemMonitor: SystemMonitor {
    var cpuUsage: Double {
        get async {
            await cpuUsageMonitor.cpuUsage
        }
    }

    var cpuTemperature: Double {
        cpuTemperatureMonitor.cpuTemperature
    }

    var memoryUsage: Double {
        memoryUsageMonitor.memoryUsage
    }

    var diskUsage: Double {
        diskUsageMonitor.diskUsage
    }

    var uptime: Double {
        uptimeMonitor.uptime
    }

    var isAWGLoaded: Bool {
        awgInterfacesMonitor.isAWGModuleLoaded
    }

    var awgInterfaces: [String] {
        awgInterfacesMonitor.awgInterfaces
    }

    func startUpdatingMetrics() {
        updateMetricsTask = Task {
            while !Task.isCancelled {
                await cpuUsageMonitor.updateCPUUsage()

                try await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopUpdatingMetrics() {
        updateMetricsTask?.cancel()
        updateMetricsTask = nil
    }
}
