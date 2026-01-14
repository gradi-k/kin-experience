class Product {
  final String id;
  final String title;
  final String brand;
  final String description;
  final double price;
  final double rating;
  final int reviewsCount;
  final bool inStock;
  final List<String> images; // assets/.. ou url
  final List<String> colors; // ex: ["Black", "White"]
  final String category;
  final bool isDeal;

  const Product({
    required this.id,
    required this.title,
    required this.brand,
    required this.description,
    required this.price,
    required this.rating,
    required this.reviewsCount,
    required this.inStock,
    required this.images,
    required this.colors,
    required this.category,
    this.isDeal = false,
  });
}
