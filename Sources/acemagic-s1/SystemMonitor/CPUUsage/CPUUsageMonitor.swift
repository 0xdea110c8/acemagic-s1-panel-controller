protocol CPUUsageMonitor: Actor {
    var cpuUsage: Double { get async }
    func updateCPUUsage() async
}
