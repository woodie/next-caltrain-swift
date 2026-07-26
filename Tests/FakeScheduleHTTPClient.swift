import Foundation
@testable import NextCaltrain

// Matches zouk's FakeHTTPClient -- each test owns its own instance, errors loudly if no
// dataHandler is set.
final class FakeScheduleHTTPClient: ScheduleHTTPClient, @unchecked Sendable {
    var dataHandler: ((URL) throws -> (Data, URLResponse))?

    func data(from url: URL) async throws -> (Data, URLResponse) {
        guard let dataHandler else { throw URLError(.unknown) }
        return try dataHandler(url)
    }
}
