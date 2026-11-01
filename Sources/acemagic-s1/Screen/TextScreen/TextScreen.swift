import Foundation

private protocol ProvidesValueUpdate {
}

final class TextScreen: @unchecked Sendable {
    private static let textScreenSerialLane = DispatchQueue(
        label: "acemagic-s1.lane.serial.screen.text",
        target: .global(qos: .default)
    )
    private let font = IBMPlexMonoFont.self
    private let drawer: any DrawsContent
    private let monitor: any ProvidesSystemMetrics
    private var lineUpdater: DispatchSourceTimer?
    private var lines: [StringLiveLine]!

    init(
        drawer: any DrawsContent,
        monitor: any ProvidesSystemMetrics = SystemMonitor()
    ) {
        self.drawer = drawer
        self.monitor = monitor
        TextScreen.textScreenSerialLane.async { [weak self] in
            guard let self else { return }
            addLines()
            redraw()
            setTimer()
        }
    }

    private func addLines() {
        lines = [
            IntMetricLine(
                name: "LOAD",
                valueGetter: self.monitor.loadAvg,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 60..<80,
                criticalColor: RGB565.red,
                criticalRange: 80...100
            ),
            IntMetricLine(
                name: "CPU",
                valueGetter: self.monitor.cpuUsage,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 60..<80,
                criticalColor: RGB565.red,
                criticalRange: 80...100
            ),
            IntMetricLine(
                name: "TEMP",
                valueGetter: self.monitor.cpuTemp,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 80..<95,
                criticalColor: RGB565.red,
                criticalRange: 95...150
            ),
            IntMetricLine(
                name: "RAM",
                valueGetter: self.monitor.ramUsage,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 60..<80,
                criticalColor: RGB565.red,
                criticalRange: 80...100
            ),
            IntMetricLine(
                name: "SWAP",
                valueGetter: self.monitor.swapUsage,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 60..<80,
                criticalColor: RGB565.red,
                criticalRange: 80...100
            ),
            IntMetricLine(
                name: "DISK",
                valueGetter: self.monitor.diskUsage,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: 60..<80,
                criticalColor: RGB565.red,
                criticalRange: 80...100
            ),
            IntMetricLine(
                name: "RSSI",
                valueGetter: self.monitor.rssi,
                color: RGB565.darkGray,
                warningColor: RGB565.yellow,
                warningRange: -75 ..< -66,
                criticalColor: RGB565.red,
                criticalRange: -200 ... -75
            ),
            AWGMetricLine(
                valueGetter: self.monitor.awgInterfaces,
                color: RGB565.darkGray
            ),
            EmptyLine(),
            EmptyLine(),
            EmptyLine(),
            EmptyLine(),
            EmptyLine(),
            EmptyLine(),
            UptimeMetricLine(
                valueGetter: self.monitor.uptime,
                color: RGB565.darkGray
            ),
            ClockMetricLine(color: RGB565.darkGray),
        ]
    }

    private func redraw() {
        var buffer = type(of: drawer).getRedrawBuffer(color: RGB565.black.color)
        render(
            lines.map { $0.stringRepresentation }.joined(separator: "\n"),
            in: &buffer,
            color: RGB565.darkGray.color
        )
        drawer.draw(buffer)
    }

    private func render(_ text: String, in buffer: inout [UInt8], color: UInt16) {
        let height = type(of: drawer).displayHeight
        let bytesInPixel = type(of: drawer).bytesInPixel
        var start = buffer.count - height * bytesInPixel
        var pixel = start
        let uppercasedText = text.uppercased()
        for char in uppercasedText {
            if char == "\n" {
                start += font.height * bytesInPixel
                pixel = start
                continue
            }
            do {
                let bitmap = try font.Glyph(char: char).bitmap
                for x in 0..<font.width {
                    for y in 0..<font.height {
                        renderPixel(
                            pixel,
                            in: &buffer,
                            at: (x, y),
                            with: bitmap,
                            color: color
                        )
                    }
                    pixel -= height * bytesInPixel
                }
                pixel -= height * bytesInPixel * font.advance
            } catch {
                #warning("handle bitmap error")
            }
        }
    }

    func renderUpdate(_ text: String, in buffer: inout [UInt8], color: UInt16) {
        let bytesInPixel = type(of: drawer).bytesInPixel
        var pixel = buffer.count - font.height * bytesInPixel
        let uppercasedText = text.uppercased()
        for char in uppercasedText {
            do {
                let bitmap = try font.Glyph(char: char).bitmap
                for x in 0..<font.width {
                    for y in 0..<font.height {
                        renderPixel(
                            pixel,
                            in: &buffer,
                            at: (x, y),
                            with: bitmap,
                            color: color
                        )
                    }
                    pixel -= font.height * bytesInPixel
                }
                pixel -= font.height * bytesInPixel * font.advance
            } catch {
                #warning("handle bitmap error")
            }
        }
    }

    private func renderPixel(
        _ pixel: Int,
        in frameBuffer: inout [UInt8],
        at point: (x: Int, y: Int),
        with bitmap: borrowing [UInt8],
        color: UInt16
    ) {
        let bytesInPixel = type(of: drawer).bytesInPixel
        let glyphY = font.height - point.y - 1
        let bitIndex = glyphY * font.width + point.x
        let byteIndex = bitIndex / 8
        let bitOffset = 7 - (bitIndex % 8)
        let isFilled = bitmap[byteIndex] & (1 << bitOffset) != 0
        let color = isFilled ? color : RGB565.black.color
        let colorHighByte = UInt8(color >> 8)
        let colorLowByte = UInt8(color & 0x00FF)
        frameBuffer[pixel + point.y * bytesInPixel] = colorHighByte
        frameBuffer[pixel + point.y * bytesInPixel + 1] = colorLowByte
    }

    private func setTimer() {
        let lineUpdater = DispatchSource.makeTimerSource(queue: TextScreen.textScreenSerialLane)
        lineUpdater.setEventHandler { [weak self] in
            guard let self else { return }
            for index in 0..<lines.count {
                let updates = lines[index].update()
                updates.forEach {
                    updateText($0.value, in: index, at: $0.index, color: $0.color.color)
                }
            }
        }
        lineUpdater.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))
        lineUpdater.activate()
        self.lineUpdater = lineUpdater
    }

    private func updateText(_ text: String, in line: Int, at index: Int, color: UInt16) {
        let displayWidth = type(of: drawer).displayWidth
        let coordinates = (
            x: displayWidth - 1 - font.width * (index + text.count),
            y: font.height * line
        )
        let rect = (width: font.width * text.count, height: font.height)
        var buffer: [UInt8] = type(of: drawer)
            .getUpdateBuffer(
                count: rect.width * rect.height,
                color: RGB565.black.color
            )
        renderUpdate(text, in: &buffer, color: color)
        drawer.update(
            x: coordinates.x,
            y: coordinates.y,
            width: rect.width,
            height: rect.height,
            buffer: buffer
        )
    }
}
