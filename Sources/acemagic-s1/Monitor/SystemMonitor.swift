import Foundation
import Glibc
import SysInfo

protocol ProvidesSystemMetrics {
    var loadAvg: Int { get }
    var cpuUsage: Int { get }
    var cpuTemp: Int { get }
    var ramUsage: Int { get }
    var swapUsage: Int { get }
    var diskUsage: Int { get }
    var rssi: Int { get }
    var awgInterfaces: [String] { get }
    var uptime: Int { get }
}

final class SystemMonitor {
    private static let metricsSerialLane = DispatchQueue(
        label: "acemagic-s1.lane.serial.metrics",
        target: .global(qos: .default)
    )

    private static let wifiInterface = "wlp2s0"

    private var _loadAvg: Int
    private var _cpuUsage: Int
    private var _cpuTemp: Int
    private var _ramUsage: Int
    private var _swapUsage: Int
    private var _diskUsage: Int
    private var _rssi: Int
    private var _awgInterfaces: [String]
    private var _uptime: Int

    private var hardwareMetricsTimer: DispatchSourceTimer?
    private var sysInfoMetricsTimer: DispatchSourceTimer?

    init() {
        _loadAvg = 0
        _cpuUsage = 0
        _cpuTemp = 0
        _ramUsage = 0
        _swapUsage = 0
        _diskUsage = 0
        _rssi = 0
        _awgInterfaces = []
        _uptime = 0
        setTimer(&hardwareMetricsTimer, frequency: 1.0) { [weak self] in
            self?._loadAvg = SystemMonitor.getLoadAvg()
            self?._cpuUsage = SystemMonitor.getCpuUsage()
            self?._cpuTemp = SystemMonitor.getCpuTemp()
            let (ramUsage, swapUsage, uptime) = SystemMonitor.getSysInfo()
            self?._ramUsage = ramUsage
            self?._swapUsage = swapUsage
            self?._uptime = uptime
        }

        setTimer(&sysInfoMetricsTimer, frequency: 10.0) { [weak self] in
            self?._diskUsage = SystemMonitor.getDiskUsage()
            self?._rssi = SystemMonitor.getRssi()
            self?._awgInterfaces = SystemMonitor.getAwgInterfaces()
        }
    }

    deinit {
        hardwareMetricsTimer?.cancel()
        sysInfoMetricsTimer?.cancel()
    }

    private func setTimer(_ timer: inout DispatchSourceTimer?, frequency: Double, handler: @escaping () -> Void) {
        let _timer = DispatchSource.makeTimerSource(queue: SystemMonitor.metricsSerialLane)
        _timer.setEventHandler(handler: handler)
        _timer.schedule(deadline: .now(), repeating: frequency, leeway: .milliseconds(50))
        _timer.activate()
        timer = _timer
    }
}

extension SystemMonitor: ProvidesSystemMetrics {
    var loadAvg: Int {
        SystemMonitor.metricsSerialLane.sync {
            _loadAvg
        }
    }

    var cpuUsage: Int {
        SystemMonitor.metricsSerialLane.sync {
            _cpuUsage
        }
    }
    var cpuTemp: Int {
        SystemMonitor.metricsSerialLane.sync {
            _cpuTemp
        }
    }
    var ramUsage: Int {
        SystemMonitor.metricsSerialLane.sync {
            _ramUsage
        }
    }
    var swapUsage: Int {
        SystemMonitor.metricsSerialLane.sync {
            _swapUsage
        }
    }
    var diskUsage: Int {
        SystemMonitor.metricsSerialLane.sync {
            _diskUsage
        }
    }
    var rssi: Int {
        SystemMonitor.metricsSerialLane.sync {
            _rssi
        }
    }
    var awgInterfaces: [String] {
        SystemMonitor.metricsSerialLane.sync {
            _awgInterfaces
        }
    }
    var uptime: Int {
        SystemMonitor.metricsSerialLane.sync {
            _uptime
        }
    }
}

extension SystemMonitor {
    static func getLoadAvg() -> Int {
        let cpuCoresCount = ProcessInfo.processInfo.activeProcessorCount
        var loadAvgValues = Array.init(repeating: 0.0, count: 1)
        guard getloadavg(&loadAvgValues, 1) == 1 else {
            log(.cantGetLoadAvg)
            return 0
        }
        return Int(loadAvgValues[0] * 100 / Double(cpuCoresCount))
    }

    static func getCpuUsage() -> Int {
        Int(SysInfo.get_cpu_usage_percent())
    }

    static func getCpuTemp() -> Int {
        Int(SysInfo.get_cpu_temperature())
    }

    static func getSysInfo() -> (ramUsage: Int, swapUsage: Int, uptime: Int) {
        let info = SysInfo.get_ram_info()
        return (Int(info.ram_free_percent), Int(info.swap_free_percent), Int(info.uptime))
    }

    static func getDiskUsage() -> Int {
        Int(SysInfo.get_disk_usage())
    }

    static func getRssi() -> Int {
        Int(SysInfo.get_wifi_rssi(wifiInterface))
    }

    static func getAwgInterfaces() -> [String] {
        var count: Int32 = 0
        let array = SysInfo.get_awg_interfaces_sysfs(&count)
        var interfaces: [String] = []
        for index in 0..<Int(count) {
            if let interface = array?[index] {
                interfaces.append(String(cString: interface))
            }
        }
        SysInfo.free_sysfs_interfaces(array, count)
        return interfaces
    }

    private static func log(_ event: SystemMonitorEvent) {
        Logger.log(event, in: .debug)
    }
}

extension SystemMonitor {
    enum SystemMonitorEvent: CustomStringConvertible {
        case cantGetLoadAvg

        var description: String {
            switch self {
                case .cantGetLoadAvg:
                    return "Can't get load average"
            }
        }
    }
}
