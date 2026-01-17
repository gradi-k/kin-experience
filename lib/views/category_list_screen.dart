import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kin_experience/controllers/location_controller.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';
import '../views/widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran affichant la liste complète des lieux d’une catégorie.
/// Ajout: Search + Filters + ✅ Filtre "près de vous" par rayon (1–100m, 100m–5km, 5–10km)
class CategoryListScreen extends ConsumerStatefulWidget {
  final String title;
  final List<dynamic> items;
  final PlaceCategory category;

  const CategoryListScreen({
    Key? key,
    required this.title,
    required this.items,
    required this.category,
  }) : super(key: key);

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _sort = 'Pertinence'; // Pertinence | Note | Distance | Prix
  bool _onlyTopRated = false;
  String _priceFilter = 'Tous';

  // ✅ Filtre distance
  bool _nearMeEnabled = true;

  // ✅ Rayons demandés
  final List<_DistanceRange> _ranges = const [
    _DistanceRange(label: 'Près (1–100 m)', minMeters: 1, maxMeters: 100),
    _DistanceRange(label: 'Autour (100 m–5 km)', minMeters: 100, maxMeters: 5000),
    _DistanceRange(label: 'Large (5–10 km)', minMeters: 5000, maxMeters: 10000),
  ];
  int _rangeIndex = 1; // défaut: 100m–5km

  // ✅ Debug: montre la position + les 5 lieux les plus proches
  static const bool _debugShowPosition = false;
  static const bool _debugShowNearest = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // Helpers "safe" (dynamic)
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

  // ✅ Latitude/Longitude (pour calcul distance)
  double? _latOf(dynamic p) =>
      _tryGet<num>(p, () => (p.latitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lat as num))?.toDouble();

  double? _lngOf(dynamic p) =>
      _tryGet<num>(p, () => (p.longitude as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lng as num))?.toDouble() ??
          _tryGet<num>(p, () => (p.lon as num))?.toDouble();

  // Normalise le filtre prix en "$", "$$", "$$$", "$$$$" si possible
  String _normalizePrice(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (RegExp(r'^\$+$').hasMatch(v)) return v;

    final n = int.tryParse(v);
    if (n != null && n >= 1 && n <= 4) return r'$' * n;

    // Exemple: "60-100" => non filtrable avec $, $$, etc.
    return v;
  }

  bool _matchesQuery(dynamic p, String q) {
    if (q.isEmpty) return true;
    final hay = [
      _nameOf(p),
      _descOf(p),
      _addressOf(p),
      _priceRangeOf(p),
    ].join(' ').toLowerCase();
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

  List<dynamic> _applyFilters({required Position? userPos, required bool posReady}) {
    final q = _searchCtrl.text.trim();

    // Si nearMe est ON mais position pas prête -> liste vide (et on affichera un message "récupération...")
    if (_nearMeEnabled && !posReady) return [];

    var list = widget.items.where((p) {
      final okQuery = _matchesQuery(p, q);
      final okPrice = _matchesPrice(p);
      final okTop = !_onlyTopRated ? true : _ratingOf(p) >= 4.5;

      final okDistance = !_nearMeEnabled
          ? true
          : (userPos != null ? _matchesDistance(userPos, p) : false);

      return okQuery && okPrice && okTop && okDistance;
    }).toList();

    // Sort
    if (_sort == 'Note') {
      list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    } else if (_sort == 'Distance') {
      if (userPos != null) {
        list.sort((a, b) =>
            _distanceMetersBetween(userPos, a).compareTo(_distanceMetersBetween(userPos, b)));
      }
    } else if (_sort == 'Prix') {
      int weight(dynamic p) {
        final v = _normalizePrice(_priceRangeOf(p));
        if (RegExp(r'^\$+$').hasMatch(v)) return v.length;
        return 99;
      }
      list.sort((a, b) => weight(a).compareTo(weight(b)));
    } else {
      int score(dynamic p) {
        if (q.isEmpty) return 0;
        final name = _nameOf(p).toLowerCase();
        final desc = _descOf(p).toLowerCase();
        final qq = q.toLowerCase();
        int s = 0;
        if (name.contains(qq)) s += 3;
        if (desc.contains(qq)) s += 1;
        return s;
      }
      list.sort((a, b) => score(b).compareTo(score(a)));
    }

    return list;
  }

  List<_NearestDebugRow> _computeNearest(Position userPos) {
    final rows = <_NearestDebugRow>[];
    for (final p in widget.items) {
      final d = _distanceMetersBetween(userPos, p);
      if (d.isFinite) {
        rows.add(_NearestDebugRow(name: _nameOf(p), meters: d));
      }
    }
    rows.sort((a, b) => a.meters.compareTo(b.meters));
    return rows.take(5).toList();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return "${km.toStringAsFixed(2)} km";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final posAsync = ref.watch(userPositionProvider);

    final bool posReady = posAsync.maybeWhen(data: (_) => true, orElse: () => false);
    final Position? userPos = posAsync.maybeWhen(data: (p) => p, orElse: () => null);

    final filtered = _applyFilters(userPos: userPos, posReady: posReady);

    final bool showNearMeEmpty = _nearMeEnabled && posReady && filtered.isEmpty;
    final bool showNearMeLoading = _nearMeEnabled && posAsync.isLoading;
    final bool showNearMeError = _nearMeEnabled && posAsync.hasError;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          // =========================
          // SEARCH + FILTER BAR
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                // ✅ Debug: position visible
                if (_debugShowPosition)
                  posAsync.when(
                    data: (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "Position: ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)} (±${p.accuracy.toStringAsFixed(0)}m)",
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text("Position: récupération en cours..."),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "Position: erreur -> $e",
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),

                // ✅ Debug: 5 plus proches (preuve immédiate si vous êtes à Kin ou pas)
                if (_debugShowNearest && userPos != null)
                  Builder(
                    builder: (_) {
                      final nearest = _computeNearest(userPos!);
                      if (nearest.isEmpty) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light
                              ? Colors.blue.withOpacity(0.06)
                              : Colors.blue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Debug: 5 plus proches (distance réelle)"),
                            const SizedBox(height: 6),
                            ...nearest.map((r) => Text("• ${r.name} — ${_formatDistance(r.meters)}")),
                          ],
                        ),
                      );
                    },
                  ),

                // Search field
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: "Rechercher (nom, description, adresse...)",
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
                  ),
                ),
                const SizedBox(height: 10),

                // Row: tri + prix
                Row(
                  children: [
                    Expanded(
                      child: _boxed(
                        theme,
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sort,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Pertinence', child: Text('Trier: Pertinence')),
                              DropdownMenuItem(value: 'Note', child: Text('Trier: Note')),
                              DropdownMenuItem(value: 'Distance', child: Text('Trier: Distance')),
                              DropdownMenuItem(value: 'Prix', child: Text('Trier: Prix')),
                            ],
                            onChanged: (v) => setState(() => _sort = v ?? _sort),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _boxed(
                      theme,
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _priceFilter,
                          items: const [
                            DropdownMenuItem(value: 'Tous', child: Text('Prix: Tous')),
                            DropdownMenuItem(value: r'$', child: Text(r'Prix: $')),
                            DropdownMenuItem(value: r'$$', child: Text(r'Prix: $$')),
                            DropdownMenuItem(value: r'$$$', child: Text(r'Prix: $$$')),
                            DropdownMenuItem(value: r'$$$$', child: Text(r'Prix: $$$$')),
                          ],
                          onChanged: (v) => setState(() => _priceFilter = v ?? _priceFilter),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Top rated
                _boxed(
                  theme,
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Meilleures notes (≥ 4.5)",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: _onlyTopRated,
                        onChanged: (v) => setState(() => _onlyTopRated = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Near me
                _boxed(
                  theme,
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.near_me, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (loc.translate('near_you') == 'near_you') ? "Près de vous" : loc.translate('near_you'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch(
                            value: _nearMeEnabled,
                            onChanged: (v) => setState(() => _nearMeEnabled = v),
                          ),
                        ],
                      ),
                      if (_nearMeEnabled) ...[
                        const SizedBox(height: 8),
                        if (posAsync.isLoading)
                          Row(
                            children: const [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Expanded(child: Text("Récupération de votre localisation...")),
                            ],
                          )
                        else if (posAsync.hasError)
                          Row(
                            children: [
                              const Icon(Icons.location_off, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Localisation indisponible. Activez le GPS et la permission.",
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.tune, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.grey.shade100
                                        : Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _rangeIndex,
                                      isExpanded: true,
                                      items: List.generate(
                                        _ranges.length,
                                            (i) => DropdownMenuItem(value: i, child: Text(_ranges[i].label)),
                                      ),
                                      onChanged: (v) => setState(() => _rangeIndex = v ?? _rangeIndex),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Result count + Reset
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _sort = 'Pertinence';
                      _onlyTopRated = false;
                      _priceFilter = 'Tous';
                      _nearMeEnabled = true;
                      _rangeIndex = 1;
                    });
                  },
                  child: const Text("Réinitialiser"),
                ),
              ],
            ),
          ),

          // Messages UX
          if (showNearMeLoading)
            _infoBanner(theme, "Localisation en cours…"),
          if (showNearMeError)
            _errorBanner(theme, "Localisation indisponible. Activez GPS + permission."),
          if (showNearMeEmpty)
            _warnBanner(theme, "Aucun élément près de chez vous. Essayez un rayon plus grand."),

          // LIST
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _nearMeEnabled
                      ? (posAsync.isLoading
                      ? "Récupération de votre localisation..."
                      : posAsync.hasError
                      ? "Localisation indisponible.\nActivez le GPS et autorisez la permission."
                      : "Il n’y a aucun élément près de chez vous.\nEssayez un rayon plus grand.")
                      : "Aucun résultat.\nEssayez un autre mot-clé ou ajustez les filtres.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final place = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
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
      ),
    );
  }

  Widget _boxed(ThemeData theme, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  Widget _infoBanner(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(theme.brightness == Brightness.light ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.18)),
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _warnBanner(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(theme.brightness == Brightness.light ? 0.10 : 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.25)),
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _errorBanner(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(theme.brightness == Brightness.light ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.22)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ✅ Modèle interne simple pour les rayons
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

class _NearestDebugRow {
  final String name;
  final double meters;
  const _NearestDebugRow({required this.name, required this.meters});
}
