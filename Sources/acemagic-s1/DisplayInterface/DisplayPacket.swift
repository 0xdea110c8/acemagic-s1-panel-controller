struct DisplayPacket {
    enum Byte {
        enum Set {
            enum Time { static let subcommand: UInt8 = 0xF3 }
            enum Heartbeat { static let subcommand: UInt8 = 0xF2 }

            enum Orientation {
                static let subcommand: UInt8 = 0xF1
                enum Portrait { static let value: UInt8 = 0x02 }
                enum Landscape { static let value: UInt8 = 0x01 }
            }

            static let command: UInt8 = 0xA1
        }

        enum Redraw {
            enum Start { static let subcommand: UInt8 = 0xF0 }
            enum Continue { static let subcommand: UInt8 = 0xF1 }
            enum End { static let subcommand: UInt8 = 0xF2 }
            static let command: UInt8 = 0xA3
        }

        enum Update {
            static let command: UInt8 = 0xA2
        }

        static let header: UInt8 = 0x55
    }

    static func time(hour: Int?, minute: Int?, second: Int?) -> [UInt8] {
        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Set.command
        packet.bytes[2] = Byte.Set.Time.subcommand
        packet.bytes[3] = hour.byte
        packet.bytes[4] = minute.byte
        packet.bytes[5] = second.byte
        return packet.bytes
    }

    static func heartbeat(hour: Int?, minute: Int?, second: Int?) -> [UInt8] {
        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Set.command
        packet.bytes[2] = Byte.Set.Heartbeat.subcommand
        packet.bytes[3] = hour.byte
        packet.bytes[4] = minute.byte
        packet.bytes[5] = second.byte
        return packet.bytes
    }

    static func portraitOrientation() -> [UInt8] {
        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Set.command
        packet.bytes[2] = Byte.Set.Orientation.subcommand
        packet.bytes[3] = Byte.Set.Orientation.Portrait.value
        return packet.bytes
    }

    static func landscapeOrientation() -> [UInt8] {
        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Set.command
        packet.bytes[2] = Byte.Set.Orientation.subcommand
        packet.bytes[3] = Byte.Set.Orientation.Landscape.value
        return packet.bytes
    }

    static func startRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Redraw.command
        packet.bytes[2] = Byte.Redraw.Start.subcommand
        packet.bytes[3] = chunk.byte
        packet.bytes[4] = offset.lowByte
        packet.bytes[5] = offset.highByte
        packet.bytes[6] = buffer.count.lowByte
        packet.bytes[7] = buffer.count.highByte

        packet.bytes.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet.bytes
    }

    static func continueRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Redraw.command
        packet.bytes[2] = Byte.Redraw.Continue.subcommand
        packet.bytes[3] = chunk.byte
        packet.bytes[4] = offset.lowByte
        packet.bytes[5] = offset.highByte
        packet.bytes[6] = buffer.count.lowByte
        packet.bytes[7] = buffer.count.highByte

        packet.bytes.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet.bytes
    }

    static func finishRedraw(chunk: Int, offset: Int, buffer: [UInt8]) -> [UInt8] {
        precondition((0x01...0x1B).contains(chunk))
        precondition((1...4096).contains(buffer.count))

        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Redraw.command
        packet.bytes[2] = Byte.Redraw.End.subcommand
        packet.bytes[3] = chunk.byte
        packet.bytes[4] = offset.lowByte
        packet.bytes[5] = offset.highByte
        packet.bytes[6] = buffer.count.lowByte
        packet.bytes[7] = buffer.count.highByte

        packet.bytes.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet.bytes
    }

    static func update(x: Int, y: Int, width: Int, height: Int, buffer: [UInt8]) -> [UInt8] {
        precondition(x < 170)
        precondition(y < 320)
        precondition(width * height <= 2048)
        precondition(buffer.count <= 4096)

        var packet = Self()
        packet.bytes[0] = Byte.header
        packet.bytes[1] = Byte.Update.command
        packet.bytes[2] = y.lowByte
        packet.bytes[3] = y.highByte
        packet.bytes[4] = x.lowByte
        packet.bytes[5] = x.highByte
        packet.bytes[6] = height.byte
        packet.bytes[7] = width.byte

        packet.bytes.replaceSubrange(8..<8 + buffer.count, with: buffer)
        return packet.bytes
    }

    private var bytes: [UInt8] = []

    init() {
        self.bytes.reserveCapacity(4104)
        self.bytes = .init(repeating: 0, count: 4104)
    }
}

extension Int? {
    fileprivate var byte: UInt8 {
        switch self {
            case .none:
                return 0x0
            case .some(let value):
                return value.byte
        }
    }
}

extension Int {
    fileprivate var byte: UInt8 {
        UInt8(self)
    }

    fileprivate var lowByte: UInt8 {
        UInt8(truncatingIfNeeded: self)
    }

    fileprivate var highByte: UInt8 {
        UInt8(truncatingIfNeeded: self >> 8)
    }
}

/*
 portrait:
 x: vertical (long) from upper right
 y: horizontal (short) from upper right
 width: vertical from upper right
 height: horizontal from upper rigth

 landscape:
 x: horizontal (long) from upper left
 y: vertical (short) from upper left
 width: vertical from upper right
 height: horizontal from upper rigth
 */
