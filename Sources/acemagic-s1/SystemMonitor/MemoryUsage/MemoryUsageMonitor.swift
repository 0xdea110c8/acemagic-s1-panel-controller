protocol MemoryUsageMonitor: Actor {
    var memoryUsage: Double { get async }
    func updateMemoryUsage() async
}
