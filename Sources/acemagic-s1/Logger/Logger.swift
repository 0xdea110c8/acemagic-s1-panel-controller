enum Logger {
    static func log(_ message: @escaping @autoclosure () -> String) {
        #if DEBUG
            print(message())
        #endif    // DEBUG
    }
}
