// lib/data/fake_shop_data.dart
import 'package:flutter/foundation.dart';

@immutable
class ShopProduct {
  final String id;
  final String title;
  final String brand;
  final String category; // Ex: "Tech", "Mode", "Maison"
  final String imageUrl; // Network image
  final double price;
  final double? oldPrice; // Promo si non null
  final double rating; // 0..5
  final int reviewCount;
  final bool freeShipping;
  final bool prime; // style "Prime" / "Express"
  final int stock; // stock restant

  const ShopProduct({
    required this.id,
    required this.title,
    required this.brand,
    required this.category,
    required this.imageUrl,
    required this.price,
    this.oldPrice,
    required this.rating,
    required this.reviewCount,
    required this.freeShipping,
    required this.prime,
    required this.stock,
  });

  bool get onSale => oldPrice != null && oldPrice! > price;

  int get discountPercent {
    if (!onSale) return 0;
    final pct = ((1 - (price / oldPrice!)) * 100).round();
    return pct.clamp(1, 95);
  }
}

const List<String> shopCategories = [
  'Tout',
  'Tech',
  'Mode',
  'Beauté',
  'Maison',
  'Sport',
  'Accessoires',
];

const List<ShopProduct> fakeShopProducts = [
  ShopProduct(
    id: 'p1',
    title: 'Casque Bluetooth ANC Pro',
    brand: 'Auralink',
    category: 'Tech',
    imageUrl:
    'https://images.unsplash.com/photo-1518441902117-f0a7e3cc1b7c?auto=format&fit=crop&w=1200&q=80',
    price: 49.99,
    oldPrice: 79.99,
    rating: 4.6,
    reviewCount: 1382,
    freeShipping: true,
    prime: true,
    stock: 24,
  ),
  ShopProduct(
    id: 'p2',
    title: 'Montre connectée Sport',
    brand: 'PulseOne',
    category: 'Tech',
    imageUrl:
    'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=1200&q=80',
    price: 39.90,
    oldPrice: 59.90,
    rating: 4.4,
    reviewCount: 912,
    freeShipping: true,
    prime: false,
    stock: 17,
  ),
  ShopProduct(
    id: 'p3',
    title: 'Sac à dos Urbain Premium',
    brand: 'KivuWear',
    category: 'Accessoires',
    imageUrl:
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80',
    price: 28.50,
    oldPrice: null,
    rating: 4.5,
    reviewCount: 321,
    freeShipping: false,
    prime: false,
    stock: 41,
  ),
  ShopProduct(
    id: 'p4',
    title: 'Sneakers Street Comfort',
    brand: 'Matonge',
    category: 'Mode',
    imageUrl:
    'https://images.unsplash.com/photo-1528701800489-20be3c9f1737?auto=format&fit=crop&w=1200&q=80',
    price: 34.99,
    oldPrice: 49.99,
    rating: 4.2,
    reviewCount: 778,
    freeShipping: true,
    prime: true,
    stock: 9,
  ),
  ShopProduct(
    id: 'p5',
    title: 'Parfum Élégance 50ml',
    brand: 'Senteur',
    category: 'Beauté',
    imageUrl:
    'https://images.unsplash.com/photo-1541643600914-78b084683601?auto=format&fit=crop&w=1200&q=80',
    price: 19.99,
    oldPrice: 29.99,
    rating: 4.7,
    reviewCount: 544,
    freeShipping: true,
    prime: false,
    stock: 32,
  ),
  ShopProduct(
    id: 'p6',
    title: 'Blender Smoothie Compact',
    brand: 'HomeLab',
    category: 'Maison',
    imageUrl:
    'https://images.unsplash.com/photo-1585237672814-8f85a8118bf1?auto=format&fit=crop&w=1200&q=80',
    price: 24.00,
    oldPrice: 35.00,
    rating: 4.3,
    reviewCount: 220,
    freeShipping: true,
    prime: true,
    stock: 14,
  ),
  ShopProduct(
    id: 'p7',
    title: 'T-shirt Oversize Essential',
    brand: 'KinStyle',
    category: 'Mode',
    imageUrl:
    'https://images.unsplash.com/photo-1520975958225-4f3c4f8b9f03?auto=format&fit=crop&w=1200&q=80',
    price: 12.90,
    oldPrice: null,
    rating: 4.1,
    reviewCount: 146,
    freeShipping: false,
    prime: false,
    stock: 65,
  ),
  ShopProduct(
    id: 'p8',
    title: 'Tapis déco Minimal 160x230',
    brand: 'LumiHome',
    category: 'Maison',
    imageUrl:
    'https://images.unsplash.com/photo-1582582621959-48d27397dc04?auto=format&fit=crop&w=1200&q=80',
    price: 44.00,
    oldPrice: 55.00,
    rating: 4.4,
    reviewCount: 89,
    freeShipping: true,
    prime: false,
    stock: 6,
  ),
  ShopProduct(
    id: 'p9',
    title: 'Bouteille Sport Isotherme 1L',
    brand: 'HydroGo',
    category: 'Sport',
    imageUrl:
    'https://images.unsplash.com/photo-1526401485004-2aa7b3b0b0a6?auto=format&fit=crop&w=1200&q=80',
    price: 9.99,
    oldPrice: 14.99,
    rating: 4.6,
    reviewCount: 403,
    freeShipping: true,
    prime: true,
    stock: 53,
  ),
  ShopProduct(
    id: 'p10',
    title: 'Crème visage Hydratation+',
    brand: 'DermaPlus',
    category: 'Beauté',
    imageUrl:
    'https://images.unsplash.com/photo-1611930022073-84c8d8f2b2d4?auto=format&fit=crop&w=1200&q=80',
    price: 11.50,
    oldPrice: 16.00,
    rating: 4.5,
    reviewCount: 611,
    freeShipping: true,
    prime: false,
    stock: 27,
  ),
  ShopProduct(
    id: 'p11',
    title: 'Écouteurs In-Ear Bass+',
    brand: 'Auralink',
    category: 'Tech',
    imageUrl:
    'https://images.unsplash.com/photo-1590658165737-15a047b9a7b1?auto=format&fit=crop&w=1200&q=80',
    price: 14.90,
    oldPrice: 22.90,
    rating: 4.0,
    reviewCount: 1004,
    freeShipping: true,
    prime: true,
    stock: 38,
  ),
  ShopProduct(
    id: 'p12',
    title: 'Ceinture cuir Classic',
    brand: 'KivuWear',
    category: 'Accessoires',
    imageUrl:
    'https://images.unsplash.com/photo-1622560480654-d96214fdc887?auto=format&fit=crop&w=1200&q=80',
    price: 10.99,
    oldPrice: null,
    rating: 4.3,
    reviewCount: 72,
    freeShipping: false,
    prime: false,
    stock: 19,
  ),
];
