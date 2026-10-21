import Foundation

/// Like Google Maps' "Leave at" / "Arrive by".
enum PlanMode: String, CaseIterable {
    case leave = "Leave at"
    case arrive = "Arrive by"
}

struct PlannedTrain: Equatable {
    let label: String
    let depart: Int  // minutes since midnight
    let arrive: Int
    let selected: Bool
}

/// Planning a trip for the calendar: the planned train plus the trains
/// before and after it, and the event. Ported from next-caltrain-react's
/// `CalendarTrip.ts`; the event goes through the phone's own calendar
/// instead of a Google Calendar link.
enum CalendarTrip {
    /// Caltrain runs on Pacific time, whatever the phone's own time zone is.
    static let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// The planned train's index in `trips` (sorted by departure): the first
    /// departing at or after `minutes` (leave), or the last arriving at or
    /// before it (arrive); nil if no train fits.
    static func find(_ trips: [Trip], mode: PlanMode, minutes: Int) -> Int? {
        switch mode {
        case .leave: return trips.firstIndex { $0.depart >= minutes }
        case .arrive: return trips.lastIndex { $0.arrive <= minutes }
        }
    }

    /// The planned train with the trains before and after it.
    static func neighbors(_ trips: [Trip], index: Int) -> [PlannedTrain] {
        (index - 1...index + 1).filter { trips.indices.contains($0) }.map { i in
            let trip = trips[i]
            return PlannedTrain(
                label: trip.legs.map { "#\($0.trainId)" }.joined(separator: "+"),
                depart: trip.depart,
                arrive: trip.arrive,
                selected: i == index
            )
        }
    }

    static func line(_ train: PlannedTrain) -> String {
        "\(train.label)  \(GoodTimes.fullTime(train.depart)) – \(GoodTimes.fullTime(train.arrive))"
    }

    static func title(destination: String) -> String {
        "Caltrain to \(destination)"
    }

    /// The event notes: the route, then the trains. The event's own times
    /// already say which one is planned, so the notes don't mark it.
    static func notes(origin: String, destination: String, trains: [PlannedTrain]) -> String {
        (["\(origin) to \(destination)"] + trains.map(line)).joined(separator: "\n")
    }

    /// Minutes past midnight on an ISO date (YYYY-MM-DD), on Pacific time;
    /// times past midnight (> 1440) roll over to the next day.
    static func date(_ isoDate: String, minutes: Int) -> Date? {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: parts[0], month: parts[1], day: parts[2] + minutes / 1440,
            hour: minutes % 1440 / 60, minute: minutes % 60
        ))
    }

    /// Local ISO date (YYYY-MM-DD) for a Date, as the date picker shows it.
    static func isoDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Day of the week, 0 for Sunday, the way the schedule counts it.
    static func dotw(_ isoDate: String) -> Int {
        guard let day = date(isoDate, minutes: 12 * 60) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.weekday, from: day) - 1
    }
}
