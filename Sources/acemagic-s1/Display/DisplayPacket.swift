enum DisplayPacket {
    static func time(_ hour: Int, _ minute: Int, _ second: Int) -> [UInt8] {
        var packet = packet
        packet[0] = Header.byte
        packet[1] = Set.byte
        packet[2] = Set.Time.byte
        packet[3] = hour.byte
        packet[4] = minute.byte
        packet[5] = second.byte
        return packet
    }

    static func heartbeat(_ hour: Int, _ minute: Int, _ second: Int) -> [UInt8] {
        var packet = packet
        packet[0] = Header.byte
        packet[1] = Set.byte
        packet[2] = Set.Heartbeat.byte
        packet[3] = hour.byte
        packet[4] = minute.byte
        packet[5] = second.byte
        return packet
    }

    static func portraitOrientation() -> [UInt8] {
        var packet = packet
        packet[0] = Header.byte
        packet[1] = Set.byte
        packet[2] = Set.Orientation.byte
        packet[3] = Set.Orientation.Portrait.byte
        return packet
    }

    static func landscapeOrientation() -> [UInt8] {
        var packet = packet
        packet[0] = Header.byte
        packet[1] = Set.byte
        packet[2] = Set.Orientation.byte
        packet[3] = Set.Orientation.Landscape.byte
        return packet
    }

    static func startRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = packet
        packet[0] = Header.byte
        packet[1] = Redraw.byte
        packet[2] = Redraw.Start.byte
        packet[3] = chunk.byte
        packet[4] = offset.lowerByte
        packet[5] = offset.upperByte
        packet[6] = buffer.count.lowerByte
        packet[7] = buffer.count.upperByte

        packet.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet
    }

    static func continueRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = packet
        packet[0] = Header.byte
        packet[1] = Redraw.byte
        packet[2] = Redraw.Continue.byte
        packet[3] = chunk.byte
        packet[4] = offset.lowerByte
        packet[5] = offset.upperByte
        packet[6] = buffer.count.lowerByte
        packet[7] = buffer.count.upperByte

        packet.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet
    }

    static func finishRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = packet
        packet[0] = Header.byte
        packet[1] = Redraw.byte
        packet[2] = Redraw.End.byte
        packet[3] = chunk.byte
        packet[4] = offset.lowerByte
        packet[5] = offset.upperByte
        packet[6] = buffer.count.lowerByte
        packet[7] = buffer.count.upperByte

        packet.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet
    }

    static func update(x: Int, y: Int, width: Int, height: Int, buffer: [UInt8]) -> [UInt8] {
        precondition(x < 170)
        precondition(y < 320)
        precondition(width * height <= 2048)
        precondition(buffer.count <= 4096)

        var packet = packet
        packet[0] = Header.byte
        packet[1] = Update.byte
        packet[2] = y.lowerByte
        packet[3] = y.upperByte
        packet[4] = x.lowerByte
        packet[5] = x.upperByte
        packet[6] = height.byte
        packet[7] = width.byte

        packet.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet
    }
}

extension DisplayPacket {
    fileprivate enum Header { static let byte: UInt8 = 0x55 }

    fileprivate enum Set {
        static let byte: UInt8 = 0xA1
        enum Time { static let byte: UInt8 = 0xF3 }
        enum Heartbeat { static let byte: UInt8 = 0xF2 }
        enum Orientation {
            static let byte: UInt8 = 0xF1
            enum Portrait { static let byte: UInt8 = 0x02 }
            enum Landscape { static let byte: UInt8 = 0x01 }
        }
    }

    fileprivate enum Redraw {
        static let byte: UInt8 = 0xA3
        enum Start { static let byte: UInt8 = 0xF0 }
        enum Continue { static let byte: UInt8 = 0xF1 }
        enum End { static let byte: UInt8 = 0xF2 }
    }

    fileprivate enum Update { static let byte: UInt8 = 0xA2 }

    fileprivate static var packet: [UInt8] {
        var packet: [UInt8] = []
        packet.reserveCapacity(4104)
        packet = .init(repeating: 0, count: 4104)
        return packet
    }
}
