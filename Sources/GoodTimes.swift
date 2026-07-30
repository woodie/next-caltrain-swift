import Foundation

struct GoodTimes {
    let date: String
    let minutes: Int
    let seconds: Int
    let dotw: Int
    let tomorrowDate: String
    let tomorrowDotw: Int

    // Ambient fallback for init() (GoodTimes()) -- exists only for callers that construct
    // GoodTimes() internally and can't take a seed as a parameter (e.g. TripViewModel).
    // Anything that constructs GoodTimes itself should call seeded(dotw:mins:) directly
    // instead and leave these alone.
    static var dotwSeed: Int?
    static var minutesSeed: Int?

    private static var didLog = false

    private init(date: String, minutes: Int, seconds: Int, dotw: Int, tomorrowDate: String, tomorrowDotw: Int) {
        self.date = date
        self.minutes = minutes
        self.seconds = seconds
        self.dotw = dotw
        self.tomorrowDate = tomorrowDate
        self.tomorrowDotw = tomorrowDotw
    }

    init(date: Date = Date()) {
        self = GoodTimes.seeded(dotw: GoodTimes.dotwSeed, mins: GoodTimes.minutesSeed, referenceDate: date)
    }

    // dotw (0=Sunday...6=Saturday) and/or mins (minutes since midnight) pin the fields that
    // would otherwise come from the real clock -- resolved directly from the arguments, so
    // there's nothing global to reset afterward.
    static func seeded(dotw: Int? = nil, mins: Int? = nil, referenceDate: Date = Date()) -> GoodTimes {
        let run = referenceDate.addingTimeInterval(-2 * 3600)
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: run)!

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let realDotw = cal.component(.weekday, from: run) - 1
        let resolvedDotw = dotw ?? realDotw
        let tomorrowDotw = (resolvedDotw + 1) % 7

        let resolvedMinutes: Int
        let resolvedSeconds: Int
        if let mins {
            resolvedMinutes = mins
            resolvedSeconds = 0
        } else {
            let h = cal.component(.hour, from: run)
            let m = cal.component(.minute, from: run)
            resolvedMinutes = (h + 2) * 60 + m
            resolvedSeconds = cal.component(.second, from: run)
        }

        let gt = GoodTimes(
            date: fmt.string(from: run),
            minutes: resolvedMinutes,
            seconds: resolvedSeconds,
            dotw: resolvedDotw,
            tomorrowDate: fmt.string(from: tomorrow),
            tomorrowDotw: tomorrowDotw
        )
        GoodTimes.logOnce(gt)
        return gt
    }

    private static func logOnce(_ gt: GoodTimes) {
        #if DEBUG
        guard !didLog else { return }
        didLog = true
        let (t, mer) = GoodTimes.partTime(gt.minutes)
        print("[GoodTimes] minutes=\(gt.minutes) (\(t)\(mer)) seconds=\(gt.seconds) " +
              "dotw=\(gt.dotw) date=\(gt.date) tomorrowDotw=\(gt.tomorrowDotw) tomorrowDate=\(gt.tomorrowDate) " +
              "dotwSeed=\(String(describing: dotwSeed)) " +
              "minutesSeed=\(String(describing: minutesSeed))")
        #endif
    }

    // MARK: - Static formatting

    /// Schedule-day (yyyy-MM-dd) for `date`, using the same "day starts at 2am" rule as `init()`.
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
        if hrs < 1 { hrs = 12 }
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
