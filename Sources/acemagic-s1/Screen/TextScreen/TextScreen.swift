import Foundation

actor TextScreen {
    enum Color {
        static let black: UInt16 = 0x0000
        static let red: UInt16 = 0xE000
        static let orange: UInt16 = 0xE3E0
        static let yellow: UInt16 = 0xE720
        static let green: UInt16 = 0x072d
        static let blue: UInt16 = 0x029C
        static let lightBlue: UInt16 = 0xBFFF
        static let purple: UInt16 = 0xB81C
        static let pink: UInt16 = 0xE00E
    }

    let drawer: any DisplayDrawer
    let systemMonitor: any SystemMonitor
    let font = IBMPlexMonoFont.self
    let backgroundColor: UInt16 = Color.black

    var timeRedrawTask: Task<Void, any Error>?
    var metricUpdateTask: Task<Void, any Error>?

    var loadAverage: Int = 1000
    var cpuUsage: Int = 101
    var cpuTemperature: Int = 1000
    var memoryUsage: Int = 101
    var diskUsage: Int = 101
    var wifiSignal: Int = 0
    var awgInterface: String? = ""

    var isRunning: Bool = false

    init(
        drawer: any DisplayDrawer,
        systemMonitor: any SystemMonitor = LinuxSystemMonitor()
    ) {
        self.drawer = drawer
        self.systemMonitor = systemMonitor
    }

    deinit {
        timeRedrawTask?.cancel()
        metricUpdateTask?.cancel()
        timeRedrawTask = nil
        metricUpdateTask = nil
    }
}

extension TextScreen: ScreenRenderer {
    func start() async throws {
        guard !isRunning else {
            return
        }

        await systemMonitor.startUpdatingMetrics()
        try redraw()

        timeRedrawTask = Task {
            while !Task.isCancelled {
                try await redrawUptime()
                try await redrawDate()
                try await redrawTime()

                let now = Date().timeIntervalSince1970
                let nextMinute = floor(now / 60) * 60 + 60
                let delay = nextMinute - now

                try await Task.sleep(for: .seconds(delay))
            }
        }

        metricUpdateTask = Task {
            while !Task.isCancelled {
                try await updateLoadAverage()
                try await updateCPUUsage()
                try await updateCPUTemperature()
                try await updateMemoryUsage()
                try await updateDiskUsage()
                try await updateAWGInterfaceUsage()
                try await updateWifiSignal()

                try await Task.sleep(for: .seconds(1))
            }
        }
    }
}

extension TextScreen {
    func redraw() throws {
        var frameBuffer: [UInt8] = .init(
            repeating: 0x00,
            count: drawer.displayWidth * drawer.displayHeight * drawer.bytesInPixel
        )
        try renderFrameBuffer(
            """















              :        /  
            """,
            &frameBuffer,
            color: Color.lightBlue
        )

        try drawer.draw(frameBuffer)
    }
}

extension TextScreen {
    func updateLoadAverage() async throws {
        let loadAverage = Int(await systemMonitor.loadAverage * 100)
        if loadAverage != self.loadAverage {
            let color: UInt16 =
                switch loadAverage / 20 {
                    case 0: Color.blue
                    case 1: Color.green
                    case 2: Color.yellow
                    case 3: Color.orange
                    default: Color.red
                }

            try updateText("LOAD", in: 0, at: 0, color: color)
            try updateText("AVG", in: 0, at: 5, color: color)
            try updateText(String(format: "%3d", loadAverage), in: 0, at: 11, color: color)
        }
    }

    func updateCPUUsage() async throws {
        let cpuUsage = Int(await systemMonitor.cpuUsage * 100)

        if cpuUsage != self.cpuUsage {
            let color: UInt16 =
                switch cpuUsage / 20 {
                    case 0: Color.blue
                    case 1: Color.green
                    case 2: Color.yellow
                    case 3: Color.orange
                    default: Color.red
                }

            try updateText("CPU", in: 1, at: 0, color: color)
            try updateText("USA", in: 1, at: 4, color: color)
            try updateText("GE", in: 1, at: 7, color: color)
            try updateText(String(format: "%3d", cpuUsage), in: 1, at: 11, color: color)
        }
    }

    func updateCPUTemperature() async throws {
        let cpuTemperature = Int(await systemMonitor.cpuTemperature)

        if cpuTemperature != self.cpuTemperature {
            let color: UInt16 =
                switch cpuTemperature {
                    case ..<50: Color.blue
                    case 50..<65: Color.green
                    case 65..<75: Color.yellow
                    case 75..<85: Color.orange
                    default: Color.red
                }

            try updateText("CPU", in: 2, at: 0, color: color)
            try updateText("TEMP", in: 2, at: 4, color: color)
            try updateText(String(format: "%3d", cpuTemperature), in: 2, at: 11, color: color)
        }
    }

    func updateMemoryUsage() async throws {
        let memoryUsage = Int(await systemMonitor.memoryUsage * 100)

        if memoryUsage != self.memoryUsage {
            let color: UInt16 =
                switch memoryUsage / 20 {
                    case 0: Color.blue
                    case 1: Color.green
                    case 2: Color.yellow
                    case 3: Color.orange
                    default: Color.red
                }

            try updateText("RAM", in: 3, at: 0, color: color)
            try updateText("USA", in: 3, at: 4, color: color)
            try updateText("GE", in: 3, at: 7, color: color)
            try updateText(String(format: "%3d", memoryUsage), in: 3, at: 11, color: color)
        }
    }

    func updateDiskUsage() async throws {
        let diskUsage = Int(await systemMonitor.diskUsage * 100)

        if diskUsage != self.diskUsage {
            let color: UInt16 =
                switch diskUsage / 20 {
                    case 0: Color.blue
                    case 1: Color.green
                    case 2: Color.yellow
                    case 3: Color.orange
                    default: Color.red
                }
            try updateText("DISK", in: 4, at: 0, color: color)
            try updateText("USA", in: 4, at: 5, color: color)
            try updateText("GE", in: 4, at: 8, color: color)
            try updateText(String(format: "%3d", diskUsage), in: 4, at: 11, color: color)
        }
    }

    func updateWifiSignal() async throws {
        let wifiSignal = min(max(await systemMonitor.wifiSignal, -99), 0)

        if wifiSignal != self.wifiSignal {
            let color: UInt16 =
                switch wifiSignal {
                    case -50..<0: Color.blue
                    case -60 ..< -50: Color.green
                    case -67 ..< -60: Color.yellow
                    case -80 ..< -67: Color.orange
                    default: Color.red
                }
            debugPrint(wifiSignal)
            try updateText("WIFI", in: 12, at: 0, color: color)
            try updateText("SIG", in: 12, at: 5, color: color)
            try updateText(String(format: "%ld", wifiSignal), in: 12, at: 11, color: color)
        }
    }

    func updateAWGInterfaceUsage() async throws {
        let isAWGLoaded = await systemMonitor.isAWGLoaded
        if isAWGLoaded {
            let awgInterface = await systemMonitor.awgInterfaces.first
            if awgInterface != self.awgInterface {
                let color: UInt16 = awgInterface != nil ? Color.blue : Color.yellow
                let state: String = awgInterface != nil ? "UP  " : "DOWN"
                let interface: String =
                    if let awgInterface {
                        awgInterface.prefix(4).uppercased()
                    } else {
                        "    "
                    }

                try updateText("AWG", in: 13, at: 0, color: color)
                try updateText(state, in: 13, at: 4, color: color)
                try updateText(interface, in: 13, at: 10, color: color)
            }
        }
    }

    func redrawUptime() async throws {
        let color = Color.blue
        let uptimeStrings = await getUptimeStrings()
        try updateText("UP", in: 14, at: 0, color: color)
        try updateText(uptimeStrings.days, in: 14, at: 5, color: color)
        try updateText(":\(uptimeStrings.hours)", in: 14, at: 8, color: color)
        try updateText(":\(uptimeStrings.minutes)", in: 14, at: 11, color: color)
    }

    func redrawDate() async throws {
        let dateStrings = getDateStrings()

        try updateText(dateStrings.day, in: 15, at: 9, color: Color.lightBlue)
        try updateText(dateStrings.month, in: 15, at: 12, color: Color.lightBlue)
    }

    func redrawTime() async throws {
        let timeStrings = getTimeStrings()

        try updateText(timeStrings.hour, in: 15, at: 0, color: Color.lightBlue)
        try updateText(timeStrings.minute, in: 15, at: 3, color: Color.lightBlue)
    }
}

extension TextScreen {
    func getDateStrings() -> (day: String, month: String) {
        let dateComponents = Calendar.current.dateComponents(
            [.day, .month, .year],
            from: Date()
        )

        let dayString = String(format: "%02d", dateComponents.day ?? 0)
        let monthString = String(format: "%02d", dateComponents.month ?? 0)
        return (dayString, monthString)
    }

    func getTimeStrings() -> (hour: String, minute: String) {
        let dateComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Date()
        )

        let hourString = String(format: "%02d", dateComponents.hour ?? 0)
        let minuteString = String(format: "%02d", dateComponents.minute ?? 0)
        return (hourString, minuteString)
    }

    func getUptimeStrings() async -> (days: String, hours: String, minutes: String) {
        let uptime = Int(await systemMonitor.uptime)
        let rawDays = uptime / 86_400
        let days = rawDays < 1000 ? rawDays : 999
        let hours = (uptime % 86_400) / 3_600
        let minutes = (uptime % 3_600) / 60
        let daysString = String(format: "%03d", days)
        let hoursString = String(format: "%02d", hours)
        let minutesString = String(format: "%02d", minutes)
        return (daysString, hoursString, minutesString)
    }
}

extension TextScreen {
    func renderFrameBuffer(
        _ text: String,
        _ frameBuffer: inout [UInt8],
        color: UInt16
    ) throws {
        var start = frameBuffer.count - drawer.displayHeight * drawer.bytesInPixel
        var pixel = start
        for char in text {
            if char == "\n" {
                start += font.height * drawer.bytesInPixel
                pixel = start
                continue
            }
            let bitmap = try font.Glyph(char: char).bitmap
            for x in 0..<font.width {
                for y in 0..<font.height {
                    renderPixel(
                        pixel,
                        in: &frameBuffer,
                        at: (x, y),
                        with: bitmap,
                        color: color
                    )
                }
                pixel -= drawer.displayHeight * drawer.bytesInPixel
            }
            pixel -= drawer.displayHeight * drawer.bytesInPixel * font.advance
        }
    }

    func updateText(
        _ text: String,
        in line: Int,
        at place: Int,
        color: UInt16
    ) throws {
        let coordinates = (
            x: drawer.displayWidth - 1 - font.width * (place + text.count),
            y: font.height * line
        )

        let rect = (width: font.width * text.count, height: font.height)

        var frameBuffer: [UInt8] = .init(
            repeating: 0x00,
            count: rect.width * rect.height * drawer.bytesInPixel
        )

        try renderUpdateBuffer(
            text,
            &frameBuffer,
            color: color
        )

        try drawer.update(
            x: coordinates.x,
            y: coordinates.y,
            width: rect.width,
            height: rect.height,
            frameBuffer: frameBuffer
        )
    }

    func renderUpdateBuffer(
        _ line: String,
        _ frameBuffer: inout [UInt8],
        color: UInt16
    ) throws {
        var pixel = frameBuffer.count - font.height * drawer.bytesInPixel
        for char in line {
            let bitmap = try font.Glyph(char: char).bitmap
            for x in 0..<font.width {
                for y in 0..<font.height {
                    renderPixel(
                        pixel,
                        in: &frameBuffer,
                        at: (x, y),
                        with: bitmap,
                        color: color
                    )
                }
                pixel -= font.height * drawer.bytesInPixel
            }
            pixel -= font.height * drawer.bytesInPixel * font.advance
        }
    }

    func renderPixel(
        _ pixel: Int,
        in frameBuffer: inout [UInt8],
        at point: (x: Int, y: Int),
        with bitmap: borrowing [UInt8],
        color: UInt16
    ) {
        let glyphY = font.height - point.y - 1
        let bitIndex = glyphY * font.width + point.x
        let byteIndex = bitIndex / 8
        let bitOffset = 7 - (bitIndex % 8)
        let isFilled = bitmap[byteIndex] & (1 << bitOffset) != 0
        let color = isFilled ? color : backgroundColor
        let colorHighByte = UInt8(color >> 8)
        let colorLowByte = UInt8(color & 0x00FF)
        frameBuffer[pixel + point.y * drawer.bytesInPixel] = colorHighByte
        frameBuffer[pixel + point.y * drawer.bytesInPixel + 1] = colorLowByte
    }
}
