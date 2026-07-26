import SwiftUI

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct StationSelectionView: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveConfirm = false

    var stations: [String] { viewModel.schedule.southStops }

    var isFlipped: Bool {
        Calendar.current.component(.hour, from: Date()) >= 12
    }

    // Morning/Evening map onto origin/destination depending on time of day.
    var morningStation: String {
        isFlipped ? viewModel.destination : viewModel.origin
    }
    var eveningStation: String {
        isFlipped ? viewModel.origin : viewModel.destination
    }

    func setMorningStation(_ station: String) {
        if isFlipped {
            viewModel.destination = station
        } else {
            viewModel.origin = station
        }
        viewModel.refresh()
    }

    func setEveningStation(_ station: String) {
        if isFlipped {
            viewModel.origin = station
        } else {
            viewModel.destination = station
        }
        viewModel.refresh()
    }

    func stationName(_ idx: Int) -> String {
        let index: Int = idx < viewModel.schedule.southStops.count ? idx : 0
        return viewModel.schedule.southStops[index]
    }

    func restoreDefaults() {
        let savedAM = (UserDefaults.standard.object(forKey: "stopAM") as? Int) ?? 15
        let savedPM = (UserDefaults.standard.object(forKey: "stopPM") as? Int) ?? 0
        setMorningStation(stationName(savedAM))
        setEveningStation(stationName(savedPM))
    }

    var isAlreadyDefault: Bool {
        let savedAM = (UserDefaults.standard.object(forKey: "stopAM") as? Int) ?? 15
        let savedPM = (UserDefaults.standard.object(forKey: "stopPM") as? Int) ?? 0
        let defaultMorning = stationName(savedAM)
        let defaultEvening = stationName(savedPM)
        return morningStation == defaultMorning && eveningStation == defaultEvening
    }

    @State private var morningRowWidth: CGFloat = 0
    @State private var eveningRowWidth: CGFloat = 0

    func stationRow(_ station: String, selected: String, columnWidth: CGFloat) -> some View {
        Text(station)
            .foregroundColor(.appText)
            .font(.system(size: AppStyle.fontOrigin, weight: .regular))
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: RowWidthKey.self, value: geo.size.width)
                }
            )
            .frame(width: columnWidth > 0 ? columnWidth : nil, alignment: .leading)
            .overlay(alignment: .leading) {
                Image(systemName: "checkmark")
                    .foregroundColor(.calArrive)
                    .opacity(station == selected ? 1 : 0)
                    .offset(x: -32)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(x: 12)
            .contentShape(Rectangle())
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.calArrive)
            .font(.system(size: AppStyle.fontOrigin, weight: .regular))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color.appBackground)
    }

    // ScrollView + VStack (not List/LazyVStack): avoids List's minimum-row-height floor
    // and LazyVStack's unbounded height proposal.
    @ViewBuilder
    private func stationListBody(
        stations: [String],
        selected: String,
        columnWidth: Binding<CGFloat>,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(stations.enumerated()), id: \.element) { index, station in
                        if index > 0 {
                            Divider().background(Color.calSwapped.opacity(0.4))
                        }
                        stationRow(station, selected: selected, columnWidth: columnWidth.wrappedValue)
                            .padding(EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 16))
                            .background(Color.appBackground)
                            .id(station)
                            .onTapGesture {
                                onSelect(station)
                            }
                    }
                }
                .onPreferenceChange(RowWidthKey.self) { width in
                    columnWidth.wrappedValue = width
                }
            }
            .background(Color.appBackground)
            .onAppear {
                // DispatchQueue.main.async: List's scrollTo "just worked" on appear,
                // but plain VStack needs the layout pass to finish first or this silently no-ops.
                DispatchQueue.main.async {
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
            .onChange(of: selected) { newStation in
                withAnimation { proxy.scrollTo(newStation, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func morningList(columnWidth: Binding<CGFloat>) -> some View {
        stationListBody(
            stations: stations,
            selected: morningStation,
            columnWidth: columnWidth,
            onSelect: setMorningStation
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            sectionHeader("Morning Station")
        }
    }

    @ViewBuilder
    private func eveningList(columnWidth: Binding<CGFloat>) -> some View {
        stationListBody(
            stations: stations,
            selected: eveningStation,
            columnWidth: columnWidth,
            onSelect: setEveningStation
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            sectionHeader("Evening Station")
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    // Wide / landscape — side by side
                    HStack(spacing: 0) {
                        morningList(columnWidth: $morningRowWidth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider().background(Color.gray)

                        eveningList(columnWidth: $eveningRowWidth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Portrait — stacked
                    VStack(spacing: 0) {
                        morningList(columnWidth: $morningRowWidth)
                            .frame(maxHeight: .infinity)

                        Divider().background(Color.gray).padding(.vertical, 4)

                        eveningList(columnWidth: $eveningRowWidth)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.appText)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isAlreadyDefault {
                    Button {
                        restoreDefaults()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.appText)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !isAlreadyDefault {
                    Button {
                        showSaveConfirm = true
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(.calArrive)
                    }
                }
            }
        }
        .alert("Stations Defaults", isPresented: $showSaveConfirm) {
            Button("Save") {
                viewModel.saveStops()
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Save \(morningStation) as morning and \(eveningStation) as evening default stations?")
        }
    }
}
