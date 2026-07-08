import Nimble
import Quick

@testable import NextCaltrain

final class TripViewModelSpec: QuickSpec {
    override class func spec() {
        describe("TripViewModel") {
            afterEach { GoodTimes.debugOverrideMinutes = nil; GoodTimes.debugOverrideDotw = nil }

            context("for a route with no service tomorrow") {
                // Weekday-only schedule. Friday -> Saturday, so tomorrowScheduleType is .weekend.
                var viewModel: TripViewModel!
                var mins: Int!
                justBeforeEach {
                    GoodTimes.debugOverrideMinutes = mins
                    GoodTimes.debugOverrideDotw = 5 // Friday
                    viewModel = TripViewModel(schedule: SpecFixtures.weekdayOnlySchedule())
                    viewModel.origin = SpecFixtures.sanFrancisco
                    viewModel.destination = SpecFixtures.gilroy
                    viewModel.refresh()
                }

                context("and all of today's trips have already departed") {
                    // After the diesel southbound train's 545 arrival.
                    beforeEach { mins = 1000 }

                    it("still has today's trips available") {
                        expect(viewModel.trips).notTo(beEmpty())
                    }

                    it("has no future (tomorrow) trips appended") {
                        expect(viewModel.trips.contains { $0.isFuture }).to(beFalse())
                    }

                    it("selects the first trip of the day, not the last") {
                        expect(viewModel.offset).to(equal(0))
                    }

                    it("keeps the selection at 0 on subsequent ticks") {
                        viewModel.updateNextIndex()
                        expect(viewModel.offset).to(equal(0))
                    }
                }

                context("and some of today's trips are still upcoming") {
                    // Before the electric southbound train departs SF at 480.
                    beforeEach { mins = 100 }

                    it("selects the next upcoming trip") {
                        expect(viewModel.offset).to(equal(viewModel.nextIndex))
                        expect(viewModel.offset).to(equal(0))
                    }
                }
            }

            context("for a route with service every day") {
                // Monday -> Tuesday, both .weekday, so normal rollover applies.
                var viewModel: TripViewModel!
                beforeEach { GoodTimes.debugOverrideDotw = 1 } // Monday

                context("and all of today's trips have already departed") {
                    beforeEach {
                        GoodTimes.debugOverrideMinutes = 1000
                        let schedule = SpecFixtures.schedule {
                            $0.weekday(electric: .normal, diesel: .normal)
                            $0.weekend(electric: .normal, diesel: .normal)
                        }
                        viewModel = TripViewModel(schedule: schedule)
                        viewModel.origin = SpecFixtures.sanFrancisco
                        viewModel.destination = SpecFixtures.sanJoseDiridon
                        viewModel.refresh()
                    }

                    it("appends tomorrow's trips, marked as future") {
                        expect(viewModel.trips.contains { $0.isFuture }).to(beTrue())
                    }

                    it("rolls the selection into tomorrow's first trip") {
                        expect(viewModel.trips[viewModel.offset].isFuture).to(beTrue())
                    }

                    it("shifts tomorrow's depart time by a full day") {
                        let futureTrip = viewModel.trips[viewModel.offset]
                        expect(futureTrip.depart).to(equal(480 + TripViewModel.dayMinutes))
                    }
                }

                context("and some of today's trips are still upcoming") {
                    beforeEach {
                        GoodTimes.debugOverrideMinutes = 100
                        let schedule = SpecFixtures.schedule {
                            $0.weekday(electric: .normal, diesel: .normal)
                            $0.weekend(electric: .normal, diesel: .normal)
                        }
                        viewModel = TripViewModel(schedule: schedule)
                        viewModel.origin = SpecFixtures.sanFrancisco
                        viewModel.destination = SpecFixtures.sanJoseDiridon
                        viewModel.refresh()
                    }

                    it("selects today's trip, not a future one") {
                        expect(viewModel.trips[viewModel.offset].isFuture).to(beFalse())
                    }
                }
            }

            context("for a route with no service on any day") {
                // Nothing configured at all -- every table is empty.
                var viewModel: TripViewModel!

                beforeEach {
                    GoodTimes.debugOverrideDotw = 1  // Monday
                    GoodTimes.debugOverrideMinutes = 100
                    let schedule = SpecFixtures.schedule { _ in
                        // intentionally empty: no service configured for
                        // any schedule type
                    }
                    viewModel = TripViewModel(schedule: schedule)
                    viewModel.origin = SpecFixtures.sanFrancisco
                    viewModel.destination = SpecFixtures.gilroy
                    viewModel.refresh()
                }

                it("has no trips") {
                    expect(viewModel.trips).to(beEmpty())
                }

                it("selects offset 0 without crashing") {
                    expect(viewModel.offset).to(equal(0))
                }

                it("remains at offset 0 after a timer tick") {
                    viewModel.updateNextIndex()
                    expect(viewModel.offset).to(equal(0))
                }
            }

            context("for a future trip's schedule type (Friday -> Saturday)") {
                // Friday with weekday+weekend service: today's trips all
                // departed, tomorrow is Saturday (.weekend). Verifies that
                // TripListView should use tomorrowScheduleType for future trips.
                var viewModel: TripViewModel!

                beforeEach {
                    GoodTimes.debugOverrideDotw = 5  // Friday
                    GoodTimes.debugOverrideMinutes = 1000  // after all today's trips
                    let schedule = SpecFixtures.schedule {
                        $0.weekday(electric: .normal, diesel: .normal)
                        $0.weekend(electric: .normal, diesel: .normal)
                    }
                    viewModel = TripViewModel(schedule: schedule)
                    viewModel.origin = SpecFixtures.sanFrancisco
                    viewModel.destination = SpecFixtures.sanJoseDiridon
                    viewModel.refresh()
                }

                it("has a future trip selected") {
                    expect(viewModel.trips[viewModel.offset].isFuture).to(beTrue())
                }

                it("isFutureSelected is true") {
                    expect(viewModel.isFutureSelected).to(beTrue())
                }

                it("today is weekday, tomorrow is weekend") {
                    expect(viewModel.scheduleType).to(equal(.weekday))
                    expect(viewModel.tomorrowScheduleType).to(equal(.weekend))
                }

                it("correct schedule type for detail view is tomorrowScheduleType") {
                    let trip = viewModel.trips[viewModel.offset]
                    let detailScheduleType =
                        trip.isFuture
                        ? viewModel.tomorrowScheduleType
                        : viewModel.scheduleType
                    expect(detailScheduleType).to(equal(.weekend))
                }
            }

            context("manual selection via setOffset") {
                // Regression coverage for the reset-button-stuck-on bug: dragging
                // away from the next train sets hasManualSelection, but dragging
                // back to that same next-train offset should clear it again —
                // otherwise the reset button stays visible even though the
                // current selection is exactly the auto-picked "next train".
                var viewModel: TripViewModel!

                beforeEach {
                    GoodTimes.debugOverrideDotw = 1  // Monday
                    GoodTimes.debugOverrideMinutes = 100
                    let schedule = SpecFixtures.schedule {
                        $0.weekday(electric: .normal, diesel: .normal)
                        $0.weekend(electric: .normal, diesel: .normal)
                    }
                    viewModel = TripViewModel(schedule: schedule)
                    viewModel.origin = SpecFixtures.sanFrancisco
                    viewModel.destination = SpecFixtures.sanJoseDiridon
                    viewModel.refresh()
                }

                it("flags manual selection when dragging to an offset other than nextIndex") {
                    viewModel.setOffset(viewModel.nextIndex + 1)
                    expect(viewModel.hasManualSelection).to(beTrue())
                }

                it("clears manual selection when dragging back to the next train") {
                    viewModel.setOffset(viewModel.nextIndex + 1)
                    expect(viewModel.hasManualSelection).to(beTrue())

                    viewModel.setOffset(viewModel.nextIndex)
                    expect(viewModel.hasManualSelection).to(beFalse())
                }

                it("resetToNext() also clears manual selection") {
                    viewModel.setOffset(viewModel.nextIndex + 1)
                    viewModel.resetToNext()
                    expect(viewModel.hasManualSelection).to(beFalse())
                }
            }
        }
    }
}
