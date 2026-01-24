import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import '../models/place_enums.dart';

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

    // Initialiser les contrôleurs avec les données existantes
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
    _prixRange = widget.initialData['prixRange'] ?? '\$';
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

    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _newImages.add(File(image.path));
      });
    }
  }

  Future<List<String>> _uploadNewImages() async {
    final List<String> urls = [];

    for (int i = 0; i < _newImages.length; i++) {
      final file = _newImages[i];

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        final resized = image.width > 1920
            ? img.copyResize(image, width: 1920)
            : image;

        final jpgBytes = img.encodeJpg(resized, quality: 85);
        final uint8bytes = Uint8List.fromList(jpgBytes);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${widget.category.key}_${timestamp}_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('${widget.category.key}/$fileName');

        await ref.putData(uint8bytes);
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    }

    return urls;
  }

  Future<void> _updateContent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload nouvelles images
      final newImageUrls = await _uploadNewImages();

      // Combiner avec les images existantes
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      // Préparer les données
      final data = {
        'nom': _nomController.text.trim(),
        'description': _descriptionController.text.trim(),
        'rating': _rating,
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        'photos': allImageUrls,
        'prixRange': _prixRange,
        'isFeatured': _isFeatured,
        'isDraft': _isDraft,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'website': _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        'facebookUrl': _facebookController.text.trim().isEmpty
            ? null
            : _facebookController.text.trim(),
        'instagramUrl': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'tiktokUrl': _tiktokController.text.trim().isEmpty
            ? null
            : _tiktokController.text.trim(),
        'schedule': _scheduleController.text.trim().isEmpty
            ? null
            : _scheduleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Mettre à jour dans Firestore
      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.docId)
          .update(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contenu mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images
            _buildImageSection(),
            const SizedBox(height: 20),

            // Nom
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'Le nom est requis'
                  : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) => v == null || v.isEmpty
                  ? 'La description est requise'
                  : null,
            ),
            const SizedBox(height: 16),

            // Coordonnées GPS
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Requis'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Requis'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rating et Prix
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
                    value: _prixRange,
                    decoration: const InputDecoration(
                      labelText: 'Prix',
                      border: OutlineInputBorder(),
                    ),
                    items: ['\$', '\$\$', '\$\$\$', '\$\$\$\$']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _prixRange = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Adresse
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Contact
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
                prefixIcon: Icon(Icons.email),
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
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Réseaux sociaux
            TextFormField(
              controller: _facebookController,
              decoration: const InputDecoration(
                labelText: 'Facebook',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.facebook),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(
                labelText: 'Instagram',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.camera_alt),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _tiktokController,
              decoration: const InputDecoration(
                labelText: 'TikTok',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.video_library),
              ),
            ),
            const SizedBox(height: 16),

            // Horaires
            TextFormField(
              controller: _scheduleController,
              decoration: const InputDecoration(
                labelText: 'Horaires',
                border: OutlineInputBorder(),
                hintText: 'Lun-Ven: 9h-18h',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Switches
            SwitchListTile(
              title: const Text('Contenu Featured'),
              subtitle: const Text('Apparaît en priorité'),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
            ),

            SwitchListTile(
              title: const Text('Brouillon'),
              subtitle: const Text('Non publié'),
              value: _isDraft,
              onChanged: (v) => setState(() => _isDraft = v),
            ),

            const SizedBox(height: 24),

            // Bouton de sauvegarde
            ElevatedButton.icon(
              onPressed: _updateContent,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer les modifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Images existantes
        if (_existingImageUrls.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Images existantes:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(_existingImageUrls[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _existingImageUrls.removeAt(index);
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
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
          ),

        // Nouvelles images
        if (_newImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nouvelles images:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_newImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _newImages.removeAt(index);
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
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
          ),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Ajouter de la galerie'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Prendre une photo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}