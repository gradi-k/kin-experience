// lib/views/category_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/location_controller.dart';
import '../controllers/places_controller.dart';
import '../localization/app_localizations.dart';
import '../models/place_enums.dart';
import '../views/widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran affichant la liste complète des lieux d'une catégorie.
class CategoryListScreen extends ConsumerStatefulWidget {
  final String title;
  final PlaceCategory category;

  const CategoryListScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _sort = 'Distance';
  bool _onlyTopRated = false;
  String _priceFilter = 'Tous';
  bool _nearMeEnabled = false;

  final List<_DistanceRange> _ranges = const [
    _DistanceRange(label: 'Près (1–100 m)', minMeters: 1, maxMeters: 100),
    _DistanceRange(label: 'Autour (100 m–5 km)', minMeters: 100, maxMeters: 5000),
    _DistanceRange(label: 'Large (5–10 km)', minMeters: 5000, maxMeters: 10000),
  ];
  int _rangeIndex = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helpers sécurisés
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

  String _addressOf(dynamic p) =>
      _tryGet(p, () => p.address.toString())?.trim() ??
          _tryGet(p, () => p.adresse.toString())?.trim() ??
          '';

  double _ratingOf(dynamic p) =>
      _tryGet<double>(p, () => (p.rating as double)) ??
          _tryGet<num>(p, () => (p.rating as num))?.toDouble() ??
          0.0;

  String _priceRangeOf(dynamic p) =>
      _tryGet(p, () => p.prixRange.toString())?.trim() ??
          _tryGet(p, () => p.priceRange.toString())?.trim() ??
          '';

  double? _latOf(dynamic p) =>
      _tryGet<num>(p, () => (p.latitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lat as num))?.toDouble();

  double? _lngOf(dynamic p) =>
      _tryGet<num>(p, () => (p.longitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lng as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lon as num))?.toDouble();

  String _normalizePrice(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (RegExp(r'^\$+$').hasMatch(v)) return v;
    final n = int.tryParse(v);
    if (n != null && n >= 1 && n <= 4) return r'$' * n;
    final firstNumMatch = RegExp(r'(\d+)').firstMatch(v);
    if (firstNumMatch != null) {
      final price = int.tryParse(firstNumMatch.group(1)!) ?? 0;
      if (price < 50) return r'$';
      if (price < 150) return r'$$';
      if (price < 350) return r'$$$';
      return r'$$$$';
    }
    return v;
  }

  bool _matchesQuery(dynamic p, String q) {
    if (q.isEmpty) return true;
    final hay = [_nameOf(p), _descOf(p), _addressOf(p), _priceRangeOf(p)]
        .join(' ')
        .toLowerCase();
    return hay.contains(q.toLowerCase());
  }

  bool _matchesPrice(dynamic p) {
    if (_priceFilter == 'Tous') return true;
    final normalized = _normalizePrice(_priceRangeOf(p));
    return normalized == _priceFilter;
  }

  double _distanceMetersBetween(Position userPos, dynamic p) {
    final lat = _latOf(p);
    final lng = _lngOf(p);
    if (lat == null || lng == null) return double.infinity;
    return Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      lat,
      lng,
    );
  }

  bool _matchesDistance(Position userPos, dynamic p) {
    final r = _ranges[_rangeIndex];
    final d = _distanceMetersBetween(userPos, p);
    if (!d.isFinite) return false;
    return d >= r.minMeters && d <= r.maxMeters;
  }

  List<dynamic> _applyFilters({
    required List<dynamic> items,
    required Position? userPos,
    required bool posReady,
  }) {
    final q = _searchCtrl.text.trim();
    if (_nearMeEnabled && !posReady) return [];

    final distCache = <dynamic, double>{};
    double distOf(dynamic p) {
      return distCache.putIfAbsent(
        p,
            () => (userPos == null ? double.infinity : _distanceMetersBetween(userPos, p)),
      );
    }

    var list = items.where((p) {
      final okQuery = _matchesQuery(p, q);
      final okPrice = _matchesPrice(p);
      final okTop = !_onlyTopRated ? true : _ratingOf(p) >= 4.5;
      final okDistance = !_nearMeEnabled
          ? true
          : (userPos != null ? _matchesDistance(userPos, p) : false);
      return okQuery && okPrice && okTop && okDistance;
    }).toList();

    if (_sort == 'Note') {
      list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    } else if (_sort == 'Distance') {
      if (userPos != null) {
        list.sort((a, b) => distOf(a).compareTo(distOf(b)));
      }
    } else if (_sort == 'Prix') {
      int weight(dynamic p) {
        final v = _normalizePrice(_priceRangeOf(p));
        if (RegExp(r'^\$+$').hasMatch(v)) return v.length;
        return 99;
      }
      list.sort((a, b) => weight(a).compareTo(weight(b)));
    }

    return list;
  }

  void _openFiltersSheet({
    required ThemeData theme,
    required AppLocalizations loc,
    required AsyncValue<Position> posAsync,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filtres',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Trier par', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Note', 'Distance', 'Prix'].map((s) {
                      final selected = _sort == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() => _sort = s);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Prix', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Tous', r'$', r'$$', r'$$$', r'$$$$'].map((s) {
                      final selected = _priceFilter == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() => _priceFilter = s);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Uniquement les mieux notés (4.5+)'),
                    value: _onlyTopRated,
                    onChanged: (v) {
                      setModalState(() => _onlyTopRated = v);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Près de moi'),
                    subtitle: Text(_ranges[_rangeIndex].label),
                    value: _nearMeEnabled,
                    onChanged: (v) {
                      setModalState(() => _nearMeEnabled = v);
                      setState(() {});
                    },
                  ),
                  if (_nearMeEnabled) ...[
                    const SizedBox(height: 8),
                    Text('Rayon', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(_ranges.length, (i) {
                        final selected = _rangeIndex == i;
                        return ChoiceChip(
                          label: Text(_ranges[i].label),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() => _rangeIndex = i);
                            setState(() {});
                          },
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniBanner(ThemeData theme, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final placesAsync = ref.watch(placesByCategoryProvider(widget.category));
    final posAsync = ref.watch(userPositionProvider);

    final userPos = posAsync.whenOrNull(data: (pos) => pos);
    final posReady = posAsync.hasValue && !posAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: placesAsync.when(
        data: (items) {
          final filtered = _applyFilters(
            items: items,
            userPos: userPos,
            posReady: posReady,
          );

          final showNearMeLoading = _nearMeEnabled && posAsync.isLoading;
          final showNearMeError = _nearMeEnabled && posAsync.hasError;
          final showNearMeEmpty = _nearMeEnabled && posReady && filtered.isEmpty;

          return Column(
            children: [
              // Barre de recherche + filtre
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: "Rechercher un lieu, un type…",
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _openFiltersSheet(
                          theme: theme,
                          loc: loc,
                          posAsync: posAsync,
                        ),
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ),

              // Ligne résultats
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Text(
                      "${filtered.length} résultat(s)",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _sort = 'Distance';
                          _onlyTopRated = false;
                          _priceFilter = 'Tous';
                          _nearMeEnabled = false;
                          _rangeIndex = 1;
                        });
                      },
                      child: const Text("Réinitialiser"),
                    ),
                  ],
                ),
              ),

              // Bannières UX
              if (showNearMeLoading)
                _miniBanner(theme, "Localisation en cours…", Colors.blue),
              if (showNearMeError)
                _miniBanner(theme, "Localisation indisponible. Activez GPS + permission.",
                    Colors.red),
              if (showNearMeEmpty)
                _miniBanner(theme,
                    "Aucun élément près de chez vous. Essayez un rayon plus grand.",
                    Colors.orange),

              // Liste
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final place = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: PlaceCard(
                        place: place,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(
                                place: place,
                                category: widget.category,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // ✅ Message générique au lieu d'erreur technique
        error: (e, _) => _buildEmptyState(theme),
      ),
    );
  }

  /// ✅ État vide avec message générique
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun lieu disponible',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Revenez plus tard ou essayez d\'autres filtres.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(placesByCategoryProvider(widget.category));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceRange {
  final String label;
  final double minMeters;
  final double maxMeters;

  const _DistanceRange({
    required this.label,
    required this.minMeters,
    required this.maxMeters,
  });
}