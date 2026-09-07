actor S1PanelController {
    let displayInterface: DisplayManager & DisplayDrawer
    var screenRenderer: ScreenRenderer
    var keepDisplayAliveTask: Task<Void, any Error>!

    init(displayInterface: DisplayManager & DisplayDrawer) {
        self.displayInterface = displayInterface
        self.screenRenderer = TextScreen(drawer: displayInterface)
    }

    deinit {
        keepDisplayAliveTask.cancel()
        keepDisplayAliveTask = nil
    }
}

extension S1PanelController: PanelController {
    func start() async throws {
        keepDisplayAliveTask = Task {
            while !Task.isCancelled {
                try displayInterface.keepDisplayAlive()
                try await Task.sleep(for: .seconds(1))
            }
        }

        try await screenRenderer.start()
    }
}
