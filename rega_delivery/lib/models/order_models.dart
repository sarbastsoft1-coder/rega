/// Order domain models for REGA Delivery.

enum OrderStatus {
  driverAssigned,
  driverArrivingPickup,
  arrivedPickup,
  pickedUp,
  onTheWay,
  arrivedCustomer,
  delivered,
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final int price;

  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class OrderModel {
  final String id;
  final String orderNumber;
  OrderStatus status;
  final String vendorStatus;
  final String merchantName;
  final String merchantAddress;
  final String merchantPhone;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final List<OrderItem> items;
  final int subtotal;
  final int discountAmount;
  final int deliveryFee;
  final int tip;
  final int waitingBonus;
  final int totalAmount;
  final String paymentMethod;
  final String customerNotes;
  final int? dbId;
  final String handoverPin;
  final String deliveryPin;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.vendorStatus = 'preparing',
    required this.merchantName,
    required this.merchantAddress,
    required this.merchantPhone,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.items,
    this.subtotal = 0,
    this.discountAmount = 0,
    required this.deliveryFee,
    required this.tip,
    this.waitingBonus = 0,
    this.totalAmount = 0,
    this.paymentMethod = 'cash',
    this.customerNotes = '',
    this.dbId,
    this.handoverPin = '',
    this.deliveryPin = '',
    this.storeLat = 34.6836,
    this.storeLng = 45.3189,
    this.customerLat = 34.6912,
    this.customerLng = 45.3264,
  });

  int get itemsTotal => subtotal > 0
      ? subtotal
      : items.fold(0, (sum, i) => sum + (i.price * i.quantity));
  int get itemsCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalEarnings => deliveryFee + tip + waitingBonus;
  int get customerCashToCollect =>
      totalAmount > 0 ? totalAmount : (itemsTotal - discountAmount + deliveryFee + tip);

  /// Returns a clean display number like #10056 (stripping prefixes like 'RA-', internal '#', etc.)
  String get displayOrderNumber {
    if (orderNumber.trim().isEmpty) return '';
    var clean = orderNumber.trim();
    clean = clean.replaceAll('#', '');
    if (clean.toUpperCase().startsWith('RA-')) {
      clean = clean.substring(3);
    } else if (clean.toUpperCase().startsWith('RA')) {
      clean = clean.substring(2);
    }
    clean = clean.trim();
    if (clean.isEmpty) return '';
    return '#$clean';
  }
}

/// Standalone formatter for order numbers across strings and maps
String formatOrderCode(dynamic raw) {
  if (raw == null) return '';
  var s = raw.toString().trim();
  if (s.isEmpty) return '';
  s = s.replaceAll('#', '').trim();
  if (s.toUpperCase().startsWith('RA-')) {
    s = s.substring(3);
  } else if (s.toUpperCase().startsWith('RA')) {
    s = s.substring(2);
  }
  s = s.trim();
  if (s.isEmpty) return '';
  return '#$s';
}

String formatMoney(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

