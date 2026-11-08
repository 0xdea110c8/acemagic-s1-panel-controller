import Foundation

extension Calendar {
    func timeComponents() -> (hour: Int, minute: Int, second: Int) {
        let dateComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        return (dateComponents.hour ?? 0, dateComponents.minute ?? 0, dateComponents.second ?? 0)
    }

    func dateComponents() -> (day: Int, month: Int, year: Int) {
        let dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date())
        return (dateComponents.day ?? 0, dateComponents.month ?? 0, dateComponents.year ?? 0)
    }
}
