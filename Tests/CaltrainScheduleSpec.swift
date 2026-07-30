import Quick
import Nimble
@testable import NextCaltrain

final class CaltrainScheduleSpec: QuickSpec {
    override class func spec() {
        describe("CaltrainSchedule") {
            describe(".optionIndex(date:dotw:specialDates:)") {
                var result: ScheduleType!
                var date: String!
                var dotw: Int!
                var specialDates: [String: Int]!
                justBeforeEach {
                    result = CaltrainSchedule.optionIndex(date: date, dotw: dotw, specialDates: specialDates)
                }
                context("with no special dates") {
                    beforeEach { specialDates = [:] }

                    context("on a weekday (Wednesday, dotw=3)") {
                        beforeEach { date = "2026-06-17"; dotw = 3 }

                        it("returns .weekday") {
                            expect(result).to(equal(.weekday))
                        }
                    }

                    context("on Sunday (dotw=0)") {
                        beforeEach { date = "2026-06-14"; dotw = 0 }

                        it("returns .weekend") {
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("on Saturday (dotw=6)") {
                        beforeEach { date = "2026-06-13"; dotw = 6 }

                        it("returns .weekend") {
                            expect(result).to(equal(.weekend))
                        }
                    }
                }

                context("with a special date matching today") {
                    beforeEach { specialDates = [
                        "2026-07-04": ScheduleType.weekend.rawValue,
                        "2026-12-25": ScheduleType.holiday.rawValue
                    ] }

                    context("when the special date maps to .weekend") {
                        beforeEach { date = "2026-07-04"; dotw = 3 }

                        it("overrides a weekday dotw") {
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("when the special date maps to .holiday") {
                        beforeEach { date = "2026-12-25"; dotw = 5 }

                        it("returns .holiday regardless of dotw") {
                            expect(result).to(equal(.holiday))
                        }
                    }

                    context("on a date not in specialDates") {
                        beforeEach { date = "2026-06-17"; dotw = 3 }

                        it("falls back to dotw-based logic") {
                            expect(result).to(equal(.weekday))
                        }
                    }
                }

                context("with a special date containing an invalid raw value") {
                    beforeEach { date = "2026-06-17"; dotw = 3; specialDates = ["2026-06-17": 99] }

                    it("falls back to .weekday") {
                        expect(result).to(equal(.weekday))
                    }
                }
            }

            describe(".forTomorrow()") {
                var result: ScheduleType!
                var dotw: Int!
                justBeforeEach {
                    let goodTimes = GoodTimes.seeded(dotw: dotw)
                    result = CaltrainSchedule.optionIndex(
                        date: goodTimes.tomorrowDate,
                        dotw: goodTimes.tomorrowDotw,
                        specialDates: [:]
                    )
                }

                context("when today is Friday (5)") {
                    beforeEach { dotw = 5 }

                    it("returns .weekend for tomorrow (Saturday)") {
                        expect(result).to(equal(.weekend))
                    }
                }

                context("when today is Sunday (0)") {
                    beforeEach { dotw = 0 }

                    it("returns .weekday for tomorrow (Monday)") {
                        expect(result).to(equal(.weekday))
                    }
                }

                context("when today is Thursday (4)") {
                    beforeEach { dotw = 4 }

                    it("returns .weekday for tomorrow (Friday)") {
                        expect(result).to(equal(.weekday))
                    }
                }
            }
        }
    }
}
