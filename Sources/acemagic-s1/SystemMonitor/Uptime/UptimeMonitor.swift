protocol UptimeMonitor: Sendable {
    var uptime: Double { get async }
}
