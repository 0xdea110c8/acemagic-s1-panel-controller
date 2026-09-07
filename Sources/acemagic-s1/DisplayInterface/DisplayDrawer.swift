protocol DisplayDrawer: Sendable {
    var displayWidth: Int { get }
    var displayHeight: Int { get }
    var bytesInPixel: Int { get }

    func draw(_ frameBuffer: [UInt8]) throws
    func update(x: Int, y: Int, width: Int, height: Int, frameBuffer: [UInt8]) throws
}
