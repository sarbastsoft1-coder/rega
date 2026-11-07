import 'package:flutter/foundation.dart';
import '../models/customer_models.dart';

class CartNotifier extends ChangeNotifier {
  final List<CartEntry> _items = [];

  List<CartEntry> get items => List.unmodifiable(_items);
  int get totalQuantity => _items.fold(0, (sum, e) => sum + e.quantity);
  int get subtotal =>
      _items.fold(0, (sum, e) => sum + e.product.price * e.quantity);
  bool get isEmpty => _items.isEmpty;

  void addProduct(ProductItem product, {int quantity = 1, String notes = ''}) {
    final existing = _items.where((e) => e.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      _items.add(CartEntry(product: product, quantity: quantity, specialNotes: notes));
    }
    notifyListeners();
  }

  void setQuantity(ProductItem product, int quantity) {
    final idx = _items.indexWhere((e) => e.product.id == product.id);
    if (idx < 0) return;
    if (quantity <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx].quantity = quantity;
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  /// Mutable list for legacy UI that still mutates entries then calls [notify].
  List<CartEntry> get mutableItems => _items;

  void notify() => notifyListeners();
}
