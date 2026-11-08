extension Int {
    var byte: UInt8 { UInt8(self) }
    var lowerByte: UInt8 { UInt8(truncatingIfNeeded: self) }
    var upperByte: UInt8 { UInt8(truncatingIfNeeded: self >> 8) }
}
