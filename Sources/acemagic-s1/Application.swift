import Dispatch
import Glibc

protocol DisplayControllerDelegate: AnyObject {
    func facedErrorWhileOpening()
    func displayClosed()
}

@main
final class Application: @unchecked Sendable {
    var state = State()
    var displayController: ControlsDisplay?
    var sigint: DispatchSourceSignal?
    var sigterm: DispatchSourceSignal?

    private static func main() {
        let application = Application()
        application.launch()
    }

    func launch() {
        overrideTerminationSignal(SIGINT, &sigint)
        overrideTerminationSignal(SIGTERM, &sigterm)
        createDisplayController()
        stopMainThread()
    }

    @inline(__always)
    func overrideTerminationSignal(_ _signal: Int32, _ overridenSignal: inout DispatchSourceSignal?) {
        signal(_signal, SIG_IGN)
        let signal = DispatchSource.makeSignalSource(signal: _signal, queue: .main)
        signal.setEventHandler { [self] in receivedTerminationSignal() }
        signal.activate()
        overridenSignal = signal
    }

    @inline(__always)
    func createDisplayController() {
        displayController = DisplayController(
            vendorId: 0x04D9,
            productId: 0x0FD01,
            interface: 1,
            endpoint: 0x02,
            timeout: 2_000,
            delegate: self
        )
    }

    @inline(__always)
    func stopMainThread() {
        dispatchMain()
    }

    func receivedTerminationSignal() {
        state.insert(.isTerminating)
        displayController?.prepareForTermination()
    }

    func checkTerminationPossibility() {
        let isTerminating = state.contains(.isTerminating)
        let isTerminatingOnError = state.contains(.isTerminatingOnError)
        let isDisplayClosed = state.contains(.isDisplayClosed)

        if isTerminating && isDisplayClosed {
            exit(isTerminatingOnError.int32Value)
        }
    }
}

extension Application: DisplayControllerDelegate {
    func facedErrorWhileOpening() {
        DispatchQueue.main.async { [self] in
            state.insert(.isTerminating)
            state.insert(.isTerminatingOnError)
            state.insert(.isDisplayClosed)
            checkTerminationPossibility()
        }
    }

    func displayClosed() {
        state.insert(.isDisplayClosed)
        checkTerminationPossibility()
    }
}

extension Application {
    struct State: OptionSet {
        static let isTerminating = State(1 << 0)
        static let isTerminatingOnError = State(1 << 1)
        static let isDisplayClosed = State(1 << 2)
        var rawValue: Int

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        init(_ rawValue: Int) {
            self.init(rawValue: rawValue)
        }

        init() {
            self.init(rawValue: 0)
        }
    }
}
