import Foundation

final class TextScreen: @unchecked Sendable {
    private static let textScreenSerialLane = DispatchQueue(
        label: "acemagic-s1.serial.text-screen",
        target: .global(qos: .default)
    )
    private let font = IBMPlexMonoFont.self
    private let drawer: any DrawsContent
    private let monitor: any ProvidesSystemMetrics
    private var lineUpdater: DispatchSourceTimer?
    private var isPortrait: Bool { drawer.isPortrait }
    private var lines: [[(line: StringLiveLine, start: Int, width: Int)]]!

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
        if isPortrait {
            /*
            LOAD       000|
            CPU        000|
            TEMP       000|
            RAM        000|
            SWAP       000|
            DISK       000|
            RSSI       000|
            AWG        000|
                       000|
                       000|
                       000|
                       000|
                       000|
                       000|
                       000|
            00:00    00/00|
*/
            lines = [
                [(loadLine, 0, 14)],
                [(cpuLine, 0, 14)],
                [(tempLine, 0, 14)],
                [(ramLine, 0, 14)],
                [(swapLine, 0, 14)],
                [(diskLine, 0, 14)],
                [(rssiLine, 0, 14)],
                [(awgLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(emptyLine, 0, 14)],
                [(uptimeLine, 0, 14)],
                [(clockLine, 0, 14)],
            ]
        } else {
            /*
            LOAD 000 CPU  000 TEMP 000|
            RAM  000 SWAP 000 DISK 000|
            SIG -000 AWG DOWN XXXX 000|
                                      |
                                      |
                                      |
                                      |
            00:00 00/00      000:00:00|
*/
            lines = [
                [(loadLine, 0, 8), (cpuLine, 8, 8), (tempLine, 16, 8)],
                [(ramLine, 0, 8), (swapLine, 8, 8), (diskLine, 16, 8)],
                [(rssiLine, 0, 8), (awgLine, 8, 8)],
                [(emptyLine, 0, 24)],
                [(emptyLine, 0, 24)],
                [(emptyLine, 0, 24)],
                [(emptyLine, 0, 24)],
                [(clockLine, 0, 11), (uptimeLine, 17, 9)],
            ]
        }
    }

    private func redraw() {
        var buffer = type(of: drawer).getRedrawBuffer(color: RGB565.black.color)
        render(
            lines
                .compactMap {
                    $0
                        .map { $0.line.stringRepresentation(width: $0.width) }
                        .joined(separator: " ")
                }
                .joined(separator: "\n"),
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
                fatalError("No bitmap for char \(char) in \(font)")
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
                fatalError("No bitmap for char \(char) in \(font)")
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
            for i in 0..<lines.count {
                for j in 0..<lines[i].count {
                    let updates = lines[i][j].line
                        .update(
                            start: lines[i][j].start,
                            width: lines[i][j].width
                        )
                    updates.forEach {
                        updateText(
                            $0.value,
                            in: i,
                            at: $0.index,
                            color: $0.color.color
                        )
                    }
                }
            }
        }
        lineUpdater.schedule(deadline: .now() + 2.0, repeating: 1.0, leeway: .milliseconds(50))
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

extension TextScreen {
    var loadLine: IntMetricLine {
        IntMetricLine(
            name: "LOAD",
            valueGetter: self.monitor.loadAvg,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 60..<80,
            criticalColor: RGB565.red,
            criticalRange: 80...100
        )
    }

    var cpuLine: IntMetricLine {
        IntMetricLine(
            name: "CPU",
            valueGetter: self.monitor.cpuUsage,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 60..<80,
            criticalColor: RGB565.red,
            criticalRange: 80...100
        )
    }

    var tempLine: IntMetricLine {
        IntMetricLine(
            name: "TEMP",
            valueGetter: self.monitor.cpuTemp,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 80..<95,
            criticalColor: RGB565.red,
            criticalRange: 95...200
        )
    }

    var ramLine: IntMetricLine {
        IntMetricLine(
            name: "RAM",
            valueGetter: self.monitor.ramUsage,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 60..<80,
            criticalColor: RGB565.red,
            criticalRange: 80...100
        )
    }

    var swapLine: IntMetricLine {
        IntMetricLine(
            name: "SWAP",
            valueGetter: self.monitor.swapUsage,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 60..<80,
            criticalColor: RGB565.red,
            criticalRange: 80...100
        )
    }

    var diskLine: IntMetricLine {
        IntMetricLine(
            name: "DISK",
            valueGetter: self.monitor.diskUsage,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: 60..<80,
            criticalColor: RGB565.red,
            criticalRange: 80...100
        )
    }

    var rssiLine: IntMetricLine {
        IntMetricLine(
            name: "RSSI",
            valueGetter: self.monitor.rssi,
            color: RGB565.darkGray,
            warningColor: RGB565.yellow,
            warningRange: -75 ..< -66,
            criticalColor: RGB565.red,
            criticalRange: -1000 ... -75
        )
    }

    var awgLine: AWGMetricLine {
        AWGMetricLine(
            valueGetter: self.monitor.awgInterfaces,
            color: RGB565.darkGray
        )
    }

    var uptimeLine: UptimeMetricLine {
        UptimeMetricLine(
            valueGetter: self.monitor.uptime,
            color: RGB565.darkGray
        )
    }

    var clockLine: ClockMetricLine {
        ClockMetricLine(color: RGB565.darkGray)
    }

    var emptyLine: EmptyLine { EmptyLine() }
}
