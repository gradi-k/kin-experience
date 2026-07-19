// lib/views/widgets/address_picker_screen.dart
//
// Sélecteur d'adresse plein écran : recherche avec suggestions combinées
// (communes de Kinshasa, lieux en base, Nominatim), carte avec marqueur
// déplaçable, position actuelle, puis confirmation explicite.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cityguide/services/address_suggestions_service.dart';
import 'package:cityguide/services/geocoding_service.dart';

/// Résultat renvoyé par [AddressPickerScreen].
class AddressPickResult {
  final String address;
  final double latitude;
  final double longitude;

  const AddressPickResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class AddressPickerScreen extends StatefulWidget {
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  const AddressPickerScreen({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const LatLng _kinshasaCenter = LatLng(-4.3276, 15.3136);
  static const Color _green = Color(0xFF0B7A4A);

  final _searchController = TextEditingController();
  final _addressController = TextEditingController();
  final _suggestionsService = AddressSuggestionsService();
  final _geocodingService = GeocodingService();

  GoogleMapController? _mapController;
  Timer? _debounce;

  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isLocating = false;

  /// Vrai quand l'utilisateur a édité l'adresse à la main : le géocodage
  /// inverse ne l'écrase alors plus.
  bool _addressEdited = false;

  LatLng? _marker;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
      _addressEdited = true;
    }
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      _marker = LatLng(lat, lng);
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      setState(() => _isSearching = true);
      final results = await _suggestionsService.search(q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  void _selectSuggestion(AddressSuggestion s) {
    FocusScope.of(context).unfocus();
    _searchController.removeListener(_onSearchChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchChanged);
    setState(() {
      _suggestions = [];
      _addressEdited = false;
    });
    _addressController.text = s.displayName;
    _setMarker(LatLng(s.latitude, s.longitude), reverseGeocode: false);
  }

  Future<void> _setMarker(LatLng pos, {bool reverseGeocode = true}) async {
    setState(() {
      _marker = pos;
      if (reverseGeocode) _addressEdited = false;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));

    if (!reverseGeocode) return;
    final address =
        await _geocodingService.reverseGeocode(pos.latitude, pos.longitude);
    if (!mounted || _addressEdited) return;
    if (address != null && address.isNotEmpty) {
      _addressController.text = address;
    }
  }

  Future<void> _useCurrentPosition() async {
    setState(() => _isLocating = true);
    final position = await _geocodingService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position indisponible — vérifiez les autorisations'),
        ),
      );
      return;
    }
    _setMarker(LatLng(position.latitude, position.longitude));
  }

  void _confirm() {
    final marker = _marker;
    final address = _addressController.text.trim();
    if (marker == null || address.isEmpty) return;
    Navigator.of(context).pop(AddressPickResult(
      address: address,
      latitude: marker.latitude,
      longitude: marker.longitude,
    ));
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'zone':
        return Icons.location_city;
      case 'place':
        return Icons.storefront;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm =
        _marker != null && _addressController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir une adresse'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: Padding(
        // Au-dessus du panneau de confirmation.
        padding: const EdgeInsets.only(bottom: 170),
        child: FloatingActionButton(
          heroTag: 'address_picker_my_location',
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: _green,
          onPressed: _isLocating ? null : _useCurrentPosition,
          child: _isLocating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _marker ?? _kinshasaCenter,
              zoom: _marker != null ? 16 : 12,
            ),
            onMapCreated: (c) => _mapController = c,
            onTap: _setMarker,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              if (_marker != null)
                Marker(
                  markerId: const MarkerId('selected'),
                  position: _marker!,
                  draggable: true,
                  onDragEnd: _setMarker,
                ),
            },
          ),

          // Recherche + suggestions.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un lieu, une commune…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : (_searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _searchController.clear,
                                  )),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black26),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(_sourceIcon(s.source),
                                color: _green, size: 20),
                            title: Text(
                              s.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Panneau de confirmation.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 12, color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _addressController,
                    onChanged: (_) {
                      _addressEdited = true;
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      labelText: 'Adresse affichée',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _marker == null
                        ? 'Touchez la carte ou cherchez un lieu'
                        : 'Position GPS : '
                            '${_marker!.latitude.toStringAsFixed(5)}, '
                            '${_marker!.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: canConfirm ? _confirm : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmer cette adresse'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
