enum RGB565 {
    case black
    case white
    case red
    case yellow
    case green
    case darkGray

    var color: UInt16 {
        switch self {
            case .black:
                return 0x0000
            case .white:
                return 0xffff
            case .red:
                return 0x8800
            case .yellow:
                return 0xac40
            case .green:
                return 0x0440
            case .darkGray:
                return 0x31a6
        }
    }
}
