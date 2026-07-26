import Quick
import Nimble
@testable import NextCaltrain

final class CaltrainServiceSpec: QuickSpec {
    override class func spec() {
        describe("CaltrainService") {
            var service: CaltrainService!
            beforeEach {
                service = CaltrainService(schedule: SpecFixtures.weekdayOnlySchedule())
            }

            describe(".isSouthCounty(_:)") {
                it("returns true for South County trains (801-900)") {
                    expect(CaltrainService.isSouthCounty(801)).to(beTrue())
                    expect(CaltrainService.isSouthCounty(814)).to(beTrue())
                    expect(CaltrainService.isSouthCounty(900)).to(beTrue())
                }

                it("returns false for electric trains") {
                    expect(CaltrainService.isSouthCounty(101)).to(beFalse())
                    expect(CaltrainService.isSouthCounty(514)).to(beFalse())
                }
            }

            describe(".direction(from:to:stops:)") {
                var origin: String!
                var destin: String!
                var direction: String!
                justBeforeEach {
                    direction = CaltrainService.direction(from: origin, to: destin, stops: SpecFixtures.stops)
                }
                context("when traveling from San Francisco to Gilroy") {
                    beforeEach { origin = SpecFixtures.sanFrancisco; destin = SpecFixtures.gilroy }

                    it("is South") {
                        expect(direction).to(equal("South"))
                    }
                }

                context("when traveling from Gilroy to San Francisco") {
                    beforeEach { origin = SpecFixtures.gilroy; destin = SpecFixtures.sanFrancisco }

                    it("is North") {
                        expect(direction).to(equal("North"))
                    }
                }
            }

            describe("#routes(from:to:scheduleType:)") {
                var from: String!
                var to: String!
                var scheduleType: ScheduleType!
                var trips: [Trip]!
                justBeforeEach {
                    trips = service.routes(from: from, to: to, scheduleType: scheduleType)
                }

                context("for a direct electric trip (San Francisco to San Jose Diridon)") {
                    beforeEach {
                        from = SpecFixtures.sanFrancisco
                        to = SpecFixtures.sanJoseDiridon
                        scheduleType = .weekday
                    }

                    it("returns one direct trip") {
                        expect(trips).to(haveCount(1))
                    }

                    it("is not a transfer") {
                        expect(trips.first?.isTransfer).to(beFalse())
                    }

                    it("uses the electric southbound train") {
                        expect(trips.first?.id).to(equal(SpecFixtures.electricSouthTrainId))
                    }

                    it("departs and arrives at the scheduled times") {
                        expect(trips.first?.depart).to(equal(480))
                        expect(trips.first?.arrive).to(equal(510))
                    }
                }

                context("for a direct diesel trip (Morgan Hill to Gilroy)") {
                    beforeEach {
                        from = SpecFixtures.morganHill
                        to = SpecFixtures.gilroy
                        scheduleType = .weekday
                    }

                    it("returns one direct trip") {
                        expect(trips).to(haveCount(1))
                    }

                    it("is not a transfer, since both endpoints are South County") {
                        expect(trips.first?.isTransfer).to(beFalse())
                    }

                    it("uses the diesel southbound train") {
                        expect(trips.first?.id).to(equal(SpecFixtures.dieselSouthTrainId))
                    }
                }

                context("for an unknown station") {
                    beforeEach {
                        from = "Unknown"
                        to = SpecFixtures.gilroy
                        scheduleType = .weekday
                    }

                    it("returns no trips") {
                        expect(trips).to(beEmpty())
                    }
                }

                context("for a transfer trip (San Francisco to Gilroy)") {
                    beforeEach {
                        from = SpecFixtures.sanFrancisco
                        to = SpecFixtures.gilroy
                        scheduleType = .weekday
                    }

                    it("returns one trip") {
                        expect(trips).to(haveCount(1))
                    }

                    it("is a transfer") {
                        expect(trips.first?.isTransfer).to(beTrue())
                    }

                    it("has two legs") {
                        expect(trips.first?.legs.count).to(equal(2))
                    }

                    it("starts with the electric train from San Francisco") {
                        let leg1 = trips.first?.legs[0]
                        expect(leg1?.trainId).to(equal(SpecFixtures.electricSouthTrainId))
                        expect(leg1?.station).to(equal(SpecFixtures.sanFrancisco))
                        expect(leg1?.depart).to(equal(480))
                    }

                    it("connects to the diesel train at San Jose Diridon") {
                        let leg2 = trips.first?.legs[1]
                        expect(leg2?.trainId).to(equal(SpecFixtures.dieselSouthTrainId))
                        expect(leg2?.station).to(equal(SpecFixtures.sanJoseDiridon))
                        expect(leg2?.depart).to(equal(515))
                    }

                    it("arrives in Gilroy at the diesel train's scheduled time") {
                        expect(trips.first?.arrive).to(equal(545))
                    }
                }

                context("for a transfer trip (Gilroy to San Francisco)") {
                    beforeEach {
                        from = SpecFixtures.gilroy
                        to = SpecFixtures.sanFrancisco
                        scheduleType = .weekday
                    }

                    it("returns one trip") {
                        expect(trips).to(haveCount(1))
                    }

                    it("is a transfer") {
                        expect(trips.first?.isTransfer).to(beTrue())
                    }

                    it("starts with the diesel train from Gilroy") {
                        let leg1 = trips.first?.legs[0]
                        expect(leg1?.trainId).to(equal(SpecFixtures.dieselNorthTrainId))
                        expect(leg1?.station).to(equal(SpecFixtures.gilroy))
                        expect(leg1?.depart).to(equal(420))
                    }

                    it("connects to the electric train at San Jose Diridon") {
                        let leg2 = trips.first?.legs[1]
                        expect(leg2?.trainId).to(equal(SpecFixtures.electricNorthTrainId))
                        expect(leg2?.station).to(equal(SpecFixtures.sanJoseDiridon))
                        expect(leg2?.depart).to(equal(520))
                    }

                    it("arrives in San Francisco at the electric train's scheduled time") {
                        expect(trips.first?.arrive).to(equal(550))
                    }
                }

                context("for a route with no service (weekend, empty fixture tables)") {
                    beforeEach {
                        from = SpecFixtures.sanFrancisco
                        to = SpecFixtures.gilroy
                        scheduleType = .weekend
                    }

                    it("returns no trips") {
                        expect(trips).to(beEmpty())
                    }
                }
            }

            describe("#nextIndex(trips:minutes:)") {
                context("when no trips have departed yet") {
                    var trips: [Trip]!
                    var index: Int!
                    beforeEach {
                        trips = service.routes(
                            from: SpecFixtures.sanFrancisco,
                            to: SpecFixtures.sanJoseDiridon,
                            scheduleType: .weekday
                        )
                        index = service.nextIndex(trips: trips, minutes: 0)
                    }

                    it("returns 0") {
                        expect(index).to(equal(0))
                    }
                }

                context("when all trips have already departed") {
                    var trips: [Trip]!
                    var index: Int!
                    beforeEach {
                        trips = service.routes(
                            from: SpecFixtures.sanFrancisco,
                            to: SpecFixtures.sanJoseDiridon,
                            scheduleType: .weekday
                        )
                        index = service.nextIndex(trips: trips, minutes: 1000)
                    }

                    it("returns the trip count") {
                        expect(index).to(equal(trips.count))
                    }
                }

                context("when given an empty trip list") {
                    var index: Int!
                    beforeEach { index = service.nextIndex(trips: [], minutes: 500) }

                    it("returns 0") {
                        expect(index).to(equal(0))
                    }
                }

                context("when the current time is exactly at the first trip's departure") {
                    var trips: [Trip]!
                    var firstDepart: Int!
                    beforeEach {
                        trips = service.routes(
                            from: SpecFixtures.sanFrancisco,
                            to: SpecFixtures.sanJoseDiridon,
                            scheduleType: .weekday
                        )
                        firstDepart = trips.first?.depart
                    }

                    it("returns the index of that trip") {
                        expect(service.nextIndex(trips: trips, minutes: firstDepart)).to(equal(0))
                    }

                    it("returns the next index one minute later") {
                        expect(service.nextIndex(trips: trips, minutes: firstDepart + 1)).to(equal(1))
                    }
                }
            }
        }
    }
}
