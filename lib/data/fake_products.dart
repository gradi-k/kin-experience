import '../models/product.dart';

final List<Product> fakeProducts = [
  Product(
    id: 'p1',
    title: 'Wireless Bluetooth Headphone',
    brand: 'Kin Shop',
    description:
    "Enjoy premium audio with these over-ear wireless headphones. Soft padded ear cups for all-day comfort, powerful bass, and up to 20 hours of battery life.",
    price: 140.0,
    rating: 4.5,
    reviewsCount: 122,
    inStock: true,
    images: const [
      'assets/images/products/headphone_1.png',
      'assets/images/products/headphone_2.png',
      'assets/images/products/headphone_3.png',
      'assets/images/products/headphone_4.png',
    ],
    colors: const ['Black', 'White'],
    category: 'Audio',
    isDeal: true,
  ),
  Product(
    id: 'p2',
    title: 'Air Purifier Pro',
    brand: 'Kin Shop',
    description:
    "Purifier with HEPA filtration for home and office. Quiet mode, smart sensors, and auto control.",
    price: 299.0,
    rating: 4.3,
    reviewsCount: 87,
    inStock: true,
    images: const [
      'assets/images/products/purifier_1.png',
      'assets/images/products/purifier_2.png',
    ],
    colors: const ['Silver', 'Black'],
    category: 'Home',
    isDeal: true,
  ),
  Product(
    id: 'p3',
    title: 'Vacuum Cleaner X',
    brand: 'Kin Shop',
    description:
    "Lightweight vacuum cleaner with powerful suction, washable filter, and long-lasting battery.",
    price: 199.0,
    rating: 4.6,
    reviewsCount: 203,
    inStock: false,
    images: const [
      'assets/images/products/vacuum_1.png',
      'assets/images/products/vacuum_2.png',
    ],
    colors: const ['Grey'],
    category: 'Home',
  ),
];
