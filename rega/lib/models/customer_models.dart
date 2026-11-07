// Shared customer-app domain models (used by UI + Provider notifiers).

class Neighborhood {
  final String id;
  final String name;
  final String nameEn;
  final int deliveryFee;

  Neighborhood({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.deliveryFee,
  });
}

class StoreItem {
  final String id;
  final String name;
  final String category;
  final double rating;
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
    required this.rating,
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

final List<Neighborhood> kalarNeighborhoods = [
  Neighborhood(id: 'n1', name: 'شارۆچکەی رزگاری', nameEn: 'Rzgari', deliveryFee: 1500),
  Neighborhood(id: 'n2', name: 'گەڕەکی زانکۆ', nameEn: 'Zanko', deliveryFee: 1000),
  Neighborhood(id: 'n3', name: 'گەڕەکی شەهیدان', nameEn: 'Shahidan', deliveryFee: 1000),
  Neighborhood(id: 'n4', name: 'گەڕەکی سیروان', nameEn: 'Sirwan', deliveryFee: 1500),
  Neighborhood(id: 'n5', name: 'گەڕەکی شۆڕش', nameEn: 'Shorish', deliveryFee: 1500),
  Neighborhood(id: 'n6', name: 'گەڕەکی بێساری', nameEn: 'Besari', deliveryFee: 2000),
  Neighborhood(id: 'n7', name: 'گەڕەکی کاکەییان', nameEn: 'Kakeyan', deliveryFee: 1500),
  Neighborhood(id: 'n8', name: 'گەڕەکی فەرمانبەران', nameEn: 'Farmanbaran', deliveryFee: 1000),
  Neighborhood(id: 'n9', name: 'ناو بازاڕی کەلار', nameEn: 'Downtown Market', deliveryFee: 1000),
];
