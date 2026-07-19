// lib/views/map/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/categories_controller.dart';
import '../../controllers/location_controller.dart';
import '../../controllers/places_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/category_config.dart';
import '../../models/place.dart';
import '../detail_screen.dart';
import '../widgets/app_network_image.dart';

/// Carte interactive « Autour de moi » : tous les lieux géolocalisés,
/// marqueurs colorés par catégorie, filtre par chips, aperçu en bottom sheet.
class MapScreen extends ConsumerStatefulWidget {
  /// Clé de catégorie pré-sélectionnée dans les filtres.
  final String? initialCategory;

  const MapScreen({super.key, this.initialCategory});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const LatLng _kinshasaCenter = LatLng(-4.3276, 15.3136);

  GoogleMapController? _mapController;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _categoryFilter = widget.initialCategory;
  }

  String _nameOf(Place p) => p.nom.trim().isEmpty ? 'Sans nom' : p.nom.trim();

  String _photoOf(Place p) => p.photos.isEmpty ? '' : p.photos.first;

  Set<Marker> _buildMarkers(
    List<Place> places,
    List<CategoryConfig> categories,
    Position? userPos,
  ) {
    final byKey = {for (final c in categories) c.key: c};
    final markers = <Marker>{};

    for (final place in places) {
      if (_categoryFilter != null && place.categoryKey != _categoryFilter) {
        continue;
      }

      // Un lieu dont la catégorie est désactivée ou inconnue n'apparaît pas :
      // il ne serait ni filtrable ni identifiable.
      final category = byKey[place.categoryKey];
      if (category == null) continue;

      if (!place.hasLocation) continue;

      markers.add(
        Marker(
          markerId: MarkerId('${place.categoryKey}_${place.id}'),
          position: LatLng(place.latitude, place.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(category.markerHue),
          onTap: () => _showPlacePreview(place, category, userPos),
        ),
      );
    }

    return markers;
  }

  void _showPlacePreview(
      Place place, CategoryConfig category, Position? userPos) {
    final theme = Theme.of(context);
    final name = _nameOf(place);
    final address = place.address ?? '';
    final photo = _photoOf(place);
    final rating = place.rating;

    String? distanceLabel;
    if (userPos != null && place.hasLocation) {
      final meters = Geolocator.distanceBetween(
          userPos.latitude, userPos.longitude, place.latitude, place.longitude);
      distanceLabel = meters < 1000
          ? '${meters.round()} m'
          : '${(meters / 1000).toStringAsFixed(1)} km';
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: AppNetworkImage(url: photo, memCacheWidth: 300),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.star,
                                  size: 16, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall),
                              if (distanceLabel != null) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.place_outlined, size: 16),
                                const SizedBox(width: 2),
                                Text(distanceLabel,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(place: place),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Voir les détails'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placesAsync = ref.watch(allPlacesProvider);
    final posAsync = ref.watch(userPositionProvider);
    final userPos = posAsync.whenOrNull(data: (p) => p);

    final initialTarget = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : _kinshasaCenter;

    final localeCode = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider).value ?? const [];

    final places = placesAsync.value ?? const <Place>[];
    final markers = _buildMarkers(places, categories, userPos);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('around_me') ??
              'Autour de moi',
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 13,
            ),
            markers: markers,
            myLocationEnabled: userPos != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // Chips de filtre par catégorie
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filterChip(theme, label: 'Tous', categoryKey: null),
                  ...categories.map(
                    (c) => _filterChip(
                      theme,
                      label: c.labelFor(localeCode),
                      categoryKey: c.key,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (placesAsync.isLoading)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: userPos != null
          ? FloatingActionButton(
              tooltip: 'Ma position',
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(userPos.latitude, userPos.longitude),
                    15,
                  ),
                );
              },
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _filterChip(ThemeData theme,
      {required String label, required String? categoryKey}) {
    final selected = _categoryFilter == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: theme.cardColor,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _categoryFilter = selected ? null : categoryKey;
          });
        },
      ),
    );
  }
}
