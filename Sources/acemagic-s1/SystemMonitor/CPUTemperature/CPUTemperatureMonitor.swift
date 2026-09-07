protocol CPUTemperatureMonitor: Sendable {
    var cpuTemperature: Double { get async }
}
