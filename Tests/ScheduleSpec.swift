import Foundation
import Quick
import Nimble
@testable import NextCaltrain

/// Covers Schedule.fetchedToday() (the once-per-day fetch cap; 2am boundary math itself is
/// covered in GoodTimesSpec) and .fetchFromNetwork(). AsyncSpec (not QuickSpec) because
/// fetchFromNetwork's own coverage needs async `it`/assertions -- matches zouk's ScanClientSpec.
final class ScheduleSpec: AsyncSpec {
    override class func spec() {
        describe("Schedule.fetchedToday") {
            afterEach {
                UserDefaults.standard.removeObject(forKey: Schedule.lastFetchKey)
            }

            context("when nothing has ever been fetched") {
                beforeEach { UserDefaults.standard.removeObject(forKey: Schedule.lastFetchKey) }

                it("returns false") {
                    expect(Schedule.fetchedToday()).to(beFalse())
                }
            }

            context("when the last fetch was a few minutes ago") {
                let recent = Date().addingTimeInterval(-5 * 60)
                beforeEach { UserDefaults.standard.set(recent, forKey: Schedule.lastFetchKey) }

                it("returns true") {
                    expect(Schedule.fetchedToday()).to(beTrue())
                }
            }

            context("when the last fetch was more than a day ago") {
                let stale = Date().addingTimeInterval(-26 * 3600)
                beforeEach { UserDefaults.standard.set(stale, forKey: Schedule.lastFetchKey) }

                it("returns false") {
                    expect(Schedule.fetchedToday()).to(beFalse())
                }
            }
        }

        // Matches huck's ScanClientSpec.kt: a FakeScheduleHTTPClient stands in for a real network
        // call, exercised per it -- not hoisted into justBeforeEach, since a throwing act belongs
        // inside the throwError assertion itself, not setup that runs before it.
        describe("Schedule.fetchFromNetwork(session:)") {
            let url = URL(string: "https://example.com/schedule.json")!
            let validJSON = Data("""
            {"northStops":["A","B"],"southStops":["A","B"],"northWeekday":{},"northWeekend":{},\
            "northHoliday":{},"southWeekday":{},"southWeekend":{},"southHoliday":{}}
            """.utf8)
            // northStops is empty -- fails Schedule.isValid without needing a malformed-JSON case too.
            let invalidJSON = Data("""
            {"northStops":[],"southStops":["A","B"],"northWeekday":{},"northWeekend":{},\
            "northHoliday":{},"southWeekday":{},"southWeekend":{},"southHoliday":{}}
            """.utf8)

            var fakeSession: FakeScheduleHTTPClient!
            beforeEach { fakeSession = FakeScheduleHTTPClient() }
            afterEach {
                UserDefaults.standard.removeObject(forKey: Schedule.lastFetchKey)
                let cacheFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent(Schedule.cacheFileName)
                try? FileManager.default.removeItem(at: cacheFile)
            }

            context("when the server responds with 200 and valid schedule data") {
                beforeEach {
                    fakeSession.dataHandler = { _ in
                        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                        return (validJSON, response)
                    }
                }

                it("parses and returns the schedule") {
                    let schedule = try await Schedule.fetchFromNetwork(session: fakeSession)
                    expect(schedule.northStops).to(equal(["A", "B"]))
                }
            }

            context("when the server responds with a non-2xx status") {
                beforeEach {
                    fakeSession.dataHandler = { _ in
                        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                        return (Data(), response)
                    }
                }

                it("throws ScheduleError.server with that status code") {
                    await expect { try await Schedule.fetchFromNetwork(session: fakeSession) }
                        .to(throwError(ScheduleError.server(500)))
                }
            }

            context("when the server responds with 200 but invalid schedule data") {
                beforeEach {
                    fakeSession.dataHandler = { _ in
                        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                        return (invalidJSON, response)
                    }
                }

                it("throws ScheduleError.invalidData") {
                    await expect { try await Schedule.fetchFromNetwork(session: fakeSession) }
                        .to(throwError(ScheduleError.invalidData))
                }
            }
        }
    }
}
