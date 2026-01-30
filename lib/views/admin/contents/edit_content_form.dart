import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

import 'package:kin_experience/models/place_enums.dart';

class EditContentScreen extends StatefulWidget {
  final String docId;
  final PlaceCategory category;
  final String collectionName;
  final Map<String, dynamic> initialData;

  const EditContentScreen({
    super.key,
    required this.docId,
    required this.category,
    required this.collectionName,
    required this.initialData,
  });

  @override
  State<EditContentScreen> createState() => _EditContentScreenState();
}

class _EditContentScreenState extends State<EditContentScreen> {
  static const Color _green = Color(0xFF0B7A4A);

  // -------------------------
  // Dropdown safety helpers
  // -------------------------
  static const List<String> _priceOptions = ['\$', '\$\$', '\$\$\$', '\$\$\$\$'];

  String _norm(String? v) => (v ?? '').trim();

  String? _safeDropdownValue(String? current, List<String> options) {
    final v = _norm(current);
    if (v.isEmpty) return null;
    return options.contains(v) ? v : null;
  }

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;
  late final TextEditingController _scheduleController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  late double _rating;
  late String _prixRange;
  late bool _isFeatured;
  late bool _isDraft;
  bool _isLoading = false;

  final List<File> _newImages = [];
  late List<String> _existingImageUrls;

  @override
  void initState() {
    super.initState();

    _nomController = TextEditingController(text: widget.initialData['nom'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['description'] ?? '');
    _addressController = TextEditingController(text: widget.initialData['address'] ?? '');
    _phoneController = TextEditingController(text: widget.initialData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.initialData['email'] ?? '');
    _websiteController = TextEditingController(text: widget.initialData['website'] ?? '');
    _facebookController = TextEditingController(text: widget.initialData['facebookUrl'] ?? '');
    _instagramController = TextEditingController(text: widget.initialData['instagramUrl'] ?? '');
    _tiktokController = TextEditingController(text: widget.initialData['tiktokUrl'] ?? '');
    _scheduleController = TextEditingController(text: widget.initialData['schedule'] ?? '');

    _latitudeController = TextEditingController(
      text: (widget.initialData['latitude'] ?? 0.0).toString(),
    );
    _longitudeController = TextEditingController(
      text: (widget.initialData['longitude'] ?? 0.0).toString(),
    );

    _rating = (widget.initialData['rating'] as num?)?.toDouble() ?? 0.0;

    // ✅ NORMALISATION + FALLBACK (anti crash dropdown)
    _prixRange = widget.initialData['prixRange'] ?? '\$\$';
    _prixRange = _norm(_prixRange);
    if (!_priceOptions.contains(_prixRange)) _prixRange = _priceOptions[1];

    _isFeatured = widget.initialData['isFeatured'] ?? false;
    _isDraft = widget.initialData['isDraft'] ?? false;
    _existingImageUrls = (widget.initialData['photos'] as List?)?.cast<String>() ?? [];
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _scheduleController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() {
      _newImages.addAll(images.map((e) => File(e.path)));
    });
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() {
      _newImages.add(File(image.path));
    });
  }

  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final resized = img.copyResize(image, width: 1280);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  Future<String> _uploadImage(File file, int index) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('places/${widget.category.name}/${widget.docId}/photo_$index.jpg');

    final bytes = await _compressImage(file);

    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return snapshot.ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final photos = List<String>.from(_existingImageUrls);

      for (int i = 0; i < _newImages.length; i++) {
        final url = await _uploadImage(_newImages[i], photos.length + i);
        photos.add(url);
      }

      final lat = double.tryParse(_latitudeController.text.trim()) ?? 0.0;
      final lng = double.tryParse(_longitudeController.text.trim()) ?? 0.0;

      await FirebaseFirestore.instance.collection(widget.collectionName).doc(widget.docId).update({
        'nom': _nomController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'facebookUrl': _facebookController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'tiktokUrl': _tiktokController.text.trim(),
        'schedule': _scheduleController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'rating': _rating,
        'prixRange': _norm(_prixRange).isEmpty ? _priceOptions[1] : _norm(_prixRange),
        'isFeatured': _isFeatured,
        'isDraft': _isDraft,
        'photos': photos,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le contenu'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Note: ${_rating.toStringAsFixed(1)}'),
                          Slider(
                            value: _rating,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            onChanged: (v) => setState(() => _rating = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _safeDropdownValue(_prixRange, _priceOptions),
                        decoration: const InputDecoration(
                          labelText: 'Prix',
                          border: OutlineInputBorder(),
                        ),
                        items: _priceOptions
                            .map<DropdownMenuItem<String>>(
                              (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                            .toList(),
                        onChanged: (v) => setState(() => _prixRange = v ?? _priceOptions[1]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Site web',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _tiktokController,
                  decoration: const InputDecoration(
                    labelText: 'TikTok URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _scheduleController,
                  decoration: const InputDecoration(
                    labelText: 'Horaires',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galerie'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Caméra'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_existingImageUrls.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Photos existantes',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final url = _existingImageUrls[i];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 120,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _existingImageUrls.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_newImages.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nouvelles photos',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _newImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _newImages[i],
                            width: 120,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SwitchListTile(
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  title: const Text('Mis en avant'),
                ),
                SwitchListTile(
                  value: _isDraft,
                  onChanged: (v) => setState(() => _isDraft = v),
                  title: const Text('Brouillon'),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
