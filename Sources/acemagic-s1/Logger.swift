enum Logger {
    enum Mode {
        case debug
        case prod
    }

    static func log(
        _ items: Any...,
        in mode: Mode,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        #if !DEBUG
            if case .debug = mode {
                return
            }
        #endif
        print(items, separator, terminator)
    }

}
