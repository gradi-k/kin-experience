// lib/views/widgets/address_field.dart
//
// Champ de formulaire compact : affiche l'adresse choisie et ouvre le
// sélecteur plein écran (AddressPickerScreen) au tap.

import 'package:flutter/material.dart';

import 'package:cityguide/views/widgets/address_picker_screen.dart';

class AddressField extends StatelessWidget {
  final String? address;
  final double? latitude;
  final double? longitude;
  final ValueChanged<AddressPickResult> onChanged;
  final String label;

  const AddressField({
    super.key,
    this.address,
    this.latitude,
    this.longitude,
    required this.onChanged,
    this.label = 'Adresse',
  });

  bool get _hasCoords =>
      latitude != null &&
      longitude != null &&
      (latitude != 0 || longitude != 0);

  Future<void> _openPicker(BuildContext context) async {
    final result = await Navigator.of(context).push<AddressPickResult>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialAddress: address,
          initialLatitude: latitude,
          initialLongitude: longitude,
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAddress = (address ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.map_outlined),
            ),
            child: Text(
              hasAddress ? address!.trim() : 'Choisir une adresse…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: hasAddress
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
            ),
          ),
        ),
        if (_hasCoords)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF0B7A4A), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Position GPS : ${latitude!.toStringAsFixed(5)}, '
                  '${longitude!.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
