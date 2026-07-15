import Foundation
import Quick
import Nimble
@testable import NextCaltrain

final class GoodTimesSpec: QuickSpec {
    override class func spec() {
        describe("GoodTimes") {
            var gt: GoodTimes!
            var minutes: Int!

            describe(".partTime(_:)") {
                var result: (String, String)!
                context("when given a morning time") {
                    beforeEach { result = GoodTimes.partTime(330) } // 5:30am

                    it("returns the time and 'am'") {
                        expect(result.0).to(equal("5:30"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given noon") {
                    beforeEach { result = GoodTimes.partTime(720) } // noon

                    it("returns 12:00 and 'pm'") {
                        expect(result.0).to(equal("12:00"))
                        expect(result.1).to(equal("pm"))
                    }
                }

                context("when given midnight") {
                    beforeEach { result = GoodTimes.partTime(0) } // 12:00am

                    it("returns 12:00 and 'am'") {
                        expect(result.0).to(equal("12:00"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given a today's-schedule post-midnight time (24:00-25:59 range)") {
                    beforeEach { result = GoodTimes.partTime(1445) } // 24:05

                    it("formats 24:05 as 12:05am") {
                        expect(result.0).to(equal("12:05"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given a tomorrow-shifted time (>= 1440)") {
                    context("at 1740 (29:00)") {
                        beforeEach { result = GoodTimes.partTime(1740) }

                        it("wraps to 5:00am") {
                            expect(result.0).to(equal("5:00"))
                            expect(result.1).to(equal("am"))
                        }
                    }

                    context("at 1620 (27:00)") {
                        beforeEach { result = GoodTimes.partTime(1620) }

                        it("wraps to 3:00am") {
                            expect(result.0).to(equal("3:00"))
                            expect(result.1).to(equal("am"))
                        }
                    }
                }
            }

            describe(".fullTime(_:)") {
                var result: String!
                context("when given noon") {
                    beforeEach { result = GoodTimes.fullTime(720) } // noon

                    it("returns '12:00pm'") {
                        expect(result).to(equal("12:00pm"))
                    }
                }
            }

            context("when 'now' is fixed via debugOverrideMinutes") {
                beforeEach { GoodTimes.debugOverrideMinutes = 720; gt = GoodTimes() }

                describe("#inThePast(_:)") {
                    context("when the target is before now") {
                        beforeEach { minutes = gt.minutes - 2 }

                        it("returns true") {
                            expect(gt.inThePast(minutes)).to(beTrue())
                        }
                    }

                    context("when the target is after now") {
                        beforeEach { minutes = gt.minutes + 2 }

                        it("returns false") {
                            expect(gt.inThePast(minutes)).to(beFalse())
                        }
                    }
                }

                describe("#departing(_:)") {
                    context("when the target equals now") {
                        beforeEach { minutes = gt.minutes }

                        it("returns true") {
                            expect(gt.departing(minutes)).to(beTrue())
                        }
                    }

                    context("when the target does not equal now") {
                        beforeEach { minutes = gt.minutes + 1 }

                        it("returns false") {
                            expect(gt.departing(minutes)).to(beFalse())
                        }
                    }
                }

                describe("#countdown(_:)") {
                    context("when the target is in the past") {
                        beforeEach { minutes = gt.minutes - 1 }

                        it("returns an empty string") {
                            expect(gt.countdown(minutes)).to(equal(""))
                        }
                    }

                    context("when the target is more than an hour away") {
                        beforeEach { minutes = gt.minutes + 66 }

                        it("formats as 'in N hr M min'") {
                            expect(gt.countdown(minutes)).to(equal("in 1 hr 5 min"))
                        }
                    }

                    context("when the target is less than an hour away") {
                        beforeEach { minutes = gt.minutes + 5 }

                        it("formats as 'in N min M sec'") {
                            expect(gt.countdown(minutes)).to(match("in 4 min \\d+ sec"))
                        }
                    }
                }
            }

            context("when 'today' is fixed via debugOverrideDotw") {
                var dotw: Int!
                justBeforeEach { GoodTimes.debugOverrideDotw = dotw; gt = GoodTimes() }
                afterEach { GoodTimes.debugOverrideDotw = nil }

                context("and today is Friday (5)") {
                    beforeEach { dotw = 5 }

                    it("computes tomorrow as Saturday (6)") {
                        expect(gt.dotw).to(equal(5))
                        expect(gt.tomorrowDotw).to(equal(6))
                    }
                }

                context("and today is Saturday (6)") {
                    beforeEach { dotw = 6 }

                    it("computes tomorrow as Sunday (0), wrapping the week") {
                        expect(gt.tomorrowDotw).to(equal(0))
                    }
                }

                context("and today is Sunday (0)") {
                    beforeEach { dotw = 0 }

                    it("computes tomorrow as Monday (1)") {
                        expect(gt.tomorrowDotw).to(equal(1))
                    }
                }
            }

            describe(".scheduleDateFor(_:)") {
                // Both timestamps in each test use the same Calendar so the comparison holds regardless of device timezone.
                let cal = Calendar.current

                it("returns the same schedule-day for two instants on the same calendar day, both after 2am") {
                    let morning = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 10))!
                    let night = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23))!

                    expect(GoodTimes.scheduleDateFor(morning)).to(equal(GoodTimes.scheduleDateFor(night)))
                }

                it("treats 1am as still belonging to the previous schedule-day") {
                    let lateNight = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23))!
                    let earlyMorning = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1))!

                    expect(GoodTimes.scheduleDateFor(earlyMorning)).to(equal(GoodTimes.scheduleDateFor(lateNight)))
                }

                it("rolls over to the next schedule-day right at the 2am boundary") {
                    let before = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1, minute: 59))!
                    let after = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 2, minute: 1))!

                    expect(GoodTimes.scheduleDateFor(after)).toNot(equal(GoodTimes.scheduleDateFor(before)))
                }
            }
        }
    }
}
