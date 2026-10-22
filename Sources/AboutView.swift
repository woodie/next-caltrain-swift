import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let scheduleDate: Int?
    var isLoading: Bool = false
    var loadFailed: Bool = false

    // "Version 1.3 (4)", from Info.plist.
    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    var scheduleDateText: String {
        guard let ms = scheduleDate else { return "Unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // toolbar — back (left), matching TripDetailView/TripListView style
                HStack {
                    if !isLoading {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.appText)
                                .frame(width: AppStyle.iconButtonSize, height: AppStyle.iconButtonSize)
                                .background(Circle().fill(Color.iconCircleBackground))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 16) {
                    Image("NextCaltrainIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)

                    Text("Next Caltrain")
                        .font(.system(size: AppStyle.fontBlurb, weight: .regular))
                        .foregroundColor(.appText)

                    Text("for iOS")
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)

                    Text(versionText)
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)

                    Text("© 2026 John Woodell")
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)
                        .padding(.top, 8)

                    if isLoading {
                        Text(loadFailed ? "Unable to load schedule" : "Loading schedule data")
                            .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                            .foregroundColor(.appText)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 2) {
                            Text("Schedule data:")
                            Text(scheduleDateText)
                        }
                        .font(.system(size: AppStyle.fontOrigin, weight: .regular))
                        .foregroundColor(.appText)
                        .padding(.top, 8)
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}
