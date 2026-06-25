import Foundation
@testable import NextCaltrain

/// Factory for building `Schedule` fixtures for specs.
///
/// `TripViewModel.init` defaults to `stopAM = 15` / `stopPM = 0` when no
/// saved preferences exist (matching the real schedule's station count), so
/// fixture stop lists must have at least 16 entries or `init` crashes with
/// an out-of-bounds array access.
///
/// The four stations that matter for routing/transfer logic are placed at
/// the ends and at meaningful interior positions; everything else is filler
/// ("Stop N") that no spec references directly:
///
///     index:    0              1..6      7              8..13   14           15
///     station:  San Francisco  Stop 1-6  San Jose Diridon  Stop 7-12  Morgan Hill  Gilroy
///
/// "South" means increasing index (SF -> Gilroy), matching
/// `CaltrainService.direction`. Electric trains (IDs 100-700) only run
/// SF <-> San Jose Diridon, since Caltrain doesn't own the electrified
/// tracks south of there. Diesel/South County trains (IDs 800-900) only run
/// San Jose Diridon <-> Gilroy. Any SF <-> Morgan Hill/Gilroy trip therefore
/// requires a transfer at San Jose Diridon, while a Morgan Hill <-> Gilroy
/// trip is direct (no transfer).
///
/// With the default indices (stopAM=15, stopPM=0), a freshly-initialized
/// `TripViewModel` defaults to Gilroy <-> San Francisco -- a transfer route
/// -- which is convenient for rollover/offset specs.
///
/// Building a schedule:
///
///     let schedule = SpecFixtures.schedule {
///         $0.weekday(electric: .normal, diesel: .normal)
///         $0.weekend(electric: .normal, diesel: .none)
///         $0.holiday(electric: .normal, diesel: .none)
///     }
///
/// Each leg (electric/diesel) for each schedule type can be `.normal`
/// (the default timetable below), `.none` (no trains -- e.g. South County
/// on weekends), or `.custom([...])` for hand-specified times.
enum SpecFixtures {
    static let sanFrancisco = "San Francisco"
    static let sanJoseDiridon = "San Jose Diridon"
    static let morganHill = "Morgan Hill"
    static let gilroy = "Gilroy"

    static let sanFranciscoIndex = 0
    static let sanJoseDiridonIndex = 7
    static let morganHillIndex = 14
    static let gilroyIndex = 15

    static let stopCount = 16

    /// Index order: SF=0 ... Gilroy=15 (South = increasing index), with
    /// filler "Stop N" stations in between so the fixture has >= 16 entries.
    static let stops: [String] = {
        var result = [String](repeating: "", count: stopCount)
        result[sanFranciscoIndex] = sanFrancisco
        result[sanJoseDiridonIndex] = sanJoseDiridon
        result[morganHillIndex] = morganHill
        result[gilroyIndex] = gilroy
        for i in 0..<stopCount where result[i].isEmpty {
            result[i] = "Stop \(i)"
        }
        return result
    }()

    static let northStops = Array(stops.reversed())

    static let electricSouthTrainId = 101
    static let electricNorthTrainId = 102
    static let dieselSouthTrainId = 801
    static let dieselNorthTrainId = 802

    /// A leg's service level for a given schedule type.
    enum Service {
        case normal
        case none
        case custom(southTimes: [Int?], northTimes: [Int?])
    }

    /// Builds a `Schedule` using the given configuration closure. Any
    /// schedule type not configured defaults to `.none` for both legs
    /// (i.e. an empty table), matching how real "no service" days behave.
    static func schedule(_ configure: (inout Builder) -> Void) -> Schedule {
        var builder = Builder()
        configure(&builder)
        return builder.build()
    }

    /// Convenience: a schedule with normal weekday service and no
    /// weekend/modified service at all (the most common fixture shape).
    static func weekdayOnlySchedule() -> Schedule {
        schedule {
            $0.weekday(electric: .normal, diesel: .normal)
        }
    }

    struct Builder {
        private var south: [ScheduleType: [String: [Int?]]] = [:]
        private var north: [ScheduleType: [String: [Int?]]] = [:]

        mutating func weekday(electric: Service = .none, diesel: Service = .none) {
            set(.weekday, electric: electric, diesel: diesel)
        }

        mutating func weekend(electric: Service = .none, diesel: Service = .none) {
            set(.weekend, electric: electric, diesel: diesel)
        }

        mutating func modified(electric: Service = .none, diesel: Service = .none) {
            set(.holiday, electric: electric, diesel: diesel)
        }

        private mutating func set(_ type: ScheduleType, electric: Service, diesel: Service) {
            var southTable: [String: [Int?]] = [:]
            var northTable: [String: [Int?]] = [:]

            switch electric {
            case .normal:
                // Electric southbound: SF(480) -> SJ(510), doesn't continue south.
                southTable[String(electricSouthTrainId)] = emptyRow(setting: [
                    sanFranciscoIndex: 480,
                    sanJoseDiridonIndex: 510
                ])
                // Electric northbound: SJ(520) -> SF(550).
                northTable[String(electricNorthTrainId)] = emptyRow(north: true, setting: [
                    sanJoseDiridonIndex: 520,
                    sanFranciscoIndex: 550
                ])
            case .none:
                break
            case .custom(let southTimes, let northTimes):
                southTable[String(electricSouthTrainId)] = southTimes
                northTable[String(electricNorthTrainId)] = northTimes
            }

            switch diesel {
            case .normal:
                // Diesel southbound: starts at SJ(515), Morgan Hill(535), Gilroy(545).
                southTable[String(dieselSouthTrainId)] = emptyRow(setting: [
                    sanJoseDiridonIndex: 515,
                    morganHillIndex: 535,
                    gilroyIndex: 545
                ])
                // Diesel northbound: Gilroy(420), Morgan Hill(430), SJ(450), doesn't reach SF.
                northTable[String(dieselNorthTrainId)] = emptyRow(north: true, setting: [
                    gilroyIndex: 420,
                    morganHillIndex: 430,
                    sanJoseDiridonIndex: 450
                ])
            case .none:
                break
            case .custom(let southTimes, let northTimes):
                southTable[String(dieselSouthTrainId)] = southTimes
                northTable[String(dieselNorthTrainId)] = northTimes
            }

            south[type] = southTable
            north[type] = northTable
        }

        /// Builds a `[Int?]` of length `stopCount`, all `nil` except at the
        /// given south-stop indices. If `north` is true, indices are
        /// converted to their position in `northStops` (the reverse order).
        private func emptyRow(north: Bool = false, setting values: [Int: Int]) -> [Int?] {
            var row = [Int?](repeating: nil, count: stopCount)
            for (southIndex, time) in values {
                let index = north ? (stopCount - 1 - southIndex) : southIndex
                row[index] = time
            }
            return row
        }

        func build() -> Schedule {
            Schedule(
                specialDates: [:],
                northStops: northStops,
                southStops: stops,
                northWeekday: north[.weekday] ?? [:],
                northWeekend: north[.weekend] ?? [:],
                northHoliday: north[.holiday] ?? [:],
                southWeekday: south[.weekday] ?? [:],
                southWeekend: south[.weekend] ?? [:],
                southHoliday: south[.holiday] ?? [:],
                scheduleDate: nil
            )
        }
    }
}
