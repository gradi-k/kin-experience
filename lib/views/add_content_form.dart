import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import '../models/place_enums.dart';

class AddContentForm extends StatefulWidget {
  final PlaceCategory category;

  const AddContentForm({super.key, required this.category});

  @override
  State<AddContentForm> createState() => _AddContentFormState();
}

class _AddContentFormState extends State<AddContentForm> {
  static const Color _green = Color(0xFF0B7A4A);

  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  double _rating = 0.0;
  String _prixRange = '\$';
  bool _isFeatured = false;
  bool _isDraft = false;
  bool _isLoading = false;

  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final List<String> _amenities = [];
  final List<String> _communities = [];

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

  String get collectionName {
    switch (widget.category) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.resto:
        return 'restaurants';
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'business';
      case PlaceCategory.shopping:
        return 'shopping';
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  Future<List<String>> _uploadImagesToFirebase() async {
    final List<String> urls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      final file = _selectedImages[i];

      // Lire l'image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        // Redimensionner si nécessaire (max 1920px de largeur)
        final resized = image.width > 1920
            ? img.copyResize(image, width: 1920)
            : image;

        // Convertir en JPEG avec compression
        final jpgBytes = img.encodeJpg(resized, quality: 85);
        final uint8bytes = Uint8List.fromList(jpgBytes);

        // Upload vers Firebase Storage
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

  Future<void> _saveContent({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isDraft = isDraft;
    });

    try {
      // Upload images
      final imageUrls = await _uploadImagesToFirebase();

      // Préparer les données
      final data = {
        'nom': _nomController.text.trim(),
        'description': _descriptionController.text.trim(),
        'rating': _rating,
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        'photos': imageUrls,
        'prixRange': _prixRange,
        'isFeatured': _isFeatured,
        'isDraft': isDraft,
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
        'amenities': _amenities,
        'schedule': _scheduleController.text.trim().isEmpty
            ? null
            : _scheduleController.text.trim(),
        'reviewCount': 0,
        'distanceKm': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Ajouter communities pour entreprise
      if (widget.category == PlaceCategory.entreprise) {
        data['communities'] = _communities;
      }

      // Ajouter avis pour resto
      if (widget.category == PlaceCategory.resto) {
        data['avis'] = [];
      }

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection(collectionName)
          .add(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDraft
                ? 'Brouillon enregistré avec succès'
                : 'Contenu publié avec succès'),
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
        title: Text('Ajouter ${widget.category.label}'),
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

            const SizedBox(height: 24),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveContent(isDraft: true),
                    icon: const Icon(Icons.save),
                    label: const Text('Brouillon'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveContent(isDraft: false),
                    icon: const Icon(Icons.publish),
                    label: const Text('Publier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
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

        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
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
                            _selectedImages.removeAt(index);
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

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Caméra'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}