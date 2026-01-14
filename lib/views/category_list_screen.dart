import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../models/place_enums.dart';
import '../views/widgets/place_card.dart';
import 'detail_screen.dart';

/// Écran affichant la liste complète des lieux d’une catégorie.
/// Ajout: Search + Filters (basé sur les données fakeData dans `items`)
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
  bool _onlyTopRated = false; // filtre simple
  String _priceFilter = 'Tous'; // Tous | $ | $$ | $$$ | $$$$

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

  double _distanceKmOf(dynamic p) =>
      _tryGet<double>(p, () => (p.distanceKm as double)) ??
          _tryGet<num>(p, () => (p.distanceKm as num))?.toDouble() ??
          0.0;

  String _priceRangeOf(dynamic p) =>
      _tryGet(p, () => p.prixRange.toString())?.trim() ??
          _tryGet(p, () => p.priceRange.toString())?.trim() ??
          '';

  // Normalise la plage de prix en "$", "$$", "$$$", "$$$$" si possible
  String _normalizePrice(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    // Si déjà $...$
    if (RegExp(r'^\$+$').hasMatch(v)) return v;

    // Cas: "1", "2", "3", "4" => "$", "$$", ...
    final n = int.tryParse(v);
    if (n != null && n >= 1 && n <= 4) return r'$' * n;

    // Cas: "low/medium/high" ou autres => laisse tel quel
    // (tu peux adapter selon ton fake_data)
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
    final raw = _priceRangeOf(p);
    final normalized = _normalizePrice(raw);

    // Si ton fake_data stocke déjà "$$" etc, ok.
    // Sinon si stocke texte, ça ne filtrera pas (et restera un filtre optionnel).
    return normalized == _priceFilter;
  }

  List<dynamic> _applyFilters() {
    final q = _searchCtrl.text.trim();

    // 1) Filter
    var list = widget.items.where((p) {
      final okQuery = _matchesQuery(p, q);
      final okPrice = _matchesPrice(p);
      final okTop = !_onlyTopRated ? true : _ratingOf(p) >= 4.5;
      return okQuery && okPrice && okTop;
    }).toList();

    // 2) Sort
    if (_sort == 'Note') {
      list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    } else if (_sort == 'Distance') {
      list.sort((a, b) => _distanceKmOf(a).compareTo(_distanceKmOf(b)));
    } else if (_sort == 'Prix') {
      // "$" < "$$" < "$$$" < "$$$$" (si normalisable)
      int weight(dynamic p) {
        final v = _normalizePrice(_priceRangeOf(p));
        if (RegExp(r'^\$+$').hasMatch(v)) return v.length;
        return 99; // inconnus à la fin
      }

      list.sort((a, b) => weight(a).compareTo(weight(b)));
    } else {
      // Pertinence: simple heuristique => nom match d'abord, puis description
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final filtered = _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // =========================
          // SEARCH + FILTER BAR
          // =========================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
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

                // Filters row
                Row(
                  children: [
                    // Sort dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.25),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sort,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Pertinence',
                                child: Text('Trier: Pertinence'),
                              ),
                              DropdownMenuItem(
                                value: 'Note',
                                child: Text('Trier: Note'),
                              ),
                              DropdownMenuItem(
                                value: 'Distance',
                                child: Text('Trier: Distance'),
                              ),
                              DropdownMenuItem(
                                value: 'Prix',
                                child: Text('Trier: Prix'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _sort = v);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Price filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.25),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _priceFilter,
                          items: const [
                            DropdownMenuItem(
                              value: 'Tous',
                              child: Text('Prix: Tous'),
                            ),
                            DropdownMenuItem(
                              value: r'$',
                              child: Text(r'Prix: $'),
                            ),
                            DropdownMenuItem(
                              value: r'$$',
                              child: Text(r'Prix: $$'),
                            ),
                            DropdownMenuItem(
                              value: r'$$$',
                              child: Text(r'Prix: $$$'),
                            ),
                            DropdownMenuItem(
                              value: r'$$$$',
                              child: Text(r'Prix: $$$$'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _priceFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Top rated toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
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
                              onChanged: (v) =>
                                  setState(() => _onlyTopRated = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Result count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  "${filtered.length} résultat(s)",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                    theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_searchCtrl.text.trim().isNotEmpty ||
                    _onlyTopRated ||
                    _priceFilter != 'Tous' ||
                    _sort != 'Pertinence')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchCtrl.clear();
                        _sort = 'Pertinence';
                        _onlyTopRated = false;
                        _priceFilter = 'Tous';
                      });
                    },
                    child: const Text("Réinitialiser"),
                  ),
              ],
            ),
          ),

          // =========================
          // LIST
          // =========================
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Aucun résultat.\nEssayez un autre mot-clé ou ajustez les filtres.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withOpacity(0.75),
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
}
