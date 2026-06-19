import SwiftUI
import Combine

class TripViewModel: ObservableObject {
    @Published var origin: String = "San Francisco"
    @Published var destination: String = "Palo Alto"
    @Published var scheduleType: ScheduleType = .weekday
    @Published var trips: [Trip] = []
    @Published var nextIndex: Int = 0
    @Published var offset: Int = 0
    private var userSelected: Bool = false
    var hasManualSelection: Bool { userSelected }
    @Published var goodTimes: GoodTimes = GoodTimes()

    let schedule: Schedule
    private let service: CaltrainService
    private var timer: AnyCancellable?

    private let kStopAM = "stopAM"
    private let kStopPM = "stopPM"

    /// Minutes-since-midnight offset applied to "tomorrow"'s trips so their
    /// depart/arrive times sort after today's and produce correct countdowns.
    /// Trips from the appended block are marked via `Trip.isFuture`.
    static let dayMinutes = 1440

    var swapped: Bool {
        let today = CaltrainSchedule.optionIndex(
            date: goodTimes.date,
            dotw: goodTimes.dotw,
            specialDates: schedule.specialDates
        )
        return scheduleType != today
    }

    /// The schedule type for tomorrow's date (used for trips appended after
    /// today's, identified by `Trip.depart >= TripViewModel.dayMinutes`).
    var tomorrowScheduleType: ScheduleType {
        return CaltrainSchedule.optionIndex(
            date: goodTimes.tomorrowDate,
            dotw: goodTimes.tomorrowDotw,
            specialDates: schedule.specialDates
        )
    }

    var serviceLabel: String {
        let trainId = trips.first?.legs.first?.trainId ?? 101
        return CaltrainService.trainType(trainId) + " Service"
    }

    var countdown: String? {
        guard offset < trips.count else { return nil }
        let c = goodTimes.countdown(trips[offset].depart)
        return c.isEmpty ? nil : c
    }

    var isDeparting: Bool {
        guard offset < trips.count else { return false }
        return goodTimes.departing(trips[offset].depart)
    }

    /// True if the currently-selected trip belongs to "tomorrow" (appended,
    /// shifted-by-dayMinutes trips).
    var isFutureSelected: Bool {
        guard offset < trips.count else { return false }
        return trips[offset].isFuture
    }

    private var isFlipped: Bool {
        return Calendar.current.component(.hour, from: Date()) >= 12
    }

    var orderedStations: [String] {
        let direction = CaltrainService.direction(
            from: origin,
            to: destination,
            stops: schedule.southStops
        )
        return direction == "South" ? schedule.southStops : schedule.southStops.reversed()
    }

    /// `sched` is loaded by ContentView during the startup loading screen
    /// (from cache or network) and injected here.
    init(schedule sched: Schedule) {
        self.schedule = sched
        self.service = CaltrainService(schedule: sched)

        let savedAM = UserDefaults.standard.object(forKey: "stopAM") as? Int
        let savedPM = UserDefaults.standard.object(forKey: "stopPM") as? Int
        let stations = sched.southStops
        let stopAM = savedAM.flatMap { $0 >= 0 && $0 < stations.count ? $0 : nil } ?? 15
        let stopPM = savedPM.flatMap { $0 >= 0 && $0 < stations.count ? $0 : nil } ?? 0

        let flipped = Calendar.current.component(.hour, from: Date()) >= 12
        if flipped {
            self.origin = stations[stopPM]
            self.destination = stations[stopAM]
        } else {
            self.origin = stations[stopAM]
            self.destination = stations[stopPM]
        }

        let gt = GoodTimes()
        self.goodTimes = gt
        self.scheduleType = CaltrainSchedule.optionIndex(
            date: gt.date,
            dotw: gt.dotw,
            specialDates: sched.specialDates
        )
        refresh()

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.goodTimes = GoodTimes()
                self.updateNextIndex()
            }
    }

    /// Returns a copy of `trip` with all leg-depart times and the final arrival
    /// shifted forward by `TripViewModel.dayMinutes`, used to represent a
    /// "tomorrow" trip appended after today's schedule.
    private func shiftedToTomorrow(_ trip: Trip) -> Trip {
        let shiftedLegs = trip.legs.map { leg in
            Leg(trainId: leg.trainId, station: leg.station, depart: leg.depart + TripViewModel.dayMinutes)
        }
        return Trip(id: trip.id, legs: shiftedLegs, arrive: trip.arrive + TripViewModel.dayMinutes, isFuture: true)
    }

    func refresh() {
        let todayTrips = service.routes(from: origin, to: destination, scheduleType: scheduleType)
        let tomorrowTrips = service.routes(from: origin, to: destination, scheduleType: tomorrowScheduleType)
            .map(shiftedToTomorrow)

        trips = todayTrips + tomorrowTrips
        nextIndex = service.nextIndex(trips: trips, minutes: goodTimes.minutes)
        userSelected = false
        offset = clampedOffset(preferring: nextIndex)
    }

    func setOffset(_ newOffset: Int) {
        userSelected = (newOffset != nextIndex)
        offset = newOffset
    }

    /// Shared fallback: if there's no service tomorrow and today's trips are
    /// all in the past, keep the first trip selected instead of clamping to
    /// the last (already-departed) one.
    private func clampedOffset(preferring desired: Int) -> Int {
        if desired < trips.count { return desired }
        let hasTomorrow = trips.contains { $0.isFuture }
        if !hasTomorrow && !trips.isEmpty {
            return 0
        }
        return max(0, trips.count - 1)
    }

    func resetToNext() {
        userSelected = false
        offset = clampedOffset(preferring: nextIndex)
    }

    func updateNextIndex() {
        nextIndex = service.nextIndex(trips: trips, minutes: goodTimes.minutes)
        if !userSelected {
            offset = clampedOffset(preferring: nextIndex)
        } else if offset >= trips.count {
            offset = clampedOffset(preferring: offset)
        }
    }

    func offsetUp() {
        if offset > 0 { offset -= 1 }
    }

    func offsetDown() {
        if offset < trips.count - 1 { offset += 1 }
    }

    func swapStations() {
        let tmp = origin
        origin = destination
        destination = tmp
        saveStops()
        refresh()
    }

    func saveStops() {
        let stations = schedule.southStops
        let flipped = isFlipped
        let amStation = flipped ? destination : origin
        let pmStation = flipped ? origin : destination
        if let amIdx = stations.firstIndex(of: amStation) {
            UserDefaults.standard.set(amIdx, forKey: kStopAM)
        }
        if let pmIdx = stations.firstIndex(of: pmStation) {
            UserDefaults.standard.set(pmIdx, forKey: kStopPM)
        }
    }

    func cycleSchedule() {
        let next = (scheduleType.rawValue + 1) % 3
        scheduleType = ScheduleType(rawValue: next)!
        refresh()
    }
}
