import Foundation

func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func fixedDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    minute: Int = 0
) -> Date {
    fixedCalendar().date(
        from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

func dueComponents(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int? = nil,
    minute: Int? = nil
) -> DateComponents {
    var components = DateComponents(
        calendar: fixedCalendar(),
        timeZone: hour == nil ? nil : TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day
    )
    components.hour = hour
    components.minute = minute
    return components
}
