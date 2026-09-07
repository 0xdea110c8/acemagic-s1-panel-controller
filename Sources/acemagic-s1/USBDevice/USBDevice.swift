protocol USBDevice: Sendable {
    init(vendorID: UInt16, productID: UInt16) throws

    func claimInterface(_ interface: Int32) throws

    func interruptWrite(
        _ bytes: [UInt8],
        to endpoint: UInt8,
        with timeout: UInt32
    ) throws
}
