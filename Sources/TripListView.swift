import SwiftUI

struct TripListView: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showStationSelection: Bool = false
    @State private var blinkOn: Bool = true
    @State private var dragShift: Int = 0
    @State private var suppressTap: Bool = false
    @State private var navigateToTrip: Trip?
    @State private var timeColumnWidth: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    private let rowHeight: CGFloat = 44
    private let listTopPad: CGFloat = 0

    var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    var rowCount: Int {
        guard headerHeight > 0, let window = windowScene?.windows.first else { return 1 }
        let available = window.bounds.height - headerHeight - listTopPad
        return min(max(1, Int(available / rowHeight)), viewModel.trips.count)
    }

    var effectiveOffset: Int {
        let shifted = viewModel.offset + dragShift
        return max(0, min(shifted, viewModel.trips.count - 1))
    }

    var selectedTrip: Trip? {
        guard effectiveOffset < viewModel.trips.count else { return nil }
        return viewModel.trips[effectiveOffset]
    }

    var isSelectedPast: Bool {
        guard let trip = selectedTrip else { return false }
        return viewModel.goodTimes.inThePast(trip.depart)
    }

    var isSelectedFuture: Bool {
        guard let trip = selectedTrip else { return false }
        return trip.isFuture
    }

    var isSelectedDeparting: Bool {
        guard let trip = selectedTrip else { return false }
        return viewModel.goodTimes.departing(trip.depart)
    }

    var serviceTypeLabel: String {
        guard let trip = selectedTrip else { return "" }
        return CaltrainService.trainType(trip.legs.first!.trainId) + " Service"
    }

    var statusColor: Color {
        if viewModel.trips.isEmpty { return .calPast }
        if viewModel.swapped { return .calSwapped }
        if isSelectedPast || isSelectedFuture { return .calPast }
        if isSelectedDeparting { return .calDepart }
        return .calArrive
    }

    var statusText: String {
        if viewModel.trips.isEmpty { return "NO TRAINS" }
        if isSelectedFuture { return "\(viewModel.tomorrowScheduleType.label) Schedule" }
        if viewModel.swapped || isSelectedPast { return "\(viewModel.scheduleType.label) Schedule" }
        if isSelectedDeparting { return "DEPARTING" }
        if let trip = selectedTrip {
            let c = viewModel.goodTimes.countdown(trip.depart)
            return c.isEmpty ? "" : c
        }
        return ""
    }

    var line1: String {
        let o = viewModel.origin; let d = viewModel.destination
        return o.count + 3 >= d.count ? o : "\(o) to"
    }

    var line2: String {
        let o = viewModel.origin; let d = viewModel.destination
        return o.count + 3 >= d.count ? "to \(d)" : d
    }

    func tripAt(_ slot: Int) -> Trip? {
        let idx = effectiveOffset + slot
        guard idx >= 0 && idx < viewModel.trips.count else { return nil }
        return viewModel.trips[idx]
    }

    func isNext(_ slot: Int) -> Bool { slot == 0 && !viewModel.swapped }

    func isInactive(_ slot: Int) -> Bool {
        if viewModel.swapped { return false }
        let idx = effectiveOffset + slot
        guard idx < viewModel.trips.count else { return false }
        let trip = viewModel.trips[idx]
        if trip.isFuture { return true }
        return viewModel.goodTimes.inThePast(trip.depart)
    }

    func isFuture(_ slot: Int) -> Bool {
        let idx = effectiveOffset + slot
        guard idx < viewModel.trips.count else { return false }
        return viewModel.trips[idx].isFuture
    }

    func isDepartingSlot(_ slot: Int) -> Bool { slot == 0 && isSelectedDeparting }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [Color(white: 0.5), Color.appBackground],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 200)
                Spacer()
            }
            .ignoresSafeArea()

            // Header layer — fixed at top
            VStack(spacing: 0) {
                header
                Spacer()
            }

            // Trip list — floats above, padded below the header
            tripList
                .padding(.top, (headerHeight > 0 ? headerHeight : 140) + listTopPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            NavigationLink(
                destination: navigateToTrip.map { trip in
                    TripDetailView(
                        trip: trip,
                        schedule: viewModel.schedule,
                        origin: viewModel.origin,
                        destination: viewModel.destination,
                        scheduleType: trip.isFuture ? viewModel.tomorrowScheduleType : viewModel.scheduleType,
                        goodTimes: viewModel.goodTimes
                    )
                },
                isActive: Binding(
                    get: { navigateToTrip != nil },
                    set: { if !$0 { navigateToTrip = nil } }
                )
            ) { EmptyView() }

            NavigationLink(destination: StationSelectionView(viewModel: viewModel), isActive: $showStationSelection) {
                EmptyView()
            }
        }
        .navigationBarHidden(true)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            blinkOn = (isSelectedDeparting || viewModel.trips.isEmpty) ? !blinkOn : true
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text(serviceTypeLabel)
                    .foregroundColor(.appText)
                    .font(.system(size: AppStyle.fontStatusBar, weight: .regular))
                Spacer()
                if viewModel.hasManualSelection {
                    Button { viewModel.resetToNext() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.appText)
                            .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                            .background(Circle().fill(Color.iconCircleBackground))
                    }
                }
                Button { viewModel.swapStations() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.appText)
                        .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                        .background(Circle().fill(Color.iconCircleBackground))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.appText)
                        .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                        .background(Circle().fill(Color.iconCircleBackground))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(line1)
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)
                    Text(line2)
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)
                }
                .contentShape(Rectangle())
                .onTapGesture { showStationSelection = true }
                Spacer()
                Color.clear
                    .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text(statusText)
                .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                .foregroundColor(statusColor)
                .opacity((isSelectedDeparting || viewModel.trips.isEmpty) ? (blinkOn ? 1 : 0) : 1)
                .animation(.easeInOut(duration: 0.5), value: blinkOn)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: rowHeight)
                .onTapGesture { viewModel.cycleSchedule() }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { headerHeight = geo.size.height }
                    .onChange(of: geo.size.height) { headerHeight = $0 }
            }
        )
    }

    private var tripList: some View {
        return VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { slot in
                if let trip = tripAt(slot) {
                    TripRow(
                        trip: trip,
                        isNext: isNext(slot),
                        isInactive: isInactive(slot),
                        isFuture: isFuture(slot),
                        isDeparting: isDepartingSlot(slot),
                        swapped: viewModel.swapped,
                        timeColumnWidth: timeColumnWidth
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !suppressTap { navigateToTrip = trip }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .onPreferenceChange(TimeWidthKey.self) { timeColumnWidth = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    suppressTap = true
                    let newShift = -Int((value.translation.height / rowHeight).rounded())
                    let proposed = viewModel.offset + newShift
                    if proposed >= 0 && proposed < viewModel.trips.count {
                        dragShift = newShift
                    }
                }
                .onEnded { _ in
                    viewModel.setOffset(effectiveOffset)
                    dragShift = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        suppressTap = false
                    }
                }
        )
    }
}
