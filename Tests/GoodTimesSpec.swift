import Quick
import Nimble
@testable import NextCaltrain

final class GoodTimesSpec: QuickSpec {
    override class func spec() {
        describe("GoodTimes") {

            describe(".partTime(_:)") {
                context("when given a morning time") {
                    var result: (String, String)!
                    beforeEach {
                        result = GoodTimes.partTime(330) // 5:30am
                    }

                    it("returns the time and 'am'") {
                        expect(result.0).to(equal("5:30"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given noon") {
                    var result: (String, String)!
                    beforeEach {
                        result = GoodTimes.partTime(720) // 12:00pm
                    }

                    it("returns 12:00 and 'pm'") {
                        expect(result.0).to(equal("12:00"))
                        expect(result.1).to(equal("pm"))
                    }
                }

                context("when given midnight") {
                    var result: (String, String)!
                    beforeEach {
                        result = GoodTimes.partTime(0)
                    }

                    it("returns 12:00 and 'am'") {
                        expect(result.0).to(equal("12:00"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given a today's-schedule post-midnight time (24:00-25:59 range)") {
                    var result: (String, String)!
                    beforeEach {
                        result = GoodTimes.partTime(1445) // 24:05
                    }

                    it("formats 24:05 as 12:05am") {
                        expect(result.0).to(equal("12:05"))
                        expect(result.1).to(equal("am"))
                    }
                }

                context("when given a tomorrow-shifted time (>= 1440)") {
                    context("at 1740 (29:00)") {
                        var result: (String, String)!
                        beforeEach {
                            result = GoodTimes.partTime(1740)
                        }

                        it("wraps to 5:00am") {
                            expect(result.0).to(equal("5:00"))
                            expect(result.1).to(equal("am"))
                        }
                    }

                    context("at 1620 (27:00)") {
                        var result: (String, String)!
                        beforeEach {
                            result = GoodTimes.partTime(1620)
                        }

                        it("wraps to 3:00am") {
                            expect(result.0).to(equal("3:00"))
                            expect(result.1).to(equal("am"))
                        }
                    }
                }
            }

            describe(".fullTime(_:)") {
                context("when given noon") {
                    var result: String!
                    beforeEach {
                        result = GoodTimes.fullTime(720)
                    }

                    it("returns '12:00pm'") {
                        expect(result).to(equal("12:00pm"))
                    }
                }
            }

            context("when 'now' is fixed via debugOverrideMinutes") {
                var gt: GoodTimes!

                beforeEach {
                    GoodTimes.debugOverrideMinutes = 720 // noon
                    gt = GoodTimes()
                }

                afterEach {
                    GoodTimes.debugOverrideMinutes = nil
                    GoodTimes.debugOverrideDotw = nil
                }

                describe("#inThePast(_:)") {
                    context("when the target is before now") {
                        it("returns true") {
                            expect(gt.inThePast(gt.minutes - 2)).to(beTrue())
                        }
                    }

                    context("when the target is after now") {
                        it("returns false") {
                            expect(gt.inThePast(gt.minutes + 2)).to(beFalse())
                        }
                    }
                }

                describe("#departing(_:)") {
                    context("when the target equals now") {
                        it("returns true") {
                            expect(gt.departing(gt.minutes)).to(beTrue())
                        }
                    }

                    context("when the target does not equal now") {
                        it("returns false") {
                            expect(gt.departing(gt.minutes + 1)).to(beFalse())
                        }
                    }
                }

                describe("#countdown(_:)") {
                    context("when the target is in the past") {
                        it("returns an empty string") {
                            expect(gt.countdown(gt.minutes - 1)).to(equal(""))
                        }
                    }

                    context("when the target is more than an hour away") {
                        it("formats as 'in N hr M min'") {
                            expect(gt.countdown(gt.minutes + 66)).to(equal("in 1 hr 5 min"))
                        }
                    }

                    context("when the target is less than an hour away") {
                        it("formats as 'in N min M sec'") {
                            let result = gt.countdown(gt.minutes + 5)
                            expect(result).to(match("in 4 min \\d+ sec"))
                        }
                    }
                }
            }

            context("when 'today' is fixed via debugOverrideDotw") {
                afterEach {
                    GoodTimes.debugOverrideDotw = nil
                }

                context("and today is Friday (5)") {
                    var gt: GoodTimes!
                    beforeEach {
                        GoodTimes.debugOverrideDotw = 5
                        gt = GoodTimes()
                    }

                    it("computes tomorrow as Saturday (6)") {
                        expect(gt.dotw).to(equal(5))
                        expect(gt.tomorrowDotw).to(equal(6))
                    }
                }

                context("and today is Saturday (6)") {
                    var gt: GoodTimes!
                    beforeEach {
                        GoodTimes.debugOverrideDotw = 6
                        gt = GoodTimes()
                    }

                    it("computes tomorrow as Sunday (0), wrapping the week") {
                        expect(gt.tomorrowDotw).to(equal(0))
                    }
                }
            }

            describe(".scheduleDateFor(_:)") {
                // Used by the once-per-day schedule fetch cap to decide whether a
                // stored "last fetched at" timestamp still counts as "today" under
                // the same "day starts at 2am" rule GoodTimes() itself uses. Both
                // timestamps in each test are built from the same Calendar so the
                // comparison holds regardless of the device's default timezone.

                it("returns the same schedule-day for two instants on the same calendar day, both after 2am") {
                    let cal = Calendar.current
                    let morning = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 10))!
                    let night = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23))!
                    expect(GoodTimes.scheduleDateFor(morning)).to(equal(GoodTimes.scheduleDateFor(night)))
                }

                it("treats 1am as still belonging to the previous schedule-day") {
                    let cal = Calendar.current
                    let lateNight = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23))!
                    let earlyMorning = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1))!
                    expect(GoodTimes.scheduleDateFor(earlyMorning)).to(equal(GoodTimes.scheduleDateFor(lateNight)))
                }

                it("rolls over to the next schedule-day right at the 2am boundary") {
                    let cal = Calendar.current
                    let beforeBoundary = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1, minute: 59))!
                    let afterBoundary = cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 2, minute: 1))!
                    expect(GoodTimes.scheduleDateFor(afterBoundary)).toNot(equal(GoodTimes.scheduleDateFor(beforeBoundary)))
                }
            }
        }
    }
}
