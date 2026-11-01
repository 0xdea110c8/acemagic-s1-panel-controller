import Foundation
import Glibc

protocol ControlsDisplay {
    func prepareForTermination()
}

protocol DrawsContent {
    static var displayWidth: Int { get }
    static var displayHeight: Int { get }
    static var bytesInPixel: Int { get }
    static func getRedrawBuffer(color: UInt16) -> [UInt8]
    static func getUpdateBuffer(count: Int, color: UInt16) -> [UInt8]
    func draw(_ buffer: [UInt8])
    func update(x: Int, y: Int, width: Int, height: Int, buffer: [UInt8])
}

final class DisplayController: @unchecked Sendable {
    private static let displaySerialLane = DispatchQueue(
        label: "acemagic-s1.lane.serial.display",
        target: .global(qos: .default)
    )
    private static let displayResurrectorSerialLane = DispatchQueue(
        label: "acemagic-s1.lane.serial.display.resurrector",
        target: .global(qos: .default)
    )

    private let state = State()
    private let vendorId: UInt16
    private let productId: UInt16
    private let interface: Int32
    private let endpoint: UInt8
    private let timeout: UInt32
    private unowned var delegate: any DisplayControllerDelegate
    private lazy var deviceString: String = { "Display (USB device \(vendorId):\(productId))\t" }()
    private var handle: OpaquePointer?
    private var context: OpaquePointer?
    private var displayResurrector: DispatchSourceTimer?

    init(
        vendorId: UInt16,
        productId: UInt16,
        interface: Int32,
        endpoint: UInt8,
        timeout: UInt32,
        delegate: any DisplayControllerDelegate
    ) {
        self.vendorId = vendorId
        self.productId = productId
        self.interface = interface
        self.endpoint = endpoint
        self.timeout = timeout
        self.delegate = delegate
        openDisplay()
    }

    private func openDisplay() {
        DisplayController.displaySerialLane.async { [self] in
            execute(
                {
                    // open display
                    if !state.isOpen {
                        let result = try USBHID.open(vendorId: vendorId, productId: productId)
                        handle = result.handle
                        context = result.context
                        state.isOpen = true
                        log(.opened)
                    }
                    if let handle {
                        // detach kernel driver
                        if state.isOpen {
                            let hadKernelDriverAttached = try USBHID.detachKernelDriver(interface, handle: handle)
                            if hadKernelDriverAttached {
                                state.isKernelDriverDetached = true
                                log(.kernelDriverDetached(interface))
                            } else {
                                state.hasNoKernelDriver = true
                                log(.hadNoKernelDriver(interface))
                            }
                        }
                        // claim interface
                        if state.isReadytoClaimInterface {
                            try USBHID.claimInterface(interface, handle: handle)
                            state.isInterfaceClaimed = true
                            log(.interfaceClaimed(interface))
                        }
                        // allow to send packets
                        state.isAllowedToWrite = true
                        log(.allowedToWrite)
                        // set display resurrector
                        let displayResurrector = DispatchSource.makeTimerSource(
                            queue: DisplayController.displayResurrectorSerialLane
                        )
                        displayResurrector.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(50))
                        displayResurrector.setEventHandler { [weak self] in
                            let time = Calendar.current.timeComponents()
                            let packet = DisplayPacket.time(time.hour, time.minute, time.second)
                            self?.interruptWrite(packet)
                        }
                        displayResurrector.activate()
                        log(.resurrectorActivated)
                        self.displayResurrector = displayResurrector
                    }
                },
                onFailure: closeDisplay
            )
        }
    }

    private func closeDisplay(facedErrorWhileOpening: Bool) {
        // forbid to send packets
        if state.isAllowedToWrite {
            state.isAllowedToWrite = false
            log(.disallowedToWrite)
        }
        DisplayController.displaySerialLane.async { [self] in
            // cancel display resurrector
            if let displayResurrector {
                displayResurrector.cancel()
                log(.resurrectorDeactivated)
            }
            execute {
                if let handle {
                    // release interface
                    if state.isInterfaceClaimed {
                        try USBHID.releaseInterface(interface, handle: handle)
                        state.isInterfaceClaimed = false
                        log(.interfaceReleased(interface))
                    }
                    // attach kernel driver back
                    if state.isKernelDriverDetached {
                        try USBHID.attachKernelDriver(interface, handle: handle)
                        state.isKernelDriverDetached = false
                        log(.kernelDriverAttached(interface))
                    }
                    // close display
                    if state.isOpen, let context {
                        USBHID.close(handle: handle, context: context)
                        state.isOpen = false
                        log(.closed)
                    }
                }
            }
            if facedErrorWhileOpening {
                delegate.facedErrorWhileOpening()
            } else {
                delegate.displayClosed()
            }
        }
    }

    private func interruptWrite(_ packet: [UInt8]) {
        DisplayController.displaySerialLane.async { [self] in
            execute {
                if state.isReady, let handle {
                    try USBHID.interruptWrite(packet, handle: handle, to: endpoint, with: timeout)
                    log(.packetSent(packet))
                }
            }
        }
    }

    private func execute(_ block: () throws -> Void, onFailure: ((Bool) -> Void)? = nil) {
        do {
            try block()
        } catch {
            log(error)
            onFailure?(true)
        }
    }

    private func log(_ event: Event) {
        Logger.log(deviceString, event, in: .debug)
    }

    private func log(_ error: Error) {
        Logger.log(deviceString, error, in: .prod)
    }
}

extension DisplayController: ControlsDisplay {
    func prepareForTermination() {
        closeDisplay(facedErrorWhileOpening: false)
    }
}

extension DisplayController: DrawsContent {
    static let displayWidth: Int = 170
    static let displayHeight: Int = 320
    static let bytesInPixel: Int = 2

    static func getRedrawBuffer(color: UInt16) -> [UInt8] {
        getUpdateBuffer(count: DisplayController.displayWidth * DisplayController.displayHeight, color: color)
    }

    static func getUpdateBuffer(count: Int, color: UInt16) -> [UInt8] {
        let high = UInt8(color >> 8)
        let low = UInt8(color & 0x00FF)
        return Array(
            repeating: [high, low],
            count: count
        )
        .flatMap { $0 }
    }

    func draw(_ buffer: [UInt8]) {
        precondition(
            buffer.count == DisplayController.displayWidth * DisplayController.displayHeight
                * DisplayController.bytesInPixel
        )
        DisplayController.splitIntoPackets(buffer)
            .forEach { packet in
                DisplayController.displaySerialLane.async { [weak self] in
                    self?.interruptWrite(packet)
                }
            }
    }

    func update(x: Int, y: Int, width: Int, height: Int, buffer: [UInt8]) {
        DisplayController.displaySerialLane.async { [weak self] in
            self?
                .interruptWrite(
                    DisplayPacket.update(
                        x: x,
                        y: y,
                        width: width,
                        height: height,
                        buffer: buffer
                    )
                )
        }
    }

    private static func splitIntoPackets(_ buffer: [UInt8]) -> [[UInt8]] {
        var packets: [[UInt8]] = []
        packets.reserveCapacity(27)

        var chunk = 1
        var offset = 0

        while offset < buffer.count {
            let length = min(4096, buffer.count - offset)
            switch chunk {
                case 1:
                    packets.append(
                        DisplayPacket.startRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(buffer[offset..<offset + length])
                        )
                    )
                case 27:
                    packets.append(
                        DisplayPacket.finishRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(buffer[offset..<offset + length])
                        )
                    )
                default:
                    packets.append(
                        DisplayPacket.continueRedraw(
                            chunk: chunk,
                            offset: offset,
                            buffer: Array(buffer[offset..<offset + length])
                        )
                    )
            }
            chunk += 1
            offset += length
        }
        return packets
    }
}

extension DisplayController {
    private class State: @unchecked Sendable {
        static let displayStateLane = DispatchQueue(
            label: "acemagic-s1.lane.concurrent.state.display",
            attributes: .concurrent,
            target: .global(qos: .default)
        )

        var isOpen: Bool {
            get {
                State.displayStateLane.sync {
                    _isOpen
                }
            }
            set {
                State.displayStateLane.async(flags: .barrier) { [self] in
                    _isOpen = newValue
                }
            }
        }

        var isKernelDriverDetached: Bool {
            get {
                State.displayStateLane.sync {
                    _isKernelDriverDetached
                }
            }
            set {
                State.displayStateLane.async(flags: .barrier) { [self] in
                    _isKernelDriverDetached = newValue
                }
            }
        }

        var hasNoKernelDriver: Bool {
            get {
                State.displayStateLane.sync {
                    _hasNoKernelDriver
                }
            }
            set {
                State.displayStateLane.async(flags: .barrier) { [self] in
                    _hasNoKernelDriver = newValue
                }
            }
        }

        var isReadytoClaimInterface: Bool {
            State.displayStateLane.sync {
                _isOpen && (_isKernelDriverDetached || _hasNoKernelDriver)
            }
        }

        var isInterfaceClaimed: Bool {
            get {
                State.displayStateLane.sync {
                    _isInterfaceClaimed
                }
            }
            set {
                State.displayStateLane.async(flags: .barrier) { [self] in
                    _isInterfaceClaimed = newValue
                }
            }
        }

        var isAllowedToWrite: Bool {
            get {
                State.displayStateLane.sync {
                    _isAllowedToWrite
                }
            }
            set {
                State.displayStateLane.async { [self] in
                    _isAllowedToWrite = newValue
                }
            }
        }

        var isReady: Bool {
            State.displayStateLane.sync {
                _isOpen && (_isKernelDriverDetached || _hasNoKernelDriver) && _isInterfaceClaimed && isAllowedToWrite
            }
        }

        private var _isOpen: Bool
        private var _isKernelDriverDetached: Bool
        private var _hasNoKernelDriver: Bool
        private var _isInterfaceClaimed: Bool
        private var _isAllowedToWrite: Bool

        init() {
            _isOpen = false
            _isKernelDriverDetached = false
            _hasNoKernelDriver = false
            _isInterfaceClaimed = false
            _isAllowedToWrite = false
        }
    }
}

extension DisplayController {
    private enum Event: CustomStringConvertible {
        case opened
        case kernelDriverDetached(Int32)
        case hadNoKernelDriver(Int32)
        case interfaceClaimed(Int32)
        case interfaceReleased(Int32)
        case kernelDriverAttached(Int32)
        case allowedToWrite
        case disallowedToWrite
        case transferred(Int)
        case closed
        case packetSent([UInt8])
        case resurrectorActivated
        case resurrectorDeactivated

        var description: String {
            switch self {
                case .opened:
                    return "opened"
                case .kernelDriverDetached(let interface):
                    return "kernel driver detached on interface \(interface)"
                case .hadNoKernelDriver(let interface):
                    return "had no kernel driver on interface \(interface)"
                case .interfaceClaimed(let interface):
                    return "claimed interface \(interface)"
                case .interfaceReleased(let interface):
                    return "released interface \(interface)"
                case .kernelDriverAttached(let interface):
                    return "attached kernel driver on interface \(interface)"
                case .allowedToWrite:
                    return "allowed to write"
                case .disallowedToWrite:
                    return "disallowed to write"
                case .transferred(let count):
                    return "transferred \(count) bytes"
                case .closed:
                    return "closed"
                case .packetSent(let packet):
                    let header = packet.prefix(8)
                        .map { String(format: "%02X", $0) }
                        .joined(separator: " ")
                    return "sent packet with header \(header)"
                case .resurrectorActivated:
                    return "resurrector activated"
                case .resurrectorDeactivated:
                    return "resurrector deactivated"
            }
        }
    }
}
