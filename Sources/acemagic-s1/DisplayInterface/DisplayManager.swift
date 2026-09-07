protocol DisplayManager: Sendable {
    func keepDisplayAlive() throws
    func setPortraitOrientation() throws
    func setLandscapeOrientation() throws
}
