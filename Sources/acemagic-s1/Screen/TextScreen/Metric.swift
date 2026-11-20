import Foundation

protocol StringLine {
    func stringRepresentation(width: Int) -> String
}

protocol LiveLine {
    mutating func update(start: Int, width: Int) -> [LineUpdate]
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

    func stringRepresentation(width: Int) -> String {
        let value = String(format: "%4d", currentValue)
        let paddedName = name.padding(toLength: width - 4, withPad: " ", startingAt: 0)
        return "\(paddedName)\(value)"
    }

    mutating func update(start: Int, width: Int) -> [LineUpdate] {
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
            updates.append(LineUpdate(index: start, value: name, color: color))
        }
        updates.append(
            LineUpdate(
                index: start + width - 4,
                value: String(format: "%4d", newValue),
                color: color
            )
        )
        return updates
    }
}

struct AWGMetricLine: StringLiveLine {
    private let name: String = "AWG"
    private var currentValue: String
    private var currentColor: RGB565
    private let valueGetter: () -> [String]
    private let color: RGB565
    private let down: String = "DOWN"

    init(
        valueGetter: @escaping @autoclosure () -> [String],
        color: RGB565
    ) {
        self.currentValue = down
        self.currentColor = color
        self.valueGetter = valueGetter
        self.color = color
    }

    func stringRepresentation(width: Int) -> String {
        let paddedName = name.padding(toLength: width - 4, withPad: " ", startingAt: 0)
        return "\(paddedName)\(currentValue)"
    }

    mutating func update(start: Int, width: Int) -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let newValues = valueGetter()
        guard newValues.isEmpty else {
            let newValue = newValues[0]
            defer { currentValue = newValue }
            if newValue == currentValue {
                return updates
            }
            updates.append(
                LineUpdate(
                    index: start + width - 4,
                    value: String(newValue.uppercased().prefix(4)),
                    color: currentColor
                )
            )
            return updates
        }
        guard currentValue == down else {
            currentValue = down
            updates.append(
                LineUpdate(
                    index: start + width - 4,
                    value: down,
                    color: currentColor
                )
            )
            return updates
        }
        return updates
    }
}

struct UptimeMetricLine: StringLiveLine {
    private let valueGetter: () -> Int
    private var days: Int
    private var hours: Int
    private var minutes: Int
    private let color: RGB565

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

    func stringRepresentation(width: Int) -> String {
        let shownDays = self.days > 999 ? 999 : days
        let daysString = String(format: "%03d", shownDays)
        let hoursString = String(format: "%02d", hours)
        let minutesString = String(format: "%02d", minutes)
        return "\(daysString):\(hoursString):\(minutesString)"
    }

    mutating func update(start: Int, width: Int) -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let newValue = valueGetter()
        let days = newValue / 86_400
        let hours = (newValue % 86_400) / 3_600
        let minutes = (newValue % 3_600) / 60
        if days != self.days {
            self.days = days
            let shownDays = days > 999 ? 999 : days
            updates.append(
                LineUpdate(
                    index: start,
                    value: String(format: "%03d", shownDays),
                    color: color
                )
            )
        }
        if hours != self.hours {
            self.hours = hours
            updates.append(
                LineUpdate(
                    index: start + 4,
                    value: String(format: "%02d", hours),
                    color: color
                )
            )
        }
        if minutes != self.minutes {
            self.minutes = minutes
            updates.append(
                LineUpdate(
                    index: start + 7,
                    value: String(format: "%02d", minutes),
                    color: color
                )
            )
        }
        return updates
    }
}

struct EmptyLine: StringLiveLine {
    func stringRepresentation(width: Int) -> String {
        ""
    }

    mutating func update(start: Int, width: Int) -> [LineUpdate] {
        []
    }
}

struct ClockMetricLine: StringLiveLine {
    var hour: Int = 0
    var minute: Int = 0
    var day: Int = 0
    var month: Int = 0
    var color: RGB565

    func stringRepresentation(width: Int) -> String {
        let hourString = String(format: "%02d", hour)
        let minuteString = String(format: "%02d", minute)
        let dayString = String(format: "%02d", day)
        let monthString = String(format: "%02d", month)
        return "\(hourString):\(minuteString)    \(dayString)/\(monthString)"
    }

    mutating func update(start: Int, width: Int) -> [LineUpdate] {
        var updates: [LineUpdate] = []
        let timeComponents = Calendar.current.timeComponents()
        let dateComponents = Calendar.current.dateComponents()
        if timeComponents.hour != hour {
            hour = timeComponents.hour
            updates.append(
                LineUpdate(
                    index: start,
                    value: String(format: "%02d", hour),
                    color: color
                )
            )
        }
        if timeComponents.minute != minute {
            minute = timeComponents.minute
            updates.append(
                LineUpdate(
                    index: start + 3,
                    value: String(format: "%02d", minute),
                    color: color
                )
            )
        }
        if dateComponents.day != day {
            day = dateComponents.day
            updates.append(
                LineUpdate(
                    index: start + 9,
                    value: String(format: "%02d", day),
                    color: color
                )
            )
        }
        if dateComponents.month != month {
            month = dateComponents.month
            updates.append(
                LineUpdate(
                    index: start + 12,
                    value: String(format: "%02d", month),
                    color: color
                )
            )
        }
        return updates
    }
}
