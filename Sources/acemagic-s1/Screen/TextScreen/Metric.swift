import Foundation

protocol StringLine {
    var stringRepresentation: String { get }
}

protocol LiveLine {
    mutating func update() -> [LineUpdate]
}

struct LineUpdate {
    let index: Int
    let value: String
    let color: RGB565
}

typealias StringLiveLine = StringLine & LiveLine

struct IntMetricLine: StringLiveLine {
    private let name: String
    private var currentValue: Int
    private var currentColor: RGB565
    private let valueGetter: () -> Int
    private let color: RGB565
    private let warningColor: RGB565?
    private let warningRange: Range<Int>?
    private let criticalColor: RGB565?
    private let criticalRange: ClosedRange<Int>?

    var stringRepresentation: String {
        let paddedName = name.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "\(paddedName)\(String(format: "%4d", currentValue))"
    }

    init(
        name: String,
        currentValue: Int = 0,
        valueGetter: @escaping @autoclosure () -> Int,
        color: RGB565,
        warningColor: RGB565? = nil,
        warningRange: Range<Int>? = nil,
        criticalColor: RGB565? = nil,
        criticalRange: ClosedRange<Int>? = nil
    ) {
        precondition(name.count <= 4)
        self.name = name
        self.currentValue = currentValue
        self.valueGetter = valueGetter
        self.color = color
        self.warningColor = warningColor
        self.warningRange = warningRange
        self.criticalColor = criticalColor
        self.criticalRange = criticalRange
        if let warningRange, warningRange.contains(currentValue), let warningColor {
            currentColor = warningColor
        }
        if let criticalRange, criticalRange.contains(currentValue), let criticalColor {
            currentColor = criticalColor
        }
        currentColor = color
    }

    mutating func update() -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let newValue = valueGetter()
        guard newValue != currentValue else { return updates }
        defer { currentValue = newValue }
        var color = color
        if let warningRange, warningRange.contains(newValue), let warningColor {
            color = warningColor
        }
        if let criticalRange, criticalRange.contains(newValue), let criticalColor {
            color = criticalColor
        }
        defer { currentColor = color }
        if color != currentColor {
            updates.append(LineUpdate(index: 0, value: name, color: color))
        }
        updates.append(LineUpdate(index: 10, value: String(format: "%4d", newValue), color: color))
        return updates
    }
}

struct AWGMetricLine: StringLiveLine {
    private let name: String = "AWG"
    private var currentValue: String
    private var currentColor: RGB565
    private let valueGetter: () -> [String]
    private let color: RGB565

    var stringRepresentation: String {
        let paddedName = name.padding(toLength: 10, withPad: " ", startingAt: 0)
        return "\(paddedName)\(currentValue)"
    }

    init(
        valueGetter: @escaping @autoclosure () -> [String],
        color: RGB565
    ) {
        self.currentValue = "DOWN"
        self.currentColor = color
        self.valueGetter = valueGetter
        self.color = color
    }

    mutating func update() -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let newValues = valueGetter()
        guard let newValue = newValues.first, newValue != currentValue else { return updates }
        updates.append(LineUpdate(index: 10, value: String(newValue.prefix(4)), color: currentColor))
        return updates
    }
}

struct UptimeMetricLine: StringLiveLine {
    private let valueGetter: () -> Int
    private var days: Int
    private var hours: Int
    private var minutes: Int
    private let color: RGB565

    var stringRepresentation: String {
        let shownDays = self.days > 999 ? 999 : days
        let daysString = String(format: "%03d", shownDays)
        let hoursString = String(format: "%02d", hours)
        let minutesString = String(format: "%02d", minutes)
        return "\(daysString):\(hoursString):\(minutesString)"
    }

    init(
        valueGetter: @escaping @autoclosure () -> Int,
        color: RGB565
    ) {
        self.valueGetter = valueGetter
        self.days = 0
        self.hours = 0
        self.minutes = 0
        self.color = color
    }

    mutating func update() -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let newValue = valueGetter()
        let days = newValue / 86_400
        let hours = (newValue % 86_400) / 3_600
        let minutes = (newValue % 3_600) / 60
        if days != self.days {
            self.days = days
            let shownDays = days > 999 ? 999 : days
            updates.append(LineUpdate(index: 0, value: String(format: "%03d", shownDays), color: color))
        }
        if hours != self.hours {
            self.hours = hours
            updates.append(LineUpdate(index: 4, value: String(format: "%02d", hours), color: color))
        }
        if minutes != self.minutes {
            self.minutes = minutes
            updates.append(LineUpdate(index: 7, value: String(format: "%02d", minutes), color: color))
        }
        return updates
    }
}

struct EmptyLine: StringLiveLine {
    var stringRepresentation: String {
        ""
    }

    mutating func update() -> [LineUpdate] {
        []
    }
}

struct ClockMetricLine: StringLiveLine {
    var hour: Int = 0
    var minute: Int = 0
    var day: Int = 0
    var month: Int = 0
    var color: RGB565
    var stringRepresentation: String {
        let hourString = String(format: "%02d", hour)
        let minuteString = String(format: "%02d", minute)
        let dayString = String(format: "%02d", day)
        let monthString = String(format: "%02d", month)
        return "\(hourString):\(minuteString)    \(dayString)/\(monthString)"
    }

    mutating func update() -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let timeComponents = Calendar.current.timeComponents()
        let dateComponents = Calendar.current.dateComponents()
        if timeComponents.hour != hour {
            hour = timeComponents.hour
            updates.append(LineUpdate(index: 0, value: String(format: "%02d", hour), color: color))
        }
        if timeComponents.minute != minute {
            minute = timeComponents.minute
            updates.append(LineUpdate(index: 3, value: String(format: "%02d", minute), color: color))
        }
        if dateComponents.day != day {
            day = dateComponents.day
            updates.append(LineUpdate(index: 9, value: String(format: "%02d", day), color: color))
        }
        if dateComponents.month != month {
            month = dateComponents.month
            updates.append(LineUpdate(index: 12, value: String(format: "%02d", month), color: color))
        }
        return updates
    }
}
