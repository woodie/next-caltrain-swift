import Foundation
import Quick
import Nimble
@testable import NextCaltrain

final class CalendarTripSpec: QuickSpec {
    override class func spec() {
        // Palo Alto to San Mateo, weekday: #523 5:43pm, #151 5:55pm, #425 6:10pm, #153 6:25pm
        func trip(_ trainId: Int, _ depart: Int, _ arrive: Int) -> Trip {
            Trip(id: trainId, legs: [Leg(trainId: trainId, station: "Palo Alto", depart: depart)], arrive: arrive)
        }
        let routes = [
            trip(523, 17 * 60 + 43, 17 * 60 + 59),
            trip(151, 17 * 60 + 55, 18 * 60 + 17),
            trip(425, 18 * 60 + 10, 18 * 60 + 28),
            trip(153, 18 * 60 + 25, 18 * 60 + 47),
        ]
        func labels(_ index: Int?) -> [String] {
            CalendarTrip.neighbors(routes, index: index!).map(\.label)
        }

        // Shows a Date as Pacific wall-clock time.
        func pacific(_ date: Date?) -> String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            fmt.timeZone = CalendarTrip.timeZone
            return fmt.string(from: date!)
        }

        describe("CalendarTrip") {
            describe(".find(_:mode:minutes:)") {
                context("leaving at 5:50pm") {
                    it("picks the first train departing at or after then") {
                        expect(labels(CalendarTrip.find(routes, mode: .leave, minutes: 17 * 60 + 50)))
                            .to(equal(["#523", "#151", "#425"]))
                    }
                }

                context("arriving by 6:20pm") {
                    it("picks the last train arriving at or before then") {
                        expect(labels(CalendarTrip.find(routes, mode: .arrive, minutes: 18 * 60 + 20)))
                            .to(equal(["#523", "#151", "#425"]))
                    }
                }

                context("leaving after the last train") {
                    it("finds nothing") {
                        expect(CalendarTrip.find(routes, mode: .leave, minutes: 1500)).to(beNil())
                    }
                }
            }

            describe(".neighbors(_:index:)") {
                it("marks the planned train") {
                    let index = CalendarTrip.find(routes, mode: .leave, minutes: 17 * 60 + 55)!
                    expect(CalendarTrip.neighbors(routes, index: index).map(\.selected))
                        .to(equal([false, true, false]))
                }

                it("has no train before the first one of the day") {
                    expect(CalendarTrip.neighbors(routes, index: 0)).to(haveCount(2))
                }
            }

            describe(".line(_:) and .notes(origin:destination:trains:)") {
                var trains: [PlannedTrain]!
                beforeEach {
                    let index = CalendarTrip.find(routes, mode: .leave, minutes: 17 * 60 + 55)!
                    trains = CalendarTrip.neighbors(routes, index: index)
                }

                it("formats a train") {
                    expect(trains.map(CalendarTrip.line)).to(equal(
                        ["#523  5:43pm – 5:59pm", "#151  5:55pm – 6:17pm", "#425  6:10pm – 6:28pm"]))
                }

                it("lists the route and the trains") {
                    expect(CalendarTrip.notes(origin: "Palo Alto", destination: "San Mateo", trains: trains))
                        .to(equal("Palo Alto to San Mateo\n#523  5:43pm – 5:59pm\n#151  5:55pm – 6:17pm\n#425  6:10pm – 6:28pm"))
                }
            }

            describe(".date(_:minutes:)") {
                it("is that time on Pacific time") {
                    expect(pacific(CalendarTrip.date("2026-05-21", minutes: 17 * 60 + 55))).to(equal("2026-05-21 17:55"))
                }

                it("rolls times past midnight over to the next day") {
                    expect(pacific(CalendarTrip.date("2026-12-31", minutes: 1445))).to(equal("2027-01-01 00:05"))
                }
            }

            describe(".dotw(_:)") {
                it("is Thursday for 2026-05-21") {
                    expect(CalendarTrip.dotw("2026-05-21")).to(equal(4))
                }
            }
        }
    }
}
