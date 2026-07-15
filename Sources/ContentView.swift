import SwiftUI

struct ContentView: View {
    @State private var schedule: Schedule?
    @State private var loadFailed: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let schedule = schedule {
                    HomeView(viewModel: TripViewModel(schedule: schedule))
                } else {
                    AboutView(scheduleDate: nil, isLoading: true, loadFailed: loadFailed)
                }
            }
        }
        .task {
            await loadSchedule()
        }
    }

    private func loadSchedule() async {
        if let cached = Schedule.loadCached() {
            if Schedule.fetchedToday() {
                schedule = cached
                return
            }
            // Cap the wait at 10s; falls back to the cached schedule on timeout or failure.
            let result = await firstOf(
                { try await Schedule.fetchFromNetwork() },
                timeout: 10
            )
            schedule = (try? result.get()) ?? cached
            return
        }

        do {
            schedule = try await Schedule.fetchFromNetwork()
        } catch {
            loadFailed = true
        }
    }

    /// Races `operation` against a `timeout` (seconds); returns whichever finishes first.
    private func firstOf<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
        timeout seconds: UInt64
    ) async -> Result<T, Error> {
        await withTaskGroup(of: Result<T, Error>.self) { group in
            group.addTask {
                do {
                    return .success(try await operation())
                } catch {
                    return .failure(error)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                return .failure(URLError(.timedOut))
            }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }
}
