
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kin_experience/models/place_enums.dart';
import 'package:kin_experience/repositories/places_repository.dart';
import 'package:kin_experience/services/content_service.dart';


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
  late final TextEditingController _prixRangeCtrl;
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _amenitiesCtrl;
  late final TextEditingController _scheduleCtrl;

  late PlaceCategory _category;
  bool _isFeatured = false;

  final List<File> _newImages = [];
  bool _replacePhotos = false;
  bool _saving = false;

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
    _prixRangeCtrl = TextEditingController(text: d.meta['prixRange']?.toString() ?? '€€');
    _keywordsCtrl = TextEditingController(text: d.meta['keywords']?.toString() ?? '');
    _amenitiesCtrl = TextEditingController(text: d.meta['amenities']?.toString() ?? '');
    _scheduleCtrl = TextEditingController(text: d.meta['schedule']?.toString() ?? '');

    _isFeatured = (d.meta['isFeatured'] == true);
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
    _prixRangeCtrl.dispose();
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

    setState(() => _saving = true);
    try {
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      final geo = GeoPoint(lat ?? 0, lng ?? 0);

      final meta = <String, dynamic>{
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'facebookUrl': _facebookCtrl.text.trim().isEmpty ? null : _facebookCtrl.text.trim(),
        'instagramUrl': _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
        'tiktokUrl': _tiktokCtrl.text.trim().isEmpty ? null : _tiktokCtrl.text.trim(),
        'rating': double.tryParse(_ratingCtrl.text.trim()) ?? 0,
        'prixRange': _prixRangeCtrl.text.trim(),
        'isFeatured': _isFeatured,
        'keywords': _keywordsCtrl.text.trim(),
        'amenities': _amenitiesCtrl.text.trim(),
        'schedule': _scheduleCtrl.text.trim(),
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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
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
              TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _latCtrl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _lngCtrl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number)),
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
              const Divider(height: 32),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text('Ajouter des nouvelles photos (${_newImages.length})'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
