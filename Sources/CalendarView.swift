import EventKit
import EventKitUI
import SwiftUI

/// Plan a trip for the calendar, like Google Maps: Leave at / Arrive by, a
/// time and a date, then the phone's own new-event screen, filled in.
struct CalendarView: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: PlanMode = .leave
    @State private var time: Date
    @State private var date: Date
    @State private var showStationSelection = false
    @State private var event: EKEvent?
    @State private var showDatePicker = false

    private let eventStore = EKEventStore()

    // A schedule day starts at 2:00 AM, so a time before then means late that
    // night (12:05 AM is 1445 minutes), the same rule as GoodTimes.
    private static let scheduleDayStart = 120

    init(viewModel: TripViewModel) {
        self.viewModel = viewModel
        _time = State(initialValue: CalendarView.initialTime(viewModel))
        _date = State(initialValue: CalendarView.initialDate(viewModel))
    }

    var isoDate: String { CalendarTrip.isoDate(date) }

    var scheduleType: ScheduleType {
        CaltrainSchedule.optionIndex(
            date: isoDate,
            dotw: CalendarTrip.dotw(isoDate),
            specialDates: viewModel.schedule.specialDates
        )
    }

    var trains: [PlannedTrain] {
        let trips = CaltrainService(schedule: viewModel.schedule)
            .routes(from: viewModel.origin, to: viewModel.destination, scheduleType: scheduleType)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var minutes = parts.hour! * 60 + parts.minute!
        if minutes < CalendarView.scheduleDayStart { minutes += TripViewModel.dayMinutes }
        guard let index = CalendarTrip.find(trips, mode: mode, minutes: minutes) else { return [] }
        return CalendarTrip.neighbors(trips, index: index)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.appText)
                        .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                        .background(Circle().fill(Color.iconCircleBackground))
                }
                Spacer()
                Text("Create Calendar Event")
                    .foregroundColor(.appText)
                    .font(.system(size: AppStyle.fontStatusBar, weight: .regular))
                Spacer()
                // Adds the event, the same green check as the station screen's Save.
                if trains.isEmpty {
                    Color.clear
                        .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                } else {
                    Button { event = makeEvent() } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(.calArrive)
                            .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                            .background(Circle().fill(Color.iconCircleBackground))
                    }
                    .accessibilityLabel("Add to Calendar")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 20) {
                Button { showStationSelection = true } label: {
                    Text("\(viewModel.origin) to \(viewModel.destination)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .pill()
                }

                // One line: (Leave at) (Oct 21, 2026) (1:55 PM), date then time like
                // the calendar's Starts row, or (10/21/26) when that doesn't fit.
                ViewThatFits(in: .horizontal) {
                    whenRow(numericDate: false)
                    whenRow(numericDate: true)
                }

                // The event as it lands in the calendar, laid out like the
                // phone's New Event screen: the title, then the notes.
                VStack(spacing: 12) {
                    if !trains.isEmpty {
                        // Title and location share a group, as on New Event.
                        eventSection {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(CalendarTrip.title(destination: viewModel.destination))
                                Divider()
                                Text(CalendarTrip.location(station: viewModel.origin))
                            }
                        }
                        eventSection {
                            Text(CalendarTrip.notes(origin: viewModel.origin, destination: viewModel.destination, trains: trains))
                        }
                    } else {
                        eventSection { Text("No train fits that time.") }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGroupedBackground)))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            NavigationLink(destination: StationSelectionView(viewModel: viewModel), isActive: $showStationSelection) {
                EmptyView()
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(get: { event != nil }, set: { if !$0 { event = nil } })) {
            if let event {
                EventEditor(event: event, eventStore: eventStore) { self.event = nil }
                    .ignoresSafeArea()
            }
        }
    }

    // (Leave at) (Oct 21, 2026) (1:55 PM). The menu is styled as a pill to
    // match the compact pickers; a numeric date (10/21/26) opens the
    // calendar in a popover, for when the long date doesn't fit.
    private func whenRow(numericDate: Bool) -> some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Plan", selection: $mode) {
                    ForEach(PlanMode.allCases, id: \.self) { Text($0.rawValue) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(mode.rawValue)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .pill()
            }
            if numericDate {
                Button { showDatePicker = true } label: {
                    Text(date, format: .dateTime.month(.defaultDigits).day().year(.twoDigits))
                        .pill()
                }
                .popover(isPresented: $showDatePicker) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        // A popover sizes to its content, which squeezes the calendar.
                        .frame(width: 320)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            } else {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .lineLimit(1)
        .fixedSize()
    }

    // One rounded group of the New Event screen.
    private func eventSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundColor(.appText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    // The planned train as a new event, on Pacific time.
    private func makeEvent() -> EKEvent? {
        let trains = trains
        guard let planned = trains.first(where: \.selected),
              let start = CalendarTrip.date(isoDate, minutes: planned.depart),
              let end = CalendarTrip.date(isoDate, minutes: planned.arrive) else { return nil }
        let event = EKEvent(eventStore: eventStore)
        event.title = CalendarTrip.title(destination: viewModel.destination)
        event.location = CalendarTrip.location(station: viewModel.origin)
        event.startDate = start
        event.endDate = end
        event.timeZone = CalendarTrip.timeZone
        event.notes = CalendarTrip.notes(origin: viewModel.origin, destination: viewModel.destination, trains: trains)
        return event
    }

    // The selected train's departure, or now if there's no train.
    private static func initialTime(_ viewModel: TripViewModel) -> Date {
        let trip = viewModel.trips.indices.contains(viewModel.offset) ? viewModel.trips[viewModel.offset] : nil
        let minutes = (trip?.depart ?? viewModel.goodTimes.minutes) % TripViewModel.dayMinutes
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    // The next date (today first, or tomorrow for tomorrow's trips) whose
    // schedule matches the one on screen, so viewing Weekend on a Tuesday
    // plans a Saturday.
    private static func initialDate(_ viewModel: TripViewModel) -> Date {
        let trip = viewModel.trips.indices.contains(viewModel.offset) ? viewModel.trips[viewModel.offset] : nil
        let isFuture = trip?.isFuture ?? false
        let wanted = isFuture ? viewModel.tomorrowScheduleType : viewModel.scheduleType
        let calendar = Calendar.current
        // Before 2:00 AM it's still the previous schedule day.
        let today = calendar.startOfDay(for: Date().addingTimeInterval(-Double(scheduleDayStart) * 60))
        for days in (isFuture ? 1 : 0)..<14 {
            guard let day = calendar.date(byAdding: .day, value: days, to: today) else { continue }
            let iso = CalendarTrip.isoDate(day)
            let type = CaltrainSchedule.optionIndex(
                date: iso, dotw: CalendarTrip.dotw(iso), specialDates: viewModel.schedule.specialDates)
            if type == wanted { return day }
        }
        return calendar.date(byAdding: .day, value: isFuture ? 1 : 0, to: today) ?? today
    }
}

private extension View {
    /// The gray capsule the compact date and time pickers draw, for our own buttons.
    func pill() -> some View {
        foregroundColor(.appText)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

/// The phone's own new-event screen. Since iOS 17 it runs outside the app,
/// so adding an event this way needs no calendar permission.
private struct EventEditor: UIViewControllerRepresentable {
    let event: EKEvent
    let eventStore: EKEventStore
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
