import Foundation

enum ScheduleError: Error, LocalizedError, Equatable {
    case invalidResponse
    case server(Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server sent back something that wasn't a valid HTTP response."
        case .server(let code):
            return "The server responded with status \(code)."
        case .invalidData:
            return "The server sent back schedule data that didn't validate."
        }
    }
}

// Test seam matching zouk's ScanHTTPClient protocol -- lets ScheduleSpec fake server responses
// (status codes, bodies) without a real network call. The explicit forwarding conformance below
// is required for the same reason zouk's is: URLSession's real data(from:) takes a defaulted
// delegate: parameter, which doesn't satisfy a protocol requirement with no such parameter.
protocol ScheduleHTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: ScheduleHTTPClient {
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(from: url, delegate: nil)
    }
}

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
    // SCHEDULE_URL precedence (local.env > config.properties > this literal fallback); see docs/COWORK.md "Endpoint resolution".
    private static let remoteURL = URL(
        string: ProcessInfo.processInfo.environment["SCHEDULE_URL"]
            ?? "https://next-caltrain-pwa.appspot.com/feed/schedule.json"
    )!
    // Not private: tests (@testable import) check/clean up the real cache file directly.
    static let cacheFileName = "schedule.json"
    private static var cachedFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(cacheFileName)
    }
    // Not private: tests (@testable import) read/write this key directly instead of hardcoding the string.
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
    /// True if the last successful fetch landed on today's schedule-day (2am boundary; see GoodTimes.scheduleDateFor).
    static func fetchedToday() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastFetchKey) as? Date else {
            return false
        }
        return GoodTimes.scheduleDateFor(last) == GoodTimes.scheduleDateFor(Date())
    }
    private static func markFetched() {
        UserDefaults.standard.set(Date(), forKey: lastFetchKey)
    }
    /// Stop lists are non-empty and every schedule table's train arrays match their direction's stop-list length.
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
    /// Fetches the latest schedule, caches it to disk if valid, and returns it; throws on network/decode/validation failure.
    static func fetchFromNetwork(session: any ScheduleHTTPClient = URLSession.shared) async throws -> Schedule {
        let (data, response) = try await session.data(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScheduleError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ScheduleError.server(httpResponse.statusCode)
        }
        let schedule = try JSONDecoder().decode(Schedule.self, from: data)
        guard schedule.isValid else {
            throw ScheduleError.invalidData
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
