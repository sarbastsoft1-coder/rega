/// Decides which driver API endpoints to hit on a sync tick.
/// Idle polls stay ≤2 calls; full refresh remains available for pull-to-refresh.
class DriverSyncPlan {
  const DriverSyncPlan({
    required this.profile,
    required this.activeOrder,
    required this.ordersHistory,
    required this.availableOrders,
    required this.earningsToday,
    required this.earningsWeek,
    required this.earningsMonth,
    required this.supportContacts,
  });

  final bool profile;
  final bool activeOrder;
  final bool ordersHistory;
  final bool availableOrders;
  final bool earningsToday;
  final bool earningsWeek;
  final bool earningsMonth;
  final bool supportContacts;

  int get httpCallCount =>
      (profile ? 1 : 0) +
      (activeOrder ? 1 : 0) +
      (ordersHistory ? 1 : 0) +
      (availableOrders ? 1 : 0) +
      (earningsToday ? 1 : 0) +
      (earningsWeek ? 1 : 0) +
      (earningsMonth ? 1 : 0) +
      (supportContacts ? 1 : 0);

  static const DriverSyncPlan full = DriverSyncPlan(
    profile: true,
    activeOrder: true,
    ordersHistory: true,
    availableOrders: true,
    earningsToday: true,
    earningsWeek: true,
    earningsMonth: true,
    supportContacts: true,
  );

  /// [tabIndex]: 0 map, 1 orders, 2 earnings, 3 profile.
  /// [earningsPeriodIndex]: 0 month, 1 week, 2 today (matches existing UI).
  factory DriverSyncPlan.forTick({
    required int tick,
    required int tabIndex,
    required int earningsPeriodIndex,
    required bool forceFull,
    required bool needSupportContacts,
  }) {
    if (forceFull) {
      return DriverSyncPlan(
        profile: true,
        activeOrder: true,
        ordersHistory: true,
        availableOrders: true,
        earningsToday: true,
        earningsWeek: true,
        earningsMonth: true,
        supportContacts: needSupportContacts,
      );
    }

    // Heartbeat: always poll active assignment (cheap, critical).
    final deep = tick > 0 && tick % 4 == 0;
    final onOrders = tabIndex == 1;
    final onEarnings = tabIndex == 2;
    final onProfile = tabIndex == 3;

    return DriverSyncPlan(
      profile: deep || onProfile,
      activeOrder: true,
      ordersHistory: deep || onOrders,
      availableOrders: deep || onOrders,
      earningsToday: deep || tabIndex == 0 || (onEarnings && earningsPeriodIndex == 2),
      earningsWeek: onEarnings && earningsPeriodIndex == 1,
      earningsMonth: onEarnings && earningsPeriodIndex == 0,
      supportContacts: needSupportContacts,
    );
  }

  /// Seconds between silent polls.
  static int intervalSeconds({required bool hasActiveOrder}) =>
      hasActiveOrder ? 5 : 12;
}
