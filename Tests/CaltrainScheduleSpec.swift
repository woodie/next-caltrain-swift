import Quick
import Nimble
@testable import NextCaltrain

final class CaltrainScheduleSpec: QuickSpec {
    override class func spec() {
        describe("CaltrainSchedule") {
            describe(".optionIndex(date:dotw:specialDates:)") {
                context("with no special dates") {
                    let specialDates: [String: Int] = [:]

                    context("on a weekday (Wednesday, dotw=3)") {
                        var result: ScheduleType!
                        beforeEach {
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-06-17",
                                dotw: 3,
                                specialDates: specialDates
                            )
                        }

                        it("returns .weekday") {
                            expect(result).to(equal(.weekday))
                        }
                    }

                    context("on Sunday (dotw=0)") {
                        var result: ScheduleType!
                        beforeEach {
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-06-14",
                                dotw: 0,
                                specialDates: specialDates
                            )
                        }

                        it("returns .weekend") {
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("on Saturday (dotw=6)") {
                        var result: ScheduleType!
                        beforeEach {
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-06-13",
                                dotw: 6,
                                specialDates: specialDates
                            )
                        }

                        it("returns .weekend") {
                            expect(result).to(equal(.weekend))
                        }
                    }
                }

                context("with a special date matching today") {
                    let specialDates: [String: Int] = [
                        "2026-07-04": ScheduleType.weekend.rawValue,
                        "2026-12-25": ScheduleType.holiday.rawValue,
                    ]

                    context("when the special date maps to .weekend") {
                        var result: ScheduleType!
                        beforeEach {
                            // July 4, 2026 is a Saturday, but pick a dotw
                            // that would normally be .weekday to prove the
                            // override wins.
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-07-04",
                                dotw: 3, // would normally be .weekday
                                specialDates: specialDates
                            )
                        }

                        it("overrides a weekday dotw") {
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("when the special date maps to .holiday") {
                        var result: ScheduleType!
                        beforeEach {
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-12-25",
                                dotw: 5, // would normally be .weekday
                                specialDates: specialDates
                            )
                        }

                        it("returns .holiday regardless of dotw") {
                            expect(result).to(equal(.holiday))
                        }
                    }

                    context("on a date not in specialDates") {
                        var result: ScheduleType!
                        beforeEach {
                            result = CaltrainSchedule.optionIndex(
                                date: "2026-06-17",
                                dotw: 3,
                                specialDates: specialDates
                            )
                        }

                        it("falls back to dotw-based logic") {
                            expect(result).to(equal(.weekday))
                        }
                    }
                }

                context("with a special date containing an invalid raw value") {
                    let specialDates: [String: Int] = ["2026-06-17": 99]
                    var result: ScheduleType!
                    beforeEach {
                        result = CaltrainSchedule.optionIndex(
                            date: "2026-06-17",
                            dotw: 3,
                            specialDates: specialDates
                        )
                    }

                    it("falls back to .weekday") {
                        expect(result).to(equal(.weekday))
                    }
                }
            }

            describe(".forTomorrow()") {
                afterEach {
                    GoodTimes.debugOverrideDotw = nil
                }

                context("when today is Friday (5)") {
                    var result: ScheduleType!
                    beforeEach {
                        GoodTimes.debugOverrideDotw = 5
                        let goodTimes = GoodTimes()
                        result = CaltrainSchedule.optionIndex(
                            date: goodTimes.tomorrowDate,
                            dotw: goodTimes.tomorrowDotw,
                            specialDates: [:]
                        )
                    }

                    it("returns .weekend for tomorrow (Saturday)") {
                        expect(result).to(equal(.weekend))
                    }
                }

                context("when today is Sunday (0)") {
                    var result: ScheduleType!
                    beforeEach {
                        GoodTimes.debugOverrideDotw = 0
                        let goodTimes = GoodTimes()
                        result = CaltrainSchedule.optionIndex(
                            date: goodTimes.tomorrowDate,
                            dotw: goodTimes.tomorrowDotw,
                            specialDates: [:]
                        )
                    }

                    it("returns .weekday for tomorrow (Monday)") {
                        expect(result).to(equal(.weekday))
                    }
                }

                context("when today is Thursday (4)") {
                    var result: ScheduleType!
                    beforeEach {
                        GoodTimes.debugOverrideDotw = 4
                        let goodTimes = GoodTimes()
                        result = CaltrainSchedule.optionIndex(
                            date: goodTimes.tomorrowDate,
                            dotw: goodTimes.tomorrowDotw,
                            specialDates: [:]
                        )
                    }

                    it("returns .weekday for tomorrow (Friday)") {
                        expect(result).to(equal(.weekday))
                    }
                }
            }
        }
    }
}
