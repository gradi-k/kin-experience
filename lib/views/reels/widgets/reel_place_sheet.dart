// lib/views/reels/widgets/reel_place_sheet.dart
//
// Panneau (bottom sheet) affiché au tap sur le lieu d'un reel : description,
// photos, mini-carte et itinéraire vers le lieu lié.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cityguide/controllers/places_controller.dart';
import 'package:cityguide/models/place.dart';
import 'package:cityguide/views/detail_screen.dart';
import 'package:cityguide/views/widgets/app_network_image.dart';

const _green = Color(0xFF0B7A4A);

class ReelPlaceSheet extends ConsumerWidget {
  final String placeId;
  final String? fallbackName;
  final ScrollController? scrollController;

  const ReelPlaceSheet({
    super.key,
    required this.placeId,
    this.fallbackName,
    this.scrollController,
  });

  /// Ouvre le panneau en bottom sheet glissable.
  static Future<void> show(
    BuildContext context, {
    required String placeId,
    String? fallbackName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ReelPlaceSheet(
            placeId: placeId,
            fallbackName: fallbackName,
            scrollController: controller,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeAsync = ref.watch(reelPlaceProvider(placeId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Flexible(
          child: placeAsync.when(
            loading: () => _LoadingSkeleton(controller: scrollController),
            error: (_, __) => _Unavailable(fallbackName: fallbackName),
            data: (place) => place == null
                ? _Unavailable(fallbackName: fallbackName)
                : _PlaceContent(place: place, controller: scrollController),
          ),
        ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  final ScrollController? controller;
  const _LoadingSkeleton({this.controller});

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width}) => Container(
          height: height,
          width: width,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        block(24, width: 180),
        block(16),
        block(16),
        block(110),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  final String? fallbackName;
  const _Unavailable({this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text('Lieu indisponible', style: theme.textTheme.titleMedium),
          if (fallbackName != null && fallbackName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              fallbackName!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _PlaceContent extends StatefulWidget {
  final Place place;
  final ScrollController? controller;
  const _PlaceContent({required this.place, this.controller});

  @override
  State<_PlaceContent> createState() => _PlaceContentState();
}

class _PlaceContentState extends State<_PlaceContent> {
  bool _descriptionExpanded = false;

  Place get place => widget.place;

  Future<void> _openDirections() async {
    final uri = place.hasLocation
        ? Uri.parse('https://www.google.com/maps/dir/?api=1'
            '&destination=${place.latitude},${place.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1'
            '&query=${Uri.encodeComponent('${place.nom} Kinshasa')}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir l'itinéraire")),
        );
      }
    }
  }

  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                place.nom,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (place.categoryKey.isNotEmpty)
              Chip(
                label: Text(place.categoryKey),
                labelStyle: theme.textTheme.labelSmall,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        if (place.rating > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(place.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (place.reviewCount > 0) ...[
                  const SizedBox(width: 4),
                  Text('(${place.reviewCount} avis)',
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        if ((place.address ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place, size: 16, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child:
                      Text(place.address!, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        if (place.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            place.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            maxLines: _descriptionExpanded ? null : 4,
            overflow:
                _descriptionExpanded ? null : TextOverflow.ellipsis,
          ),
          if (!_descriptionExpanded && place.description.length > 160)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => setState(() => _descriptionExpanded = true),
                child: const Text('Voir plus'),
              ),
            ),
        ],
        if (place.photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: place.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 140,
                  height: 110,
                  child: AppNetworkImage(
                    url: place.photos[i],
                    memCacheWidth: 420,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (place.hasLocation) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(place.latitude, place.longitude),
                  zoom: 15,
                ),
                liteModeEnabled: true,
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationButtonEnabled: false,
                markers: {
                  Marker(
                    markerId: MarkerId(place.id),
                    position: LatLng(place.latitude, place.longitude),
                  ),
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _openDirections,
          icon: const Icon(Icons.directions),
          label: const Text("S'y rendre"),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _green,
          ),
          onPressed: _openDetail,
          child: const Text('Voir la fiche complète'),
        ),
      ],
    );
  }
}
