// lib/widgets/address_search_field.dart
import 'package:flutter/material.dart';
import 'package:kin_experience/services/geocoding_service.dart';
import 'dart:async';
/// Widget de recherche d'adresse avec autocomplétion
/// et bouton de géolocalisation
class AddressSearchField extends StatefulWidget {
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(String address, double latitude, double longitude) onLocationSelected;
  final String? labelText;
  final String? hintText;

  const AddressSearchField({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
    this.labelText = 'Adresse',
    this.hintText = 'Rechercher une adresse...',
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GeocodingService _geocodingService = GeocodingService();

  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isGettingLocation = false;
  Timer? _debounce;

  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void initState() {
    super.initState();

    if (widget.initialAddress != null) {
      _controller.text = widget.initialAddress!;
      _selectedAddress = widget.initialAddress;
    }

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLatitude = widget.initialLatitude;
      _selectedLongitude = widget.initialLongitude;
    }

    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_controller.text.trim().isEmpty) {
        setState(() {
          _suggestions = [];
        });
        return;
      }

      _searchAddresses(_controller.text.trim());
    });
  }

  Future<void> _searchAddresses(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _geocodingService.searchAddresses(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    setState(() {
      _controller.text = suggestion.shortAddress;
      _selectedAddress = suggestion.displayName;
      _selectedLatitude = suggestion.latitude;
      _selectedLongitude = suggestion.longitude;
      _suggestions = [];
    });

    _focusNode.unfocus();

    widget.onLocationSelected(
      _selectedAddress!,
      _selectedLatitude!,
      _selectedLongitude!,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

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

      // Géocode inverse pour obtenir l'adresse
      final address = await _geocodingService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _controller.text = address ?? 'Ma position actuelle';
          _selectedAddress = address ?? '';
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          _suggestions = [];
        });

        widget.onLocationSelected(
          _selectedAddress!,
          _selectedLatitude!,
          _selectedLongitude!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position récupérée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ de recherche
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
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
                : _controller.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _suggestions = [];
                  _selectedAddress = null;
                  _selectedLatitude = null;
                  _selectedLongitude = null;
                });
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Bouton "Ma position"
        OutlinedButton.icon(
          onPressed: _isGettingLocation ? null : _useCurrentLocation,
          icon: _isGettingLocation
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.my_location),
          label: Text(_isGettingLocation
              ? 'Localisation...'
              : 'Utiliser ma position'),
        ),

        const SizedBox(height: 8),

        // Suggestions
        if (_suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor,
              ),
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
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.dividerColor,
              ),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(
                    suggestion.shortAddress,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: suggestion.displayName != suggestion.shortAddress
                      ? Text(
                    suggestion.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),

        // Coordonnées sélectionnées (lecture seule)
        if (_selectedLatitude != null && _selectedLongitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📍 Coordonnées : ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}