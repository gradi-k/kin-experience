import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _activeImage = 0;
  String? _activeColor;

  @override
  void initState() {
    super.initState();
    _activeColor = widget.product.colors.isNotEmpty ? widget.product.colors.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            // Top bar (back + actions)
            Row(
              children: [
                _roundIcon(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _roundIcon(icon: Icons.shopping_bag_outlined, onTap: () {}),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black12,
                  child: const Icon(Icons.person, size: 18, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Main image
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 1.05,
                child: _img(p.images[_activeImage]),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              p.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFD2A100)),
                const SizedBox(width: 4),
                Text(
                  p.rating.toStringAsFixed(1),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${p.reviewsCount} Reviews)',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Text(
                  '\$${p.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: p.inStock ? const Color(0xFF17B26A) : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.inStock ? 'In stock' : 'Out of stock',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.inStock ? const Color(0xFF17B26A) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                      label: const Text('Add to cart'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: p.inStock ? () {} : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.black12,
                        disabledForegroundColor: Colors.black38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Buy Now'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Color selector
            if (p.colors.isNotEmpty) ...[
              Row(
                children: [
                  Text('Color:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Wrap(
                    spacing: 10,
                    children: p.colors.map((c) {
                      final active = c == _activeColor;
                      return ChoiceChip(
                        label: Text(c),
                        selected: active,
                        onSelected: (_) => setState(() => _activeColor = c),
                        selectedColor: theme.colorScheme.primary.withOpacity(0.14),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: active ? theme.colorScheme.primary : Colors.black87,
                        ),
                        backgroundColor: Colors.black.withOpacity(0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Thumbnails (horizontal)
            if (p.images.length > 1) ...[
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final active = i == _activeImage;
                    return InkWell(
                      onTap: () => setState(() => _activeImage = i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 72,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: 2,
                            color: active ? theme.colorScheme.primary : Colors.transparent,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _img(p.images[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Description
            Text(
              'Description',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              p.description,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.35, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
          color: Colors.white,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _img(String path) {
    return path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.asset(path, fit: BoxFit.cover);
  }
}
