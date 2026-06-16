import Foundation

struct GoodTimes {
    let date: String
    let minutes: Int
    let seconds: Int
    let dotw: Int
    let tomorrowDate: String
    let tomorrowDotw: Int

    // TEMPORARY DEBUG HACK: set to override "now" for testing (e.g. early morning).
    // Set to nil for normal behavior. Format: minutes since midnight, e.g. 330 = 5:30am.
    static var debugOverrideMinutes: Int? = nil

    // TEMPORARY DEBUG HACK: set to override the day-of-week for testing
    // (e.g. force "today" to be Friday so tomorrow is Saturday/weekend).
    // 0 = Sunday ... 6 = Saturday. Set to nil for normal behavior.
    static var debugOverrideDotw: Int? = nil

    // TEMPORARY DEBUG HACK: prints computed values once on first init, useful
    // when testing debugOverrideMinutes/debugOverrideDotw.
    private static var didLog = false

    init(date: Date = Date()) {
        let run = date.addingTimeInterval(-2 * 3600)
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: run)!

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let realDotw = cal.component(.weekday, from: run) - 1
        let dotw = GoodTimes.debugOverrideDotw ?? realDotw
        let tomorrowDotw = (dotw + 1) % 7

        if let overrideMinutes = GoodTimes.debugOverrideMinutes {
            self.minutes = overrideMinutes
            self.seconds = 0
            self.dotw = dotw
            self.date = fmt.string(from: run)
            self.tomorrowDate = fmt.string(from: tomorrow)
            self.tomorrowDotw = tomorrowDotw
            GoodTimes.logOnce(self)
            return
        }

        let h = cal.component(.hour, from: run)
        let m = cal.component(.minute, from: run)
        let s = cal.component(.second, from: run)
        self.minutes = (h + 2) * 60 + m
        self.seconds = s
        self.dotw = dotw
        self.date = fmt.string(from: run)
        self.tomorrowDate = fmt.string(from: tomorrow)
        self.tomorrowDotw = tomorrowDotw
        GoodTimes.logOnce(self)
    }

    private static func logOnce(_ gt: GoodTimes) {
        guard !didLog else { return }
        didLog = true
        let (t, mer) = GoodTimes.partTime(gt.minutes)
        print("[GoodTimes] minutes=\(gt.minutes) (\(t)\(mer)) seconds=\(gt.seconds) " +
              "dotw=\(gt.dotw) date=\(gt.date) tomorrowDotw=\(gt.tomorrowDotw) tomorrowDate=\(gt.tomorrowDate) " +
              "debugOverrideMinutes=\(String(describing: debugOverrideMinutes)) " +
              "debugOverrideDotw=\(String(describing: debugOverrideDotw))")
    }

    // MARK: - Static formatting

    /// Returns the yyyy-MM-dd schedule-day string for an arbitrary instant, using
    /// the same "day starts at 2am" rule as init(): subtract 2 hours before formatting.
    /// Lets us compare "today" against a stored last-fetch timestamp for the
    /// once-per-day schedule fetch policy.
    static func scheduleDateFor(_ date: Date) -> String {
        let run = date.addingTimeInterval(-2 * 3600)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: run)
    }

    static func partTime(_ minutes: Int) -> (String, String) {
        var hrs = (minutes / 60) % 24
        let min = minutes % 60
        let mer = (hrs > 11 && hrs < 24) ? "pm" : "am"
        if hrs > 12 { hrs -= 12 }
        if hrs > 12 { hrs -= 12 }
        if hrs < 1  { hrs = 12 }
        return (String(format: "%d:%02d", hrs, min), mer)
    }

    static func fullTime(_ minutes: Int) -> String {
        let (t, mer) = partTime(minutes)
        return t + mer
    }

    // MARK: - Instance methods

    func partTime() -> (String, String) { GoodTimes.partTime(minutes) }
    func fullTime() -> String { GoodTimes.fullTime(minutes) }

    func inThePast(_ target: Int) -> Bool {
        return target - minutes < 0
    }

    func departing(_ target: Int) -> Bool {
        return target == minutes
    }

    func countdown(_ target: Int) -> String {
        let diff = target - minutes - 1
        if diff < 0 {
            return ""
        } else if diff > 59 {
            return "in \(diff / 60) hr \(diff % 60) min"
        } else {
            return "in \(diff) min \(60 - seconds) sec"
        }
    }
}
