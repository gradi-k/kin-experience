import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kin_experience/controllers/location_controller.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';
import '../views/widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran affichant la liste complète des lieux d’une catégorie.
/// Search + Filters + ✅ Filtre "près de vous" par rayon (1–100m, 100m–5km, 5–10km)
/// ✅ UI compacte: barre de recherche + icône filtre (ouvre un bottom sheet)
/// ✅ Pertinence supprimée (tri par Note / Distance / Prix uniquement)
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

  // ✅ Pertinence supprimée
  String _sort = 'Distance'; // Note | Distance | Prix
  bool _onlyTopRated = false;
  String _priceFilter = 'Tous';

  // ✅ Filtre distance
  bool _nearMeEnabled = false;

  // ✅ Rayons demandés
  final List<_DistanceRange> _ranges = const [
    _DistanceRange(label: 'Près (1–100 m)', minMeters: 1, maxMeters: 100),
    _DistanceRange(label: 'Autour (100 m–5 km)', minMeters: 100, maxMeters: 5000),
    _DistanceRange(label: 'Large (5–10 km)', minMeters: 5000, maxMeters: 10000),
  ];
  int _rangeIndex = 1; // défaut: 100m–5km

  // ✅ Debug optionnel (désactivé)
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

  // ---------------------------
  // Normalisation Prix => "$".."$$$$"
  // ---------------------------
  String _normalizePrice(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';

    // 1) Déjà "$$$"
    if (RegExp(r'^\$+$').hasMatch(v)) return v;

    // 2) "1".."4"
    final n = int.tryParse(v);
    if (n != null && n >= 1 && n <= 4) return r'$' * n;

    // 3) "60-100" / "60 – 100" / "60 à 100" / "60"
    // On récupère le premier nombre trouvé
    final firstNumMatch = RegExp(r'(\d+)').firstMatch(v);
    if (firstNumMatch != null) {
      final price = int.tryParse(firstNumMatch.group(1)!) ?? 0;

      // Tranches (ajuste si besoin)
      if (price < 50) return r'$';
      if (price < 150) return r'$$';
      if (price < 350) return r'$$$';
      return r'$$$$';
    }

    // fallback
    return v;
  }

  // ---------------------------
  // Query / Filters
  // ---------------------------
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

  // ---------------------------
  // Apply + Sort (sans Pertinence)
  // ---------------------------
  List<dynamic> _applyFilters({
    required Position? userPos,
    required bool posReady,
  }) {
    final q = _searchCtrl.text.trim();

    // Si nearMe est ON mais position pas prête -> liste vide (UI affiche "localisation en cours…")
    if (_nearMeEnabled && !posReady) return [];

    // Cache distance pour éviter recalculs pendant sort
    final distCache = <dynamic, double>{};
    double distOf(dynamic p) {
      return distCache.putIfAbsent(
        p,
            () => (userPos == null ? double.infinity : _distanceMetersBetween(userPos, p)),
      );
    }

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
      // Si pas de position, on ne trie pas par distance
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
    } else {
      // Sécurité si valeur inconnue
      _sort = 'Distance';
    }

    return list;
  }

  // Debug: 5 plus proches
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

  // ---------------------------
  // UI Helpers
  // ---------------------------
  Widget _miniBanner(ThemeData theme, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(theme.brightness == Brightness.light ? 0.10 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet({
    required ThemeData theme,
    required AppLocalizations loc,
    required AsyncValue<Position> posAsync,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bool posReady = posAsync.maybeWhen(data: (_) => true, orElse: () => false);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ligne 1: Trier
                  Row(
                    children: [
                      const Icon(Icons.sort, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text("Trier par")),
                      DropdownButton<String>(
                        value: _sort,
                        items: const [
                          DropdownMenuItem(value: 'Distance', child: Text('Distance')),
                          DropdownMenuItem(value: 'Note', child: Text('Note')),
                          DropdownMenuItem(value: 'Prix', child: Text('Prix')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => _sort = v);
                          setState(() => _sort = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Ligne 2: Prix
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text("Prix")),
                      DropdownButton<String>(
                        value: _priceFilter,
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(value: r'$', child: Text(r'$')),
                          DropdownMenuItem(value: r'$$', child: Text(r'$$')),
                          DropdownMenuItem(value: r'$$$', child: Text(r'$$$')),
                          DropdownMenuItem(value: r'$$$$', child: Text(r'$$$$')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => _priceFilter = v);
                          setState(() => _priceFilter = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Ligne 3: meilleures notes
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text("Meilleures notes (≥ 4.5)")),
                      Switch(
                        value: _onlyTopRated,
                        onChanged: (v) {
                          setLocal(() => _onlyTopRated = v);
                          setState(() => _onlyTopRated = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Ligne 4: près de vous + rayon
                  Row(
                    children: [
                      const Icon(Icons.near_me, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (loc.translate('near_you') == 'near_you')
                              ? "Près de vous"
                              : loc.translate('near_you'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: _nearMeEnabled,
                        onChanged: (v) {
                          setLocal(() => _nearMeEnabled = v);
                          setState(() => _nearMeEnabled = v);
                        },
                      ),
                    ],
                  ),

                  if (_nearMeEnabled) ...[
                    const SizedBox(height: 6),
                    if (posAsync.isLoading)
                      Row(
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text("Récupération de votre localisation...")),
                        ],
                      )
                    else if (posAsync.hasError)
                      Row(
                        children: [
                          const Icon(Icons.location_off, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Localisation indisponible. Activez le GPS et la permission.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (posReady)
                        Row(
                          children: [
                            const Icon(Icons.tune, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(child: Text("Rayon")),
                            DropdownButton<int>(
                              value: _rangeIndex,
                              items: List.generate(
                                _ranges.length,
                                    (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(_ranges[i].label),
                                ),
                              ),
                              onChanged: (v) {
                                if (v == null) return;
                                setLocal(() => _rangeIndex = v);
                                setState(() => _rangeIndex = v);
                              },
                            ),
                          ],
                        ),
                  ],

                  const SizedBox(height: 10),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setLocal(() {
                              _searchCtrl.clear();
                              _sort = 'Distance';
                              _onlyTopRated = false;
                              _priceFilter = 'Tous';
                              _nearMeEnabled = true;
                              _rangeIndex = 1;
                            });
                            setState(() {
                              _searchCtrl.clear();
                              _sort = 'Distance';
                              _onlyTopRated = false;
                              _priceFilter = 'Tous';
                              _nearMeEnabled = true;
                              _rangeIndex = 1;
                            });
                          },
                          child: const Text("Réinitialiser"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Appliquer"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          // BARRE RECHERCHE COMPACTE + ICONE FILTRE
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44, // ✅ compact
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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

          // =========================
          // DEBUG (optionnel)
          // =========================
          if (_debugShowPosition)
            posAsync.when(
              data: (p) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  "Position: ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)} (±${p.accuracy.toStringAsFixed(0)}m)",
                  style: theme.textTheme.bodySmall,
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text("Position: récupération en cours..."),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  "Position: erreur -> $e",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          if (_debugShowNearest && userPos != null)
            Builder(
              builder: (_) {
                final nearest = _computeNearest(userPos);
                if (nearest.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Container(
                    width: double.infinity,
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
                        ...nearest.map(
                              (r) => Text("• ${r.name} — ${_formatDistance(r.meters)}"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // =========================
          // LIGNE RESULTATS (compact)
          // =========================
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _sort = 'Distance';
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

          // =========================
          // BANNIÈRES UX (compact)
          // =========================
          if (showNearMeLoading)
            _miniBanner(theme, "Localisation en cours…", Colors.blue),
          if (showNearMeError)
            _miniBanner(theme, "Localisation indisponible. Activez GPS + permission.", Colors.red),
          if (showNearMeEmpty)
            _miniBanner(theme, "Aucun élément près de chez vous. Essayez un rayon plus grand.", Colors.orange),

          // =========================
          // LIST
          // =========================
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
