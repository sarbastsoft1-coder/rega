import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/services/driver_sync_plan.dart';

void main() {
  test('idle map tick hits at most 2 endpoints', () {
    final plan = DriverSyncPlan.forTick(
      tick: 1,
      tabIndex: 0,
      earningsPeriodIndex: 2,
      forceFull: false,
      needSupportContacts: false,
    );
    expect(plan.activeOrder, isTrue);
    expect(plan.earningsToday, isTrue);
    expect(plan.profile, isFalse);
    expect(plan.ordersHistory, isFalse);
    expect(plan.availableOrders, isFalse);
    expect(plan.earningsWeek, isFalse);
    expect(plan.earningsMonth, isFalse);
    expect(plan.httpCallCount, lessThanOrEqualTo(2));
  });

  test('idle interval is slower than active-order interval', () {
    expect(DriverSyncPlan.intervalSeconds(hasActiveOrder: false), greaterThan(
      DriverSyncPlan.intervalSeconds(hasActiveOrder: true),
    ));
  });

  test('full refresh keeps fan-out for pull-to-refresh', () {
    expect(DriverSyncPlan.full.httpCallCount, greaterThanOrEqualTo(6));
  });

  test('earnings week tab does not pull month', () {
    final plan = DriverSyncPlan.forTick(
      tick: 1,
      tabIndex: 2,
      earningsPeriodIndex: 1,
      forceFull: false,
      needSupportContacts: false,
    );
    expect(plan.earningsWeek, isTrue);
    expect(plan.earningsMonth, isFalse);
    expect(plan.httpCallCount, lessThanOrEqualTo(2));
  });
}
