import Dispatch
import Glibc

protocol DisplayControllerDelegate: AnyObject {
    func facedErrorWhileOpening()
    func displayClosed()
}

@main
final class Application: @unchecked Sendable {
    var state = State()
    var displayController: DisplayController!
    var screen: TextScreen?
    var sigint: DispatchSourceSignal?
    var sigterm: DispatchSourceSignal?

    private static func main() {
        let application = Application()
        application.launch()
    }

    func launch() {
        overrideTerminationSignal(SIGINT, &sigint)
        overrideTerminationSignal(SIGTERM, &sigterm)
        displayController = DisplayController(
            vendorId: 0x04D9,
            productId: 0x0FD01,
            interface: 1,
            endpoint: 0x02,
            timeout: 2_000,
            delegate: self
        )
        screen = TextScreen(drawer: displayController)
        dispatchMain()
    }

    func overrideTerminationSignal(_ __sig: Int32, _ _signal: inout DispatchSourceSignal?) {
        signal(__sig, SIG_IGN)
        let signal = DispatchSource.makeSignalSource(signal: __sig, queue: .main)
        signal.setEventHandler { [self] in
            state.insert(.isTerminating)
            displayController?.prepareForTermination()
        }
        signal.activate()
        _signal = signal
    }

    func checkTerminationPossibility() {
        let isTerminating = state.contains(.isTerminating)
        let isDisplayClosed = state.contains(.isDisplayClosed)

        if isTerminating && isDisplayClosed {
            let isTerminatingOnError = state.contains(.isTerminatingOnError)
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
