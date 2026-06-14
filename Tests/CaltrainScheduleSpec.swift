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
                        it("returns .weekday") {
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-06-17",
                                dotw: 3,
                                specialDates: specialDates
                            )
                            expect(result).to(equal(.weekday))
                        }
                    }

                    context("on Sunday (dotw=0)") {
                        it("returns .weekend") {
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-06-14",
                                dotw: 0,
                                specialDates: specialDates
                            )
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("on Saturday (dotw=6)") {
                        it("returns .weekend") {
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-06-13",
                                dotw: 6,
                                specialDates: specialDates
                            )
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
                        it("overrides a weekday dotw") {
                            // July 4, 2026 is a Saturday, but pick a dotw
                            // that would normally be .weekday to prove the
                            // override wins.
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-07-04",
                                dotw: 3, // would normally be .weekday
                                specialDates: specialDates
                            )
                            expect(result).to(equal(.weekend))
                        }
                    }

                    context("when the special date maps to .holiday") {
                        it("returns .holiday regardless of dotw") {
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-12-25",
                                dotw: 5, // would normally be .weekday
                                specialDates: specialDates
                            )
                            expect(result).to(equal(.holiday))
                        }
                    }

                    context("on a date not in specialDates") {
                        it("falls back to dotw-based logic") {
                            let result = CaltrainSchedule.optionIndex(
                                date: "2026-06-17",
                                dotw: 3,
                                specialDates: specialDates
                            )
                            expect(result).to(equal(.weekday))
                        }
                    }
                }

                context("with a special date containing an invalid raw value") {
                    it("falls back to .weekday") {
                        let specialDates: [String: Int] = ["2026-06-17": 99]
                        let result = CaltrainSchedule.optionIndex(
                            date: "2026-06-17",
                            dotw: 3,
                            specialDates: specialDates
                        )
                        expect(result).to(equal(.weekday))
                    }
                }
            }
        }
    }
}
