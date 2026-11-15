// Shared customer-app domain models (used by UI + Provider notifiers).

class Neighborhood {
  final String id;
  final String name;
  final String nameEn;
  final int deliveryFee;
  final double? lat;
  final double? lng;

  const Neighborhood({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.deliveryFee,
    this.lat,
    this.lng,
  });

  bool get hasCenter => lat != null && lng != null;

  Neighborhood copyWith({
    String? id,
    String? name,
    String? nameEn,
    int? deliveryFee,
    double? lat,
    double? lng,
  }) {
    return Neighborhood(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class StoreItem {
  final String id;
  final String name;
  final String category;
  /// Backend marketplace category id — used to show the store under the right home tile.
  final int? categoryId;
  final double rating; // لە ١٠ (نموونە: ٩.٨)
  final int reviewCount;
  final String deliveryTime;
  final int deliveryFee;
  final String imageUrl;
  final String address;
  final bool isOpen;
  final String phone;
  final String? discountBadge;
  final double lat;
  final double lng;

  StoreItem({
    required this.id,
    required this.name,
    required this.category,
    this.categoryId,
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.imageUrl,
    required this.address,
    this.isOpen = true,
    required this.phone,
    this.discountBadge,
    this.lat = 34.6836,
    this.lng = 45.3189,
  });

  /// نمرەی پیشاندراو لە ١٠ — پشتیوانی بۆ داتای کۆنی لە ٥
  double get ratingOutOf10 {
    if (rating <= 0) return 0;
    if (rating <= 5.01) return double.parse((rating * 2).toStringAsFixed(1));
    return double.parse(rating.clamp(0, 10).toStringAsFixed(1));
  }
}

class ProductItem {
  final String id;
  final String storeId;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final String category;
  final String? subCategory;

  ProductItem({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.subCategory,
  });
}

class CartEntry {
  final ProductItem product;
  int quantity;
  String specialNotes;

  CartEntry({
    required this.product,
    this.quantity = 1,
    this.specialNotes = '',
  });
}

class UserProfile {
  String name;
  String email;
  String phone;
  String address;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });
}

class OrderItem {
  final String id;
  final String storeName;
  final int totalAmount;
  String status;
  final String deliveryPin;
  final double storeLat;
  final double storeLng;
  final double customerLat;
  final double customerLng;
  final DateTime date;
  final List<CartEntry> items;
  final String driverName;
  final String driverPhone;
  final String address;

  OrderItem({
    required this.id,
    required this.storeName,
    required this.totalAmount,
    required this.status,
    required this.date,
    required this.items,
    required this.driverName,
    required this.driverPhone,
    this.address = 'گەڕەکی شەهیدان - کۆڵانی ١٤، تەنیشت قوتابخانەی کەلار',
    this.deliveryPin = '4821',
    this.storeLat = 34.6836,
    this.storeLng = 45.3189,
    this.customerLat = 34.6912,
    this.customerLng = 45.3264,
  });
}

/// Populated at runtime from backend bootstrap — NOT the source of truth.
/// Empty until `/bootstrap` (or admin zones API) fills it.
final List<Neighborhood> kalarNeighborhoods = [];
