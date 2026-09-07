import Foundation

struct DisplayInterface {
    let displayEndpoint: UInt8 = 0x02
    let displayTimeout: UInt32 = 2_000

    let display: USBDevice

    init(
        vendorID: UInt16 = 0x04D9,
        productID: UInt16 = 0x0FD01
    ) throws {
        display = try CLibUSBDevice(vendorID: vendorID, productID: productID)
        try display.claimInterface(1)
    }
}

extension DisplayInterface: DisplayManager {
    func keepDisplayAlive() throws {
        try setTime()
    }

    func setPortraitOrientation() throws {
        try display.interruptWrite(
            DisplayPacket.portraitOrientation(),
            to: displayEndpoint,
            with: displayTimeout
        )
    }

    func setLandscapeOrientation() throws {
        try display.interruptWrite(
            DisplayPacket.landscapeOrientation(),
            to: displayEndpoint,
            with: displayTimeout
        )
    }
}

extension DisplayInterface {
    @inline(__always)
    func setTime() throws {
        let timeComponents = getTimeComponents()

        try display.interruptWrite(
            DisplayPacket.time(
                hour: timeComponents.hour,
                minute: timeComponents.minute,
                second: timeComponents.second
            ),
            to: displayEndpoint,
            with: displayTimeout
        )
    }

    @inline(__always)
    func getTimeComponents() -> DateComponents {
        Calendar.current.dateComponents(
            [
                .hour,
                .minute,
                .second,
            ],
            from: Date()
        )
    }
}

extension DisplayInterface: DisplayDrawer {
    var displayWidth: Int { 170 }
    var displayHeight: Int { 320 }
    var bytesInPixel: Int { 2 }

    func draw(_ frameBuffer: [UInt8]) throws {
        precondition(frameBuffer.count == displayWidth * displayHeight * bytesInPixel)

        try getDrawPackets(from: frameBuffer)
            .forEach { packet in
                try display.interruptWrite(
                    packet,
                    to: displayEndpoint,
                    with: displayTimeout
                )
            }
    }

    func update(x: Int, y: Int, width: Int, height: Int, frameBuffer: [UInt8]) throws {
        try display.interruptWrite(
            DisplayPacket.update(
                x: x,
                y: y,
                width: width,
                height: height,
                buffer: frameBuffer
            ),
            to: displayEndpoint,
            with: displayTimeout
        )
    }
}

extension DisplayInterface {
    func getDrawPackets(from frameBuffer: [UInt8]) -> [[UInt8]] {
        var packets: [[UInt8]] = []
        packets.reserveCapacity(27)

        var chunk = 1
        var offset = 0

        while offset < frameBuffer.count {
            let length = min(4096, frameBuffer.count - offset)

            switch chunk {
                case 1:
                    packets.append(
                        DisplayPacket.startRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(frameBuffer[offset..<offset + length])
                        )
                    )
                case 27:
                    packets.append(
                        DisplayPacket.finishRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(frameBuffer[offset..<offset + length])
                        )
                    )
                default:
                    packets.append(
                        DisplayPacket.continueRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(frameBuffer[offset..<offset + length])
                        )
                    )
            }

            chunk += 1
            offset += length
        }

        return packets
    }
}
