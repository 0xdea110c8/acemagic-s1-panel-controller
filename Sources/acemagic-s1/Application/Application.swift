@preconcurrency import Dispatch

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

final class Application {
    var s1PanelController: PanelController!
    var screen: ScreenRenderer!

    init() {}

    func run() async throws {
        Logger.log("Acemagic S1 panel daemon started.")
        s1PanelController = S1PanelController(displayInterface: try DisplayInterface())
        try await s1PanelController.start()
        await waitForTermination()
        Logger.log("Acemagic S1 panel daemon stopped.")
    }

    private func waitForTermination() async {
        for await _ in TerminationSignal.stream() {
            break
        }
    }
}

enum TerminationSignal {
    @preconcurrency
    static func stream() -> AsyncStream<Int32> {
        AsyncStream { continuation in
            signal(SIGTERM, SIG_IGN)
            signal(SIGINT, SIG_IGN)

            let termSource = DispatchSource.makeSignalSource(
                signal: SIGTERM,
                queue: .main
            )

            let intSource = DispatchSource.makeSignalSource(
                signal: SIGINT,
                queue: .main
            )

            termSource.setEventHandler {
                continuation.yield(SIGTERM)
            }

            intSource.setEventHandler {
                continuation.yield(SIGINT)
            }

            termSource.resume()
            intSource.resume()

            continuation.onTermination = { _ in
                termSource.cancel()
                intSource.cancel()
            }
        }
    }
}
