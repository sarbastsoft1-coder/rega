import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

/// Shared KPI / dashboard snapshot for shell badges + home screen.
class DashboardNotifier extends ChangeNotifier {
  DashboardNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  Map<String, dynamic> kpis = {};
  Map<String, dynamic> raw = {};
  List<dynamic> recentOrders = [];
  List<dynamic> radarDrivers = [];
  List<dynamic> revenueChart = [];
  int days = 7;

  int get pendingOrders => (kpis['active_orders_count'] as num?)?.toInt() ?? 0;
  int get onlineStores => (kpis['online_stores'] as num?)?.toInt() ?? 0;
  int get totalCustomers => (kpis['total_customers'] as num?)?.toInt() ?? 0;
  int get onlineDrivers => (kpis['online_drivers'] as num?)?.toInt() ?? 0;
  int get openTickets => (kpis['open_tickets_count'] as num?)?.toInt() ?? 0;

  Future<void> load({int? days, bool silent = false}) async {
    if (days != null) this.days = days;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final res = await api.getDashboard(days: this.days);
      final data = res['data'] as Map<String, dynamic>? ?? res;
      raw = Map<String, dynamic>.from(data);
      kpis = Map<String, dynamic>.from(data['kpis'] as Map? ?? {});
      recentOrders = List<dynamic>.from(data['recent_orders'] as List? ?? []);
      radarDrivers = List<dynamic>.from(data['radar_drivers'] as List? ?? []);
      revenueChart = List<dynamic>.from(data['revenue_chart'] as List? ?? []);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

/// Live admin work inbox (pending orders / stores / drivers / tickets).
class AdminInboxNotifier extends ChangeNotifier {
  AdminInboxNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> items = [];
  int unreadCount = 0;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final data = await api.getAdminInbox();
      _applyPayload(data);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadOnly() async {
    try {
      unreadCount = await api.getAdminInboxUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      final data = await api.markAdminInboxAllRead();
      _applyPayload(data);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markRead(String itemKey) async {
    try {
      final data = await api.markAdminInboxRead(itemKey);
      _applyPayload(data);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _applyPayload(Map<String, dynamic> data) {
    final raw = data['items'] as List<dynamic>? ?? [];
    items = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    unreadCount = (data['unread_count'] as num?)?.toInt() ?? 0;
  }
}

class OrdersNotifier extends ChangeNotifier {
  OrdersNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> orders = [];
  String statusFilter = 'all';

  Future<void> load({String? status, bool silent = false}) async {
    if (status != null) statusFilter = status;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final res = await api.getOrders(status: statusFilter);
      final raw = res['data'] as List<dynamic>? ?? [];
      orders = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class DriversNotifier extends ChangeNotifier {
  DriversNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> drivers = [];

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final list = await api.getDrivers();
      drivers = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class CustomersNotifier extends ChangeNotifier {
  CustomersNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> customers = [];

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final list = await api.getCustomers();
      customers = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class StoresNotifier extends ChangeNotifier {
  StoresNotifier(this.api);

  final ApiClient api;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> stores = [];

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final list = await api.getStores();
      stores = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
