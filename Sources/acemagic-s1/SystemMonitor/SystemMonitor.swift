protocol SystemMonitor: Actor {
    var loadAverage: Double { get async }
    var cpuUsage: Double { get async }
    var cpuTemperature: Double { get async }
    var memoryUsage: Double { get async }
    var diskUsage: Double { get async }
    var uptime: Double { get async }
    var isAWGLoaded: Bool { get async }
    var wifiSignal: Int { get async }
    var awgInterfaces: [String] { get async }

    func startUpdatingMetrics() async
    func stopUpdatingMetrics() async
}
