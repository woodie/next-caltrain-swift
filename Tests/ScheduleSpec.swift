import Foundation
import Quick
import Nimble
@testable import NextCaltrain

/// Covers Schedule.fetchedToday(), the once-per-day fetch cap; 2am boundary math itself is covered in GoodTimesSpec.
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
    }
}
