import Foundation
enum ScheduleType: Int, Equatable {
    case weekday = 0
    case weekend = 1
    case holiday = 2
    var label: String {
        switch self {
        case .weekday:  return "Weekday"
        case .weekend:  return "Weekend"
        case .holiday:  return "Holiday"
        }
    }
}
struct Schedule: Codable {
    let specialDates: [String: Int]
    let northStops: [String]
    let southStops: [String]
    let northWeekday: [String: [Int?]]
    let northWeekend: [String: [Int?]]
    let northHoliday: [String: [Int?]]
    let southWeekday: [String: [Int?]]
    let southWeekend: [String: [Int?]]
    let southHoliday: [String: [Int?]]
    let scheduleDate: Int?  // epoch ms; matches PWA's scheduleDate (stop_times.txt mtime)
    private static let remoteURL = URL(string: "https://next-caltrain-pwa.appspot.com/schedule.json")!
    private static var cachedFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("schedule.json")
    }
    // Not private so unit tests (@testable import) can read/write the same key
    // directly instead of hardcoding the string.
    static let lastFetchKey = "lastFetchTime"
    /// Loads a valid cached schedule from disk, if one exists.
    static func loadCached() -> Schedule? {
        guard let cached = try? Data(contentsOf: cachedFileURL),
              let schedule = try? JSONDecoder().decode(Schedule.self, from: cached),
              schedule.isValid else {
            return nil
        }
        return schedule
    }
    /// True if the last successful network fetch landed on today's schedule-day
    /// (2am boundary, see GoodTimes.scheduleDateFor). Used to skip redundant
    /// network calls once we already have today's data.
    static func fetchedToday() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastFetchKey) as? Date else {
            return false
        }
        return GoodTimes.scheduleDateFor(last) == GoodTimes.scheduleDateFor(Date())
    }
    private static func markFetched() {
        UserDefaults.standard.set(Date(), forKey: lastFetchKey)
    }
    /// Basic structural validation: stop lists are non-empty, and every schedule
    /// table's train arrays match the length of their direction's stop list.
    var isValid: Bool {
        guard !northStops.isEmpty, !southStops.isEmpty else { return false }
        let northTables = [northWeekday, northWeekend, northHoliday]
        let southTables = [southWeekday, southWeekend, southHoliday]
        for table in northTables {
            for (_, times) in table where times.count != northStops.count {
                return false
            }
        }
        for table in southTables {
            for (_, times) in table where times.count != southStops.count {
                return false
            }
        }
        return true
    }
    /// Fetches the latest published schedule from the network. If valid, writes
    /// it to the local cache for use on future launches and returns it.
    /// Throws on network/decode/validation failure.
    static func fetchFromNetwork() async throws -> Schedule {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let schedule = try JSONDecoder().decode(Schedule.self, from: data)
        guard schedule.isValid else {
            throw URLError(.cannotParseResponse)
        }
        try? data.write(to: cachedFileURL, options: .atomic)
        markFetched()
        return schedule
    }
}
struct CaltrainSchedule {
    static func optionIndex(date: String, dotw: Int, specialDates: [String: Int]) -> ScheduleType {
        if let type = specialDates[date] {
            return ScheduleType(rawValue: type) ?? .weekday
        } else if dotw == 0 || dotw == 6 {
            return .weekend
        } else {
            return .weekday
        }
    }
}
