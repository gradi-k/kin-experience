import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

import 'package:kin_experience/models/place_enums.dart';
import 'package:kin_experience/views/widgets/address_location_picker.dart';
import 'package:kin_experience/views/widgets/address_search_field.dart';


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
  String _prixRange = '5-150\$';
  bool _isFeatured = false;
  bool _isDraft = false;
  bool _isLoading = false;
  double _uploadProgress = 0.0;  // ✅ Ajouté : Progression de l'upload (0.0 à 1.0)

  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final List<String> _amenities = [];
  final List<String> _communities = [];
  // ✅ Catalogue d'équipements (label -> icon)
  static const Map<String, IconData> _amenitiesCatalog = {
    // Connexion & numérique
    'Wi-Fi': Icons.wifi,
    'Prises électriques': Icons.power,
    'Espace coworking': Icons.work_outline,
    'Salle de réunion': Icons.meeting_room_outlined,
    'Écran / Projecteur': Icons.tv_outlined,

    // Accès & stationnement
    'Parking': Icons.local_parking,
    'Parking sécurisé': Icons.local_parking_outlined,
    'Accès PMR': Icons.accessible_outlined,
    'Ascenseur': Icons.elevator_outlined,

    // Restauration
    'Petit-déjeuner': Icons.free_breakfast_outlined,
    'Restaurant': Icons.restaurant_outlined,
    'Bar / Lounge': Icons.local_bar_outlined,
    'Room service': Icons.room_service_outlined,
    'Terrasse': Icons.deck_outlined,

    // Bien-être & loisirs
    'Spa': Icons.spa_outlined,
    'Massage': Icons.spa,
    'Sauna': Icons.hot_tub_outlined,
    'Hammam': Icons.hot_tub,
    'Piscine': Icons.pool_outlined,
    'Salle de sport': Icons.fitness_center_outlined,
    'Jacuzzi': Icons.bathtub_outlined,

    // Confort & sécurité
    'Climatisation': Icons.ac_unit_outlined,
    'Générateur': Icons.electrical_services_outlined,
    'Sécurité 24h/24': Icons.security_outlined,
    'Caméras': Icons.videocam_outlined,

    // Famille
    'Espace enfants': Icons.child_friendly_outlined,
    'Aire de jeux': Icons.sports_esports_outlined,

    // Paiement
    'Paiement carte': Icons.credit_card_outlined,
    'Mobile Money': Icons.payments_outlined,

    // Animaux
    'Animaux acceptés': Icons.pets_outlined,
  };

  IconData _amenityIcon(String name) {
    // fallback si l'équipement vient d'un texte libre
    return _amenitiesCatalog[name] ?? Icons.check_circle_outline;
  }


  void _openAmenityPickerDialog() {
    final searchController = TextEditingController();
    final customController = TextEditingController();

    // sélection temporaire (on démarre avec ce qui est déjà choisi)
    final Set<String> tempSelected = {..._amenities};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final query = searchController.text.trim().toLowerCase();

            final all = _amenitiesCatalog.keys.toList();
            all.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            final filtered = query.isEmpty
                ? all
                : all.where((e) => e.toLowerCase().contains(query)).toList();

            return AlertDialog(
              title: const Text('Ajouter des équipements'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Champ recherche (liste)
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Ajout libre (comme avant)
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Ajouter un équipement personnalisé',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Rooftop, DJ, Voiturier...',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Liste avec icônes + multi-select
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey.shade50
                              : Colors.grey.shade900,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final name = filtered[index];
                              final checked = tempSelected.contains(name);

                              return CheckboxListTile(
                                value: checked,
                                onChanged: (v) {
                                  setLocalState(() {
                                    if (v == true) {
                                      tempSelected.add(name);
                                    } else {
                                      tempSelected.remove(name);
                                    }
                                  });
                                },
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(name),
                                secondary: Icon(_amenityIcon(name), color: _green),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    searchController.dispose();
                    customController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final custom = customController.text.trim();

                    setState(() {
                      // ✅ merge sélection
                      _amenities
                        ..clear()
                        ..addAll(tempSelected);

                      // ✅ ajout libre
                      if (custom.isNotEmpty && !_amenities.contains(custom)) {
                        _amenities.add(custom);
                      }
                    });

                    searchController.dispose();
                    customController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
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
    final totalImages = _selectedImages.length;

    // ✅ Reset progrès au début
    if (mounted) {
      setState(() => _uploadProgress = 0.0);
    }

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
        final jpgBytes = img.encodeJpg(resized, quality: 100);
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

        // ✅ Mettre à jour le progrès après chaque image
        if (mounted) {
          setState(() {
            _uploadProgress = (i + 1) / totalImages;
          });
        }
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
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;  // ✅ Reset progrès
        });
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
            const SizedBox(height: 24),

            // ✅ Section Localisation
            Text(
              '📍 Localisation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _green,
              ),
            ),
            const SizedBox(height: 12),

            AddressLocationPicker(
              onLocationSelected: (address, latitude, longitude) {
                setState(() {
                  _addressController.text = address;
                  _latitudeController.text = latitude.toString();
                  _longitudeController.text = longitude.toString();
                });
              },
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
                      labelText: 'Tranche de prix',
                      border: OutlineInputBorder(),
                    ),
                    // Remplacement des $ par tes tranches spécifiques
                    items: [
                      '5-150\$',
                      '150-500\$',
                      '500-1000\$',
                      'Plus de 1000\$' // Optionnel, pour couvrir tous les cas
                    ]
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 14)),
                    ))
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

            // ✅ Amenities (Équipements)
            const Text(
              'Équipements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

// ✅ Chips avec icônes
            if (_amenities.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amenities.map((amenity) {
                  return Chip(
                    avatar: Icon(_amenityIcon(amenity), size: 18, color: _green),
                    label: Text(amenity),
                    onDeleted: () {
                      setState(() => _amenities.remove(amenity));
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Ajouter un équipement',
                      border: OutlineInputBorder(),
                      hintText: 'Wi-Fi, Parking, Piscine...',
                    ),
                    onSubmitted: (value) {
                      final v = value.trim();
                      if (v.isNotEmpty && !_amenities.contains(v)) {
                        setState(() => _amenities.add(v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // ✅ Bouton "+" : Dialog multi-select + recherche + ajout libre
                IconButton.filled(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final searchController = TextEditingController();
                        final customController = TextEditingController();
                        final Set<String> tempSelected = {..._amenities};

                        return StatefulBuilder(
                          builder: (context, setLocalState) {
                            final query = searchController.text.trim().toLowerCase();

                            final all = _amenitiesCatalog.keys.toList()
                              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                            final filtered = query.isEmpty
                                ? all
                                : all.where((e) => e.toLowerCase().contains(query)).toList();

                            return AlertDialog(
                              title: const Text('Ajouter des équipements'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✅ Recherche
                                    TextField(
                                      controller: searchController,
                                      decoration: const InputDecoration(
                                        labelText: 'Rechercher',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.search),
                                      ),
                                      onChanged: (_) => setLocalState(() {}),
                                    ),
                                    const SizedBox(height: 12),

                                    // ✅ Ajout libre
                                    TextField(
                                      controller: customController,
                                      decoration: const InputDecoration(
                                        labelText: 'Ajouter un équipement personnalisé',
                                        border: OutlineInputBorder(),
                                        hintText: 'Ex: Rooftop, DJ, Voiturier...',
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ✅ Liste selectable avec icônes
                                    Flexible(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Material(
                                          color: Theme.of(context).brightness == Brightness.light
                                              ? Colors.grey.shade50
                                              : Colors.grey.shade900,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: filtered.length,
                                            itemBuilder: (context, index) {
                                              final name = filtered[index];
                                              final checked = tempSelected.contains(name);

                                              return CheckboxListTile(
                                                value: checked,
                                                onChanged: (v) {
                                                  setLocalState(() {
                                                    if (v == true) {
                                                      tempSelected.add(name);
                                                    } else {
                                                      tempSelected.remove(name);
                                                    }
                                                  });
                                                },
                                                dense: true,
                                                controlAffinity: ListTileControlAffinity.leading,
                                                title: Text(name),
                                                secondary: Icon(_amenityIcon(name), color: _green),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    searchController.dispose();
                                    customController.dispose();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final custom = customController.text.trim();

                                    setState(() {
                                      // merge sélection
                                      _amenities
                                        ..clear()
                                        ..addAll(tempSelected);

                                      // ajout libre
                                      if (custom.isNotEmpty && !_amenities.contains(custom)) {
                                        _amenities.add(custom);
                                      }
                                    });

                                    searchController.dispose();
                                    customController.dispose();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Ajouter'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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

            // ✅ Barre de progression
            if (_isLoading && _uploadProgress > 0) ...[
              const SizedBox(height: 20),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_green),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedImages.isEmpty
                        ? 'Enregistrement en cours... ${(_uploadProgress * 100).toInt()}%'
                        : 'Upload des images... ${(_uploadProgress * 100).toInt()}% (${(_uploadProgress * _selectedImages.length).ceil()}/${_selectedImages.length})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
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