import 'package:flutter/material.dart';

import '../data/fake_data.dart';
import '../models/place_enums.dart';
import 'detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final List<dynamic> allItems;

  const GlobalSearchScreen({
    Key? key,
    required this.allItems,
  }) : super(key: key);

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// ✅ Même logique que CategoryListScreen : un filtre de catégorie
  /// "Tous" = aucune restriction
  PlaceCategory? _categoryFilter; // null => Tous

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // SAFE getters (dynamic)
  // ---------------------------
  T? _tryGet<T>(dynamic obj, T Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String _nameOf(dynamic p) =>
      _tryGet(p, () => p.nom.toString())?.trim() ??
          _tryGet(p, () => p.name.toString())?.trim() ??
          '';

  String _descOf(dynamic p) =>
      _tryGet(p, () => p.description.toString())?.trim() ??
          _tryGet(p, () => p.desc.toString())?.trim() ??
          '';
  String _imageOf(dynamic p) =>
      _tryGet(p, () => p.image.toString())?.trim() ??
          _tryGet(p, () => p.imageUrl.toString())?.trim() ??
          _tryGet(p, () => p.photo.toString())?.trim() ??
          _tryGet(p, () => p.cover.toString())?.trim() ??
          '';
  Widget _thumb(ThemeData theme, String path, PlaceCategory category) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final isAsset = path.startsWith('assets/');

    Widget fallback() => Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_placeIcon(category), color: theme.colorScheme.primary),
    );

    if (path.isEmpty) return fallback();

    // ✅ Asset image
    if (isAsset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          path,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    // ✅ Network image
    if (isNetwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          path,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    }

    // Si ton path n’a ni "assets/" ni "http", on fallback (ou adapte selon ton data)
    return fallback();
  }

  String _addressOf(dynamic p) =>
      _tryGet(p, () => p.address.toString())?.trim() ??
          _tryGet(p, () => p.adresse.toString())?.trim() ??
          '';

  // ---------------------------
  // SMART category inference
  // ---------------------------
  PlaceCategory _inferCategory(dynamic place) {
    if (fakeSites.contains(place)) return PlaceCategory.site;
    if (fakeRestos.contains(place)) return PlaceCategory.resto;
    if (fakeHotels.contains(place)) return PlaceCategory.hotel;
    if (fakeEvents.contains(place)) return PlaceCategory.event;
    if (fakeEntreprises.contains(place)) return PlaceCategory.entreprise;
    if (fakeShoppings.contains(place)) return PlaceCategory.shopping;

    // fallback sûr
    return PlaceCategory.site;
  }

  bool _matchesQuery(dynamic p, String q) {
    if (q.isEmpty) return true;

    final hay = [
      _nameOf(p),
      _descOf(p),
      _addressOf(p),
    ].join(' ').toLowerCase();

    return hay.contains(q.toLowerCase());
  }

  bool _matchesCategory(dynamic p) {
    if (_categoryFilter == null) return true; // Tous
    return _inferCategory(p) == _categoryFilter;
  }

  List<dynamic> _filteredPlaces(String q) {
    return widget.allItems
        .where((p) => _matchesCategory(p) && _matchesQuery(p, q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final q = _searchCtrl.text.trim();
    final places = _filteredPlaces(q);

    // ✅ IMPORTANT : plus de "Tape un mot clé" -> on affiche tout par défaut
    final bool emptyAll = places.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // Search + Filter (catégorie)
            // =========================
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.grey.shade100
                          : Colors.grey.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Filtre de catégorie (comme CategoryListScreen)
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: _categoryDropdown(theme),
                  //     ),
                  //     const SizedBox(width: 10),
                  //     // Text(
                  //     //   '${places.length} résultat(s)',
                  //     //   style: theme.textTheme.bodySmall?.copyWith(
                  //     //     fontWeight: FontWeight.w700,
                  //     //     color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                  //     //   ),
                  //     // ),
                  //   ],
                  // ),
                ],
              ),
            ),

            // const Divider(height: 0.1),

            // =========================
            // Results
            // =========================
            Expanded(
              child: emptyAll
                  ? _emptyState(theme, 'Aucun résultat.')
                  : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                children: [
                  ...places.map((p) => _placeTile(context, theme, p)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // UI Widgets
  // ---------------------------

  Widget _categoryDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PlaceCategory?>(
          isExpanded: true,
          value: _categoryFilter,
          icon: const Icon(Icons.keyboard_arrow_down),
          borderRadius: BorderRadius.circular(14),
          items: [
            const DropdownMenuItem<PlaceCategory?>(
              value: null,
              child: Text('Tous'),
            ),
            DropdownMenuItem(
              value: PlaceCategory.hotel,
              child: Text(_labelOf(PlaceCategory.hotel)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.resto,
              child: Text(_labelOf(PlaceCategory.resto)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.event,
              child: Text(_labelOf(PlaceCategory.event)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.site,
              child: Text(_labelOf(PlaceCategory.site)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.entreprise,
              child: Text(_labelOf(PlaceCategory.entreprise)),
            ),
            DropdownMenuItem(
              value: PlaceCategory.shopping,
              child: Text(_labelOf(PlaceCategory.shopping)),
            ),
          ],
          onChanged: (v) => setState(() => _categoryFilter = v),
        ),
      ),
    );
  }

  String _labelOf(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.hotel:
        return 'Hôtels';
      case PlaceCategory.resto:
        return 'Restaurants';
      case PlaceCategory.event:
        return 'Événements';
      case PlaceCategory.site:
        return 'Sites';
      case PlaceCategory.entreprise:
        return 'Business';
      case PlaceCategory.shopping:
        return 'Market';
    default:
      return 'Autres';
    }
  }

  IconData _placeIcon(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.hotel:
        return Icons.hotel;
      case PlaceCategory.resto:
        return Icons.restaurant;
      case PlaceCategory.event:
        return Icons.event;
      case PlaceCategory.site:
        return Icons.landscape;
      case PlaceCategory.entreprise:
        return Icons.home_work;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
    default:
      return Icons.place_outlined;
    }
  }

  Widget _placeTile(BuildContext context, ThemeData theme, dynamic place) {
    final name = _nameOf(place);
    final desc = _descOf(place);
    final category = _inferCategory(place);
    final img = _imageOf(place);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _placeImage(place),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Sans nom' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          desc.isEmpty ? _addressOf(place) : desc,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailScreen(
                place: place,
                category: category,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(ThemeData theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
          ),
        ),
      ),
    );
  }

  Widget _placeImage(dynamic place) {
    String? img;

    try {
      if (place.images != null && place.images.isNotEmpty) {
        img = place.images.first;
      } else if (place.image != null) {
        img = place.image;
      }
    } catch (_) {}

    if (img == null || img.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported),
      );
    }

    if (img.startsWith('http')) {
      return Image.network(img, fit: BoxFit.cover);
    }

    return Image.asset(
      img,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.broken_image),
      ),
    );
  }

}