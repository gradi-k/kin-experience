import 'package:flutter/material.dart';
import '../data/fake_products.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class ShopProductsScreen extends StatefulWidget {
  const ShopProductsScreen({super.key});

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _activeCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final cats = <String>{'All'};
    for (final p in fakeProducts) {
      cats.add(p.category);
    }
    return cats.toList();
  }

  List<Product> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return fakeProducts.where((p) {
      final matchCat = _activeCategory == 'All' ? true : p.category == _activeCategory;
      final matchQ = q.isEmpty
          ? true
          : (p.title.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q));
      return matchCat && matchQ;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final deals = _filtered.where((p) => p.isDeal).toList();
    final all = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        title: const Text(
          'dyson',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search products and parts',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Big Title
          Text(
            'KinShop: Engineered\nfor Excellence!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),

          // Category chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final c = _categories[i];
                final active = c == _activeCategory;
                return ChoiceChip(
                  label: Text(c),
                  selected: active,
                  onSelected: (_) => setState(() => _activeCategory = c),
                  selectedColor: theme.colorScheme.primary.withOpacity(0.12),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? theme.colorScheme.primary : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  backgroundColor: Colors.white,
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Deals (horizontal cards)
          if (deals.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Deals',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: deals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final p = deals[index];
                  return _DealCard(
                    product: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // All products (grid)
          Text(
            'All products',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final p = all[index];
              return _ProductGridCard(
                product: p,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _DealCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _img(product.images.first),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD2A100)),
                const SizedBox(width: 4),
                Text(
                  '${product.rating.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _img(String path) {
    return path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.asset(path, fit: BoxFit.cover);
  }
}

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductGridCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _img(product.images.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD2A100)),
                  const SizedBox(width: 4),
                  Text(
                    '${product.rating.toStringAsFixed(1)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '\$${product.price.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _img(String path) {
    return path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.asset(path, fit: BoxFit.cover);
  }
}
