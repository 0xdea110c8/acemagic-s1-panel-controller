enum Logger {
    static func log(_ message: @escaping @autoclosure () -> String) {
        #if DEBUG
            print(message())
        #endif    // DEBUG
    }

    static func log(
        _ messages: (any CustomStringConvertible)...,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        #if DEBUG
            print(
                messages
                    .map { $0.description }
                    .joined(separator: separator),
            )
        #endif
    }

    static func log(
        _ items: Any...,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        #if DEBUG
            print(items, separator, terminator)
        #endif
    }
}
