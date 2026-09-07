protocol AWGInterfacesMonitor: Sendable {
    var isAWGModuleLoaded: Bool { get }
    var awgInterfaces: [String] { get }
}
