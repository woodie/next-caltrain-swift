import Foundation
import Quick
import Nimble
@testable import NextCaltrain

/// Covers Schedule.fetchedToday() -- the once-per-day fetch cap that lets
/// ContentView.loadSchedule() skip a redundant network call once we already
/// have today's schedule. fetchedToday() itself only reads UserDefaults and
/// delegates to GoodTimes.scheduleDateFor(); the 2am boundary math for
/// scheduleDateFor() is covered separately in GoodTimesSpec.
final class ScheduleSpec: QuickSpec {
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
                beforeEach {
                    let recent = Date().addingTimeInterval(-5 * 60)
                    UserDefaults.standard.set(recent, forKey: Schedule.lastFetchKey)
                }

                it("returns true") {
                    expect(Schedule.fetchedToday()).to(beTrue())
                }
            }

            context("when the last fetch was more than a day ago") {
                beforeEach {
                    let stale = Date().addingTimeInterval(-26 * 3600)
                    UserDefaults.standard.set(stale, forKey: Schedule.lastFetchKey)
                }

                it("returns false") {
                    expect(Schedule.fetchedToday()).to(beFalse())
                }
            }
        }
    }
}
