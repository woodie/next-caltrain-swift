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
            // Case 2a: have cache, already fetched today (2am boundary) —
            // skip the network call entirely, no need to ask again.
            if Schedule.fetchedToday() {
                schedule = cached
                return
            }
            // Case 2b: have cache, haven't fetched today yet. Try to refresh,
            // but cap the wait at 10s — whichever finishes first
            // (success/failure/timeout) falls back to the cached data and
            // proceeds to Home. On failure we keep the stale schedule and
            // simply try again next time loadSchedule() runs.
            let result = await firstOf(
                { try await Schedule.fetchFromNetwork() },
                timeout: 10
            )
            schedule = (try? result.get()) ?? cached
            return
        }

        // Case 1: no cache. Must fetch from network. On failure, show a
        // permanent "Unable to load schedule" state — no retry loop.
        do {
            schedule = try await Schedule.fetchFromNetwork()
        } catch {
            loadFailed = true
        }
    }

    /// Races `operation` against a `timeout` (seconds). Returns the
    /// operation's result if it completes first, otherwise a timeout error.
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
