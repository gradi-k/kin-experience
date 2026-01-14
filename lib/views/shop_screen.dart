// lib/views/shop_screen.dart
import 'package:flutter/material.dart';
import '../data/fake_shop_data.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchCtrl = TextEditingController();
  String _activeCategory = 'Tout';
  String _sort = 'Populaire'; // Populaire | Prix ↑ | Prix ↓ | Promo
  bool _onlyPromo = false;
  bool _onlyFreeShipping = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ShopProduct> _filtered() {
    final q = _searchCtrl.text.trim().toLowerCase();

    var items = fakeShopProducts.where((p) {
      final matchesCategory =
      _activeCategory == 'Tout' ? true : p.category == _activeCategory;
      final matchesQuery = q.isEmpty
          ? true
          : (p.title.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q));
      final matchesPromo = _onlyPromo ? p.onSale : true;
      final matchesShip = _onlyFreeShipping ? p.freeShipping : true;
      return matchesCategory && matchesQuery && matchesPromo && matchesShip;
    }).toList();

    // Sorting
    switch (_sort) {
      case 'Prix ↑':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Prix ↓':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Promo':
        items.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        break;
      default:
      // Populaire: rating*reviews as signal
        double score(ShopProduct p) => p.rating * (p.reviewCount / 100.0);
        items.sort((a, b) => score(b).compareTo(score(a)));
        break;
    }

    return items;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Shop'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: () => _toast('Panier (à connecter)'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Search + banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    _PromoBanner(
                      onTap: () {
                        setState(() {
                          _onlyPromo = true;
                          _sort = 'Promo';
                        });
                        _toast('Filtre: Promotions');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Categories
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: shopCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final c = shopCategories[i];
                    final selected = c == _activeCategory;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() => _activeCategory = c),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : null,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.cardColor,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: theme.dividerColor.withOpacity(0.35),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Filters row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DropdownPill<String>(
                      value: _sort,
                      items: const ['Populaire', 'Prix ↑', 'Prix ↓', 'Promo'],
                      onChanged: (v) => setState(() => _sort = v ?? _sort),
                      icon: Icons.swap_vert,
                      label: 'Trier',
                    ),
                    _TogglePill(
                      label: 'Promos',
                      icon: Icons.local_offer_outlined,
                      value: _onlyPromo,
                      onChanged: (v) => setState(() => _onlyPromo = v),
                    ),
                    _TogglePill(
                      label: 'Livraison gratuite',
                      icon: Icons.local_shipping_outlined,
                      value: _onlyFreeShipping,
                      onChanged: (v) => setState(() => _onlyFreeShipping = v),
                    ),
                    Text(
                      '${items.length} produit(s)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Products Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              sliver: items.isEmpty
                  ? SliverToBoxAdapter(
                child: _EmptyState(
                  onReset: () {
                    setState(() {
                      _activeCategory = 'Tout';
                      _sort = 'Populaire';
                      _onlyPromo = false;
                      _onlyFreeShipping = false;
                      _searchCtrl.clear();
                    });
                  },
                ),
              )
                  : SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final p = items[index];
                    return _ProductCard(
                      product: p,
                      onTap: () => _openDetails(p),
                      onAddToCart: () => _toast('Ajouté au panier'),
                    );
                  },
                  childCount: items.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(ShopProduct p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: p),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Components
// -----------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit, une marque…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.90),
              theme.colorScheme.primary.withOpacity(0.55),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offres du jour — jusqu’à -60% sur une sélection',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Voir',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TogglePill({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(label),
      avatar: Icon(icon, size: 18),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: value ? theme.colorScheme.primary : null,
      ),
      selectedColor: theme.colorScheme.primary.withOpacity(0.12),
      backgroundColor: theme.cardColor,
      shape: StadiumBorder(
        side: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  final String label;

  const _DropdownPill({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            items: items
                .map(
                  (e) => DropdownMenuItem<T>(
                value: e,
                child: Text(
                  e.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.dividerColor.withOpacity(0.08),
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: theme.dividerColor.withOpacity(0.06),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),

                    // Badges
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Row(
                        children: [
                          if (product.onSale)
                            _Badge(
                              text: '-${product.discountPercent}%',
                              bg: Colors.red.withOpacity(0.92),
                            ),
                          if (product.prime) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              text: 'Express',
                              bg: theme.colorScheme.primary.withOpacity(0.92),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (product.stock <= 10)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: _Badge(
                          text: 'Stock faible',
                          bg: Colors.black.withOpacity(0.70),
                        ),
                      ),
                  ],
                ),
              ),

              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${product.reviewCount})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (product.freeShipping)
                          const Icon(Icons.local_shipping_outlined, size: 18),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.onSale)
                          Text(
                            '\$${product.oldPrice!.toStringAsFixed(2)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          tooltip: 'Ajouter au panier',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  const _Badge({required this.text, required this.bg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aucun produit trouvé',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Modifie la recherche ou réinitialise les filtres.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Simple details screen (optionnel, mais donne un rendu "e-commerce")
// -----------------------------------------------------------------------------
class ProductDetailsScreen extends StatelessWidget {
  final ShopProduct product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 1.25,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.dividerColor.withOpacity(0.08),
                  child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            product.brand,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.star, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text(
                '${product.rating.toStringAsFixed(1)}  (${product.reviewCount} avis)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (product.freeShipping)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Livraison gratuite',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              if (product.onSale)
                Text(
                  '\$${product.oldPrice!.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const Spacer(),
              if (product.onSale)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '-${product.discountPercent}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          _DetailsLine(label: 'Catégorie', value: product.category),
          _DetailsLine(label: 'Stock', value: product.stock.toString()),
          _DetailsLine(label: 'Livraison', value: product.freeShipping ? 'Gratuite' : 'Payante'),
          _DetailsLine(label: 'Service', value: product.prime ? 'Express' : 'Standard'),

          const SizedBox(height: 18),

          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Produit sélectionné pour donner un rendu e-commerce moderne. '
                'Branche ensuite ta vraie source de données (API/Firestore) sur ce design.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Favoris (à connecter)')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.favorite_border),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ajouté au panier')),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Ajouter au panier'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailsLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}