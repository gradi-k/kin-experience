import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cityguide/models/place_enums.dart';
import 'package:cityguide/views/widgets/address_location_picker.dart';
import 'package:cityguide/views/widgets/schedule_picker_field.dart';
import 'package:cityguide/views/widgets/menu_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cityguide/repositories/places_repository.dart';
import 'package:cityguide/services/content_service.dart';


class EditDraftForm extends StatefulWidget {
  final PlaceItem draft;
  final List<String> initialPhotos;

  const EditDraftForm({
    super.key,
    required this.draft,
    required this.initialPhotos,
  });

  @override
  State<EditDraftForm> createState() => _EditDraftFormState();
}

class _EditDraftFormState extends State<EditDraftForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _service = ContentService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;

  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _tiktokCtrl;

  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  late final TextEditingController _ratingCtrl;
  late String _prixRange;
  static const List<String> _priceOptions = ['5-150\$', '150-500\$', '500-1000\$', 'Plus de 1000\$'];
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _amenitiesCtrl;
  late final TextEditingController _scheduleCtrl;

  late PlaceCategory _category;
  bool _isFeatured = false;

  final List<File> _newImages = [];
  bool _replacePhotos = false;
  bool _saving = false;

  // Barre de progression
  double _uploadProgress = 0.0;
  String _uploadStep = '';

  // Menu
  String? _menuUrl;
  String? _menuType;
  final _menuPickerKey = GlobalKey<MenuPickerState>();

  @override
  void initState() {
    super.initState();

    final d = widget.draft;
    _category = PlaceCategoryX.fromKey(d.category);

    _nameCtrl = TextEditingController(text: d.nom);
    _descCtrl = TextEditingController(text: d.description);
    _addressCtrl = TextEditingController(text: d.address);

    _phoneCtrl = TextEditingController(text: d.meta['phone']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: d.meta['email']?.toString() ?? '');
    _websiteCtrl = TextEditingController(text: d.meta['website']?.toString() ?? '');
    _facebookCtrl = TextEditingController(text: d.meta['facebookUrl']?.toString() ?? '');
    _instagramCtrl = TextEditingController(text: d.meta['instagramUrl']?.toString() ?? '');
    _tiktokCtrl = TextEditingController(text: d.meta['tiktokUrl']?.toString() ?? '');

    _latCtrl = TextEditingController(text: d.location.latitude.toString());
    _lngCtrl = TextEditingController(text: d.location.longitude.toString());

    _ratingCtrl = TextEditingController(text: (d.meta['rating'] ?? 0).toString());
    final rawPrix = d.meta['prixRange']?.toString() ?? '5-150\$';
    _prixRange = _priceOptions.contains(rawPrix) ? rawPrix : _priceOptions[0];
    _keywordsCtrl = TextEditingController(text: d.meta['keywords']?.toString() ?? '');
    _amenitiesCtrl = TextEditingController(text: d.meta['amenities']?.toString() ?? '');
    _scheduleCtrl = TextEditingController(text: d.meta['schedule']?.toString() ?? '');

    _isFeatured = (d.meta['isFeatured'] == true);
    _menuUrl = d.meta['menuUrl'] as String?;
    _menuType = d.meta['menuType'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _ratingCtrl.dispose();
    _keywordsCtrl.dispose();
    _amenitiesCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() => _newImages.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() { _saving = true; _uploadStep = 'Préparation...'; _uploadProgress = 0.0; });
    try {
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      final geo = GeoPoint(lat ?? 0, lng ?? 0);

      if (mounted) setState(() { _uploadStep = 'Upload des photos...'; _uploadProgress = 0.1; });

      // Upload menu fichier si nouveau fichier sélectionné
      String? finalMenuUrl = _menuUrl;
      if (_menuType == 'file' && _menuPickerKey.currentState?.selectedFile != null) {
        if (mounted) setState(() { _uploadStep = 'Upload du menu...'; _uploadProgress = 0.7; });
        final file = _menuPickerKey.currentState!.selectedFile!;
        final ext = file.path.split('.').last;
        final ref = FirebaseStorage.instance
            .ref()
            .child('menus/${widget.draft.id}_menu.$ext');
        await ref.putFile(file);
        finalMenuUrl = await ref.getDownloadURL();
      }

      if (mounted) setState(() { _uploadStep = 'Enregistrement...'; _uploadProgress = 0.9; });

      final meta = <String, dynamic>{
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'facebookUrl': _facebookCtrl.text.trim().isEmpty ? null : _facebookCtrl.text.trim(),
        'instagramUrl': _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        'tiktokUrl': _tiktokCtrl.text.trim().isEmpty ? null : _tiktokCtrl.text.trim(),
        'rating': double.tryParse(_ratingCtrl.text.trim()) ?? 0,
        'prixRange': _prixRange,
        'isFeatured': _isFeatured,
        'keywords': _keywordsCtrl.text.trim(),
        'amenities': _amenitiesCtrl.text.trim(),
        'schedule': _scheduleCtrl.text.trim(),
        'menuUrl': finalMenuUrl,
        'menuType': _menuType,
      }..removeWhere((k, v) => v == null);

      final updated = PlaceItem(
        id: widget.draft.id,
        category: _category.key,
        nom: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        photos: widget.draft.photos,
        location: geo,
        meta: meta,
      );

      await _service.updateDraft(
        draftId: widget.draft.id,
        updated: updated,
        newImages: _newImages,
        replacePhotos: _replacePhotos,
      );

      if (mounted) setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() { _saving = false; _uploadProgress = 0.0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier brouillon')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<PlaceCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: PlaceCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), minLines: 2, maxLines: 5),
              const SizedBox(height: 12),
              AddressLocationPicker(
                initialAddress: _addressCtrl.text.isEmpty ? null : _addressCtrl.text,
                initialLatitude: double.tryParse(_latCtrl.text),
                initialLongitude: double.tryParse(_lngCtrl.text),
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _addressCtrl.text = address;
                    _latCtrl.text = lat.toString();
                    _lngCtrl.text = lng.toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Note: ${(double.tryParse(_ratingCtrl.text) ?? 0.0).toStringAsFixed(1)}'),
                        Slider(
                          value: (double.tryParse(_ratingCtrl.text) ?? 0.0).clamp(0.0, 5.0),
                          min: 0,
                          max: 5,
                          divisions: 10,
                          onChanged: (v) => setState(() => _ratingCtrl.text = v.toStringAsFixed(1)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _prixRange,
                      decoration: const InputDecoration(
                        labelText: 'Tranche de prix',
                        border: OutlineInputBorder(),
                      ),
                      items: _priceOptions
                          .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 14)),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _prixRange = v ?? _priceOptions[0]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
                title: const Text('Mis en avant'),
              ),
              CheckboxListTile(
                value: _replacePhotos,
                onChanged: (v) => setState(() => _replacePhotos = v ?? false),
                title: const Text('Remplacer les photos existantes par les nouvelles'),
              ),
              const SizedBox(height: 12),
              SchedulePickerField(
                controller: _scheduleCtrl,
              ),
              const SizedBox(height: 12),
              MenuPicker(
                key: _menuPickerKey,
                initialMenuUrl: _menuUrl,
                initialMenuType: _menuType,
                onMenuChanged: (url, type) => setState(() { _menuUrl = url; _menuType = type; }),
              ),
              const Divider(height: 32),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text('Ajouter des nouvelles photos (${_newImages.length})'),
              ),
              const SizedBox(height: 16),
              if (_saving) ...[
                _PublishProgressBar(
                  progress: _uploadProgress,
                  step: _uploadStep,
                  color: const Color(0xFF0B7A4A),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre de progression
// ─────────────────────────────────────────────────────────────────────────────

class _PublishProgressBar extends StatelessWidget {
  final double progress;
  final String step;
  final Color color;

  const _PublishProgressBar({required this.progress, required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                step.isEmpty ? 'En cours...' : step,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Text(
              '$pct %',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}