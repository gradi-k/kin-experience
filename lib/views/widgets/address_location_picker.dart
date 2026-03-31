// lib/widgets/address_location_picker.dart
// ✅ Widget simplifié : Recherche + Saisie manuelle + Mini carte

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
//import 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cityguide/services/geocoding_service.dart';

class AddressLocationPicker extends StatefulWidget {
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(String address, double latitude, double longitude) onLocationSelected;
  final String? hintText;

  const AddressLocationPicker({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
    this.hintText = 'Rechercher ou entrer une adresse...',
  });

  @override
  State<AddressLocationPicker> createState() => _AddressLocationPickerState();
}

class _AddressLocationPickerState extends State<AddressLocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeocodingService _geocodingService = GeocodingService();

  GoogleMapController? _mapController;
  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isGettingLocation = false;
  bool _showMap = false;
  Timer? _debounce;

  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;
  LatLng? _markerPosition;

  static const LatLng _kinshasaCenter = LatLng(-4.3276, 15.3136);

  @override
  void initState() {
    super.initState();

    if (widget.initialAddress != null) {
      _manualController.text = widget.initialAddress!;
      _selectedAddress = widget.initialAddress;
    }

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLatitude = widget.initialLatitude;
      _selectedLongitude = widget.initialLongitude;
      _markerPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _showMap = true;
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      _searchAddresses(_searchController.text.trim());
    });
  }

  Future<void> _searchAddresses(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await _geocodingService.searchAddresses(query);  // ✅ Corrigé
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    setState(() {
      _searchController.clear();
      _manualController.text = suggestion.shortAddress;
      _selectedAddress = suggestion.displayName;
      _selectedLatitude = suggestion.latitude;
      _selectedLongitude = suggestion.longitude;
      _markerPosition = LatLng(suggestion.latitude, suggestion.longitude);
      _suggestions = [];
      _showMap = true;
    });

    _searchFocusNode.unfocus();
    _animateToPosition(_selectedLatitude!, _selectedLongitude!);

    widget.onLocationSelected(
      _selectedAddress!,
      _selectedLatitude!,
      _selectedLongitude!,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final position = await _geocodingService.getCurrentPosition();

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'obtenir votre position'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final address = await _geocodingService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _manualController.text = address ?? 'Ma position actuelle';
          _selectedAddress = address ?? '';
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          _markerPosition = LatLng(position.latitude, position.longitude);
          _suggestions = [];
          _showMap = true;
        });

        _animateToPosition(position.latitude, position.longitude);

        widget.onLocationSelected(_selectedAddress!, _selectedLatitude!, _selectedLongitude!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position récupérée !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _geocodeManualAddress() async {
    final address = _manualController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final result = await _geocodingService.geocodeAddress(address);

      if (result != null && mounted) {
        setState(() {
          _selectedAddress = result.displayName;
          _selectedLatitude = result.latitude;
          _selectedLongitude = result.longitude;
          _markerPosition = LatLng(result.latitude, result.longitude);
          _showMap = true;
          _isSearching = false;
        });

        _animateToPosition(result.latitude, result.longitude);
        widget.onLocationSelected(_selectedAddress!, _selectedLatitude!, _selectedLongitude!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adresse localisée !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse introuvable'), backgroundColor: Colors.orange),
        );
        setState(() => _isSearching = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSearching = false);
      }
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _markerPosition = position;
      _selectedLatitude = position.latitude;
      _selectedLongitude = position.longitude;
    });

    _reverseGeocodePosition(position.latitude, position.longitude);
  }

  Future<void> _reverseGeocodePosition(double lat, double lng) async {
    try {
      final address = await _geocodingService.reverseGeocode(lat, lng);

      if (mounted && address != null) {
        setState(() {
          _selectedAddress = address;
          _manualController.text = address;
        });

        widget.onLocationSelected(_selectedAddress!, _selectedLatitude!, _selectedLongitude!);
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
  }

  void _animateToPosition(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recherche rapide
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: 'Recherche rapide',
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _suggestions = []);
              },
            )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // Suggestions
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(suggestion.shortAddress, style: const TextStyle(fontSize: 14)),
                  subtitle: suggestion.displayName != suggestion.shortAddress
                      ? Text(
                    suggestion.displayName,
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Bouton Ma position
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGettingLocation ? null : _useCurrentLocation,
            icon: _isGettingLocation
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.my_location),
            label: Text(_isGettingLocation ? 'Localisation...' : '📍 Utiliser ma position'),
          ),
        ),

        const SizedBox(height: 16),

        // Saisie manuelle
        TextField(
          controller: _manualController,
          decoration: InputDecoration(
            labelText: 'Ou entrer manuellement',
            hintText: 'Ex: Avenue de la Gombe, Kinshasa',
            prefixIcon: const Icon(Icons.edit_location_alt),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _geocodeManualAddress,
              tooltip: 'Localiser',
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _geocodeManualAddress(),
        ),

        const SizedBox(height: 12),

        // Toggle carte
        OutlinedButton.icon(
          onPressed: () => setState(() => _showMap = !_showMap),
          icon: Icon(_showMap ? Icons.map_outlined : Icons.map),
          label: Text(_showMap ? 'Masquer la carte' : '🗺️ Choisir sur la carte'),
        ),

        const SizedBox(height: 12),

        // Mini carte
        if (_showMap)
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _markerPosition ?? _kinshasaCenter,
                    zoom: 13,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _onMapTap,
                  markers: _markerPosition != null
                      ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _markerPosition!,
                      draggable: true,
                      onDragEnd: _onMapTap,
                      infoWindow: InfoWindow(
                        title: 'Position sélectionnée',
                        snippet: _selectedAddress ?? 'Déplaçable',
                      ),
                    ),
                  }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tapez ou glissez le marqueur',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Coordonnées
        if (_selectedLatitude != null && _selectedLongitude != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Position sélectionnée',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lat: ${_selectedLatitude!.toStringAsFixed(6)} | Lng: ${_selectedLongitude!.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (_selectedAddress != null && _selectedAddress!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress!,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}