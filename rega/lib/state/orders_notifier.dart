import 'package:flutter/foundation.dart';
import '../models/customer_models.dart';

class OrdersNotifier extends ChangeNotifier {
  final List<OrderItem> _orders = [];

  List<OrderItem> get orders => List.unmodifiable(_orders);
  List<OrderItem> get mutableOrders => _orders;

  void replaceAll(List<OrderItem> next) {
    _orders
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void insertFront(OrderItem order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void notify() => notifyListeners();
}
