import Nimble
import Quick

@testable import NextCaltrain

final class TripViewModelSpec: QuickSpec {
  override class func spec() {
    describe("TripViewModel") {
      afterEach {
        GoodTimes.debugOverrideMinutes = nil
        GoodTimes.debugOverrideDotw = nil
      }

      context("for a route with no service tomorrow") {
        // Weekday-only schedule. Friday -> Saturday, so
        // tomorrowScheduleType is .weekend with empty tables.
        var viewModel: TripViewModel!

        beforeEach {
          GoodTimes.debugOverrideDotw = 5  // Friday
        }

        context("and all of today's trips have already departed") {
          beforeEach {
            // After the diesel southbound train's 545 arrival.
            GoodTimes.debugOverrideMinutes = 1000
            viewModel = TripViewModel(schedule: SpecFixtures.weekdayOnlySchedule())
            viewModel.origin = SpecFixtures.sanFrancisco
            viewModel.destination = SpecFixtures.gilroy
            viewModel.refresh()
          }

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
          beforeEach {
            // Before the electric southbound train departs SF at 480.
            GoodTimes.debugOverrideMinutes = 100
            viewModel = TripViewModel(schedule: SpecFixtures.weekdayOnlySchedule())
            viewModel.origin = SpecFixtures.sanFrancisco
            viewModel.destination = SpecFixtures.gilroy
            viewModel.refresh()
          }

          it("selects the next upcoming trip") {
            expect(viewModel.offset).to(equal(viewModel.nextIndex))
            expect(viewModel.offset).to(equal(0))
          }
        }
      }

      context("for a route with service every day") {
        // Both weekday and weekend tables populated.
        // Monday -> Tuesday, both .weekday, so tomorrowTrips is
        // non-empty and the normal rollover applies.
        var viewModel: TripViewModel!

        beforeEach {
          GoodTimes.debugOverrideDotw = 1  // Monday
        }

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
    }
  }
}
