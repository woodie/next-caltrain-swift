import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: TripViewModel
    @State private var blinkOn: Bool = true
    @State private var showTripList: Bool = false
    @State private var showStationSelection: Bool = false
    @State private var showAbout: Bool = false
    @State private var dragShift: Int = 0

    private let rowHeight: CGFloat = 44

    var effectiveOffset: Int {
        let shifted = viewModel.offset + dragShift
        return max(0, min(shifted, max(viewModel.trips.count - 1, 0)))
    }

    var selectedTrip: Trip? {
        guard effectiveOffset < viewModel.trips.count else { return nil }
        return viewModel.trips[effectiveOffset]
    }

    var noTrainsAtAll: Bool { viewModel.trips.isEmpty }

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

    var ringColor: Color {
        if noTrainsAtAll { return .calSwapped }
        if isSelectedFuture { return .calSwapped }
        if viewModel.swapped || isSelectedPast { return .calSwapped }
        if isSelectedDeparting { return .calDepart }
        return .calArrive
    }

    var line1: String {
        let o = viewModel.origin
        let d = viewModel.destination
        return o.count + 3 >= d.count ? o : "\(o) to"
    }

    var line2: String {
        let o = viewModel.origin
        let d = viewModel.destination
        return o.count + 3 >= d.count ? "to \(d)" : d
    }

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

            // Toolbar layer — fixed at top, doesn't affect circle layout
            VStack(spacing: 0) {
                HStack {
                    Text("Next Caltrain")
                        .foregroundColor(.appText)
                        .font(.system(size: AppStyle.fontStatusBar, weight: .regular))
                        .frame(height: AppStyle.iconButtonSize)
                        .contentShape(Rectangle())
                        .onTapGesture { showAbout = true }

                    Spacer()

                    if viewModel.hasManualSelection {
                        Button {
                            viewModel.resetToNext()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.appText)
                                .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                                .background(Circle().fill(Color.iconCircleBackground))
                        }
                    }

                    Button {
                        viewModel.swapStations()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.appText)
                            .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                            .background(Circle().fill(Color.iconCircleBackground))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }

            // Floating circle — centered on the full screen, doesn't affect toolbar
            circleContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            NavigationLink(destination: TripListView(
                    viewModel: viewModel
                ), isActive: $showTripList) {
                EmptyView()
            }
            NavigationLink(destination: StationSelectionView(
                    viewModel: viewModel
                ), isActive: $showStationSelection) {
                EmptyView()
            }
            NavigationLink(destination: AboutView(
                    scheduleDate: viewModel.schedule.scheduleDate
                ), isActive: $showAbout) {
                EmptyView()
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    private var circleContent: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: 5)
                .frame(width: 230, height: 230)
                .animation(.easeInOut(duration: 0.4), value: ringColor)

            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    Text(line1)
                        .foregroundColor(.appText)
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                    Text(line2)
                        .foregroundColor(.appText)
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                }
                .contentShape(Rectangle())
                .onTapGesture { showStationSelection = true }

                if noTrainsAtAll {
                    Text("NO TRAINS")
                        .foregroundColor(.calPast)
                        .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                        .opacity(blinkOn ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: blinkOn)
                } else {
                    // blurb-hero
                    if isSelectedFuture {
                        Text(viewModel.tomorrowScheduleType.label)
                            .foregroundColor(.calPast)
                            .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                    } else if isSelectedDeparting {
                        Text("DEPARTING")
                            .foregroundColor(.calDepart)
                            .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                            .opacity(blinkOn ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5), value: blinkOn)
                    } else if viewModel.swapped || isSelectedPast {
                        Text(viewModel.scheduleType.label)
                            .foregroundColor(.calPast)
                            .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                    } else if let trip = selectedTrip {
                        let c = viewModel.goodTimes.countdown(trip.depart)
                        if !c.isEmpty {
                            Text(c)
                                .foregroundColor(.calArrive)
                                .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // train-hero + time-hero + meridiem-hero
                    if let trip = selectedTrip {
                        let clr: Color = (viewModel.swapped || isSelectedPast || isSelectedFuture) ? .calPast : .appText
                        let (timeStr, merStr) = GoodTimes.partTime(trip.depart)
                        VStack(spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text("#\(trip.legs.first!.trainId)")
                                    .foregroundColor(clr)
                                    .font(.system(size: AppStyle.fontTrain, weight: .regular))
                                Text(timeStr)
                                    .foregroundColor(clr)
                                    .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                                Text(merStr)
                                    .foregroundColor(clr)
                                    .font(.system(size: AppStyle.fontTrain, weight: .regular))
                            }
                            Text(CaltrainService.trainType(trip.legs.first!.trainId))
                                .foregroundColor(.appText)
                                .font(.system(size: AppStyle.fontTrain, weight: .regular))
                        }
                    }
                }
            }
            .frame(width: 190)
            .offset(y: 8)
        }
        .contentShape(Circle())
        .onTapGesture {
            showTripList = true
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let newShift = -Int((value.translation.height / rowHeight).rounded())
                    let proposed = viewModel.offset + newShift
                    if proposed >= 0 && proposed < viewModel.trips.count {
                        dragShift = newShift
                    }
                }
                .onEnded { _ in
                    viewModel.setOffset(effectiveOffset)
                    dragShift = 0
                }
        )
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            blinkOn = (isSelectedDeparting || noTrainsAtAll) ? !blinkOn : true
        }
    }
}
