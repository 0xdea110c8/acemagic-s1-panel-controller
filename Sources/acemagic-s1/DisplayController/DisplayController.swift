import Foundation
import Glibc

protocol ControlsDisplay {
    func prepareForTermination()
}

protocol DrawsContent {
}

final class DisplayController: @unchecked Sendable {
    private static let displaySerialLane = DispatchQueue(
        label: "acemagic-s1.lane.serial.display",
        target: .global(qos: .default)
    )

    private let state = State()
    private let vendorId: UInt16
    private let productId: UInt16
    private let interface: Int32
    private let endpoint: UInt8
    private let timeout: UInt32
    private unowned var delegate: DisplayControllerDelegate
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
        delegate: DisplayControllerDelegate
    ) {
        self.vendorId = vendorId
        self.productId = productId
        self.interface = interface
        self.endpoint = endpoint
        self.timeout = timeout
        self.delegate = delegate
        prepareDisplay()
    }

    private func prepareDisplay() {
        open()
        detachKernelDriver()
        claimInterface()
        state.isAllowedToWrite = true
        logEvent(.allowedToWrite)
        setDisplayResurrector()
    }

    private func open() {
        execute(
            {
                if !state.isOpen {
                    let result = try USBHID.open(vendorId: vendorId, productId: productId)
                    handle = result.handle
                    context = result.context
                    state.isOpen = true
                    logEvent(.opened)
                }
            },
            onFailure: closeDisplay
        )
    }

    private func detachKernelDriver() {
        execute(
            {
                if state.isOpen, let handle {
                    let hadKernelDriverAttached = try USBHID.detachKernelDriver(interface, handle: handle)
                    if hadKernelDriverAttached {
                        state.isKernelDriverDetached = true
                        logEvent(.kernelDriverDetached(interface))
                    } else {
                        state.hasNoKernelDriver = true
                        logEvent(.hadNoKernelDriver(interface))
                    }
                }
            },
            onFailure: closeDisplay
        )
    }

    private func claimInterface() {
        execute(
            {
                if state.isReadytoClaimInterface, let handle {
                    try USBHID.claimInterface(interface, handle: handle)
                    state.isInterfaceClaimed = true
                    logEvent(.interfaceClaimed(interface))
                }
            },
            onFailure: closeDisplay
        )
    }

    private func closeDisplay(facedErrorWhileOpening: Bool) {
        releaseInterface()
        attachKernelDriver()
        close()
        if facedErrorWhileOpening {
            delegate.facedErrorWhileOpening()
        } else {
            delegate.displayClosed()
        }
    }

    private func releaseInterface() {
        execute {
            if state.isInterfaceClaimed, let handle {
                try USBHID.releaseInterface(interface, handle: handle)
                state.isInterfaceClaimed = false
                logEvent(.interfaceReleased(interface))
            }
        }
    }

    private func attachKernelDriver() {
        execute {
            if state.isKernelDriverDetached, let handle {
                try USBHID.attachKernelDriver(interface, handle: handle)
                state.isKernelDriverDetached = false
                logEvent(.kernelDriverAttached(interface))
            }
        }
    }

    private func close() {
        execute {
            if state.isOpen, let handle, let context {
                USBHID.close(handle: handle, context: context)
                state.isOpen = false
                logEvent(.closed)
            }
        }
    }

    private func setDisplayResurrector() {
        let displayResurrector = DispatchSource.makeTimerSource(queue: DisplayController.displaySerialLane)
        displayResurrector.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(50))
        displayResurrector.setEventHandler { [self] in
            let time = Calendar.current.timeComponents()
            execute {
                if state.isReady, let handle {
                    let packet = DisplayPacket.time(time.hour, time.minute, time.second)
                    try USBHID.interruptWrite(packet, handle: handle, to: endpoint, with: timeout)
                    logEvent(.packetSent(packet))
                }
            }
        }
        displayResurrector.activate()
        logEvent(.resurrectorActivated)
        self.displayResurrector = displayResurrector
    }

    private func execute(_ block: () throws -> Void, onFailure: ((Bool) -> Void)? = nil) {
        do {
            try block()
        } catch let error as USBHID.USBHIDError {
            logUSBError(error)
            onFailure?(true)
        } catch {
            logUnknownUSBError(error)
            onFailure?(true)
        }
    }

    private func logEvent(_ event: Event) {
        Logger.log(deviceString, event)
    }

    private func logUSBError(_ error: USBHID.USBHIDError) {
        Logger.log(deviceString, error)
    }

    private func logUnknownUSBError(_ error: Error) {
        Logger.log(deviceString, error)
    }
}

extension DisplayController: ControlsDisplay {
    func prepareForTermination() {
        state.isAllowedToWrite = false
        logEvent(.disallowedToWrite)
        displayResurrector?.cancel()
        logEvent(.resurrectorDeactivated)
        closeDisplay(facedErrorWhileOpening: false)
    }
}

extension DisplayController: DrawsContent {
}

extension DisplayController {
    class State: @unchecked Sendable {
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
    enum Event: CustomStringConvertible {
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
