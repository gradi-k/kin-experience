// lib/views/add_reel_form.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cityguide/models/reel.dart';
import 'package:video_compress/video_compress.dart';



class AddReelForm extends StatefulWidget {
  final Reel? existingReel; // Pour l'édition

  const AddReelForm({super.key, this.existingReel});

  @override
  State<AddReelForm> createState() => _AddReelFormState();
}

class _AddReelFormState extends State<AddReelForm> {
  static const Color _green = Color(0xFF0B7A4A);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _authorNameController = TextEditingController();
  final _musicLabelController = TextEditingController();
  final _videoUrlController = TextEditingController();

  // Sélection du lieu lié
  String? _selectedPlaceId;
  String? _selectedPlaceCategory;
  String? _selectedPlaceName;

  // Fichier vidéo local
  File? _videoFile;
  String? _existingVideoUrl;

  bool _isLoading = false;
  bool _isActive = true;
  String? _error;

  // Progress tracking
  double _uploadProgress = 0;
  double _compressionProgress = 0;
  bool _isCompressing = false;
  String _progressMessage = '';

  bool get _isEditing => widget.existingReel != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final reel = widget.existingReel!;
      _captionController.text = reel.caption;
      _locationController.text = reel.location;
      _authorNameController.text = reel.authorName;
      _musicLabelController.text = reel.musicLabel ?? '';
      _videoUrlController.text = reel.videoUrl;
      _existingVideoUrl = reel.videoUrl;
      _selectedPlaceId = reel.placeId;
      _selectedPlaceCategory = reel.placeCategory;
      _selectedPlaceName = reel.placeName;
      _isActive = reel.isActive;
    } else {
      // Auteur par défaut
      final user = FirebaseAuth.instance.currentUser;
      _authorNameController.text = user?.displayName ?? 'City Guide';
    }

    // Écouter les événements de compression
    VideoCompress.compressProgress$.subscribe((progress) {
      setState(() {
        _compressionProgress = progress / 100;
        _progressMessage = 'Compression: ${progress.toStringAsFixed(0)}%';
      });
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _authorNameController.dispose();
    _musicLabelController.dispose();
    _videoUrlController.dispose();
    VideoCompress.cancelCompression();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _videoUrlController.clear();
        _compressionProgress = 0;
        _uploadProgress = 0;
      });
    }
  }

  /// Compresse la vidéo avant l'upload
  Future<File?> _compressVideo(File file) async {
    setState(() {
      _isCompressing = true;
      _compressionProgress = 0;
      _progressMessage = 'Compression en cours...';
    });

    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false, // Garde l'original
        includeAudio: true,
      );

      if (info != null && info.file != null) {
        setState(() {
          _isCompressing = false;
          _compressionProgress = 1.0;
          _progressMessage = 'Compression terminée!';
        });

        // Log pour debug
        final originalSize = await file.length();
        final compressedSize = await info.file!.length();
        final reduction = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);
        debugPrint('Compression: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB (${reduction}% réduit)');

        return info.file;
      }

      throw Exception('Échec de la compression');
    } catch (e) {
      setState(() {
        _isCompressing = false;
        _error = 'Erreur de compression: $e';
      });
      debugPrint('Compression error: $e');
      return null;
    }
  }

  Future<String?> _uploadVideo(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non authentifié');

      setState(() {
        _uploadProgress = 0;
        _progressMessage = 'Upload en cours...';
      });

      final fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance.ref().child('reels/$fileName');

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Écouter la progression de l'upload
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        setState(() {
          _uploadProgress = progress;
          _progressMessage = 'Upload: ${(progress * 100).toStringAsFixed(0)}%';
        });
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _progressMessage = 'Upload terminé!';
      });

      return downloadUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() {
        _error = 'Erreur d\'upload: $e';
      });
      return null;
    }
  }

  Future<void> _selectPlace() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _PlaceSelector(),
    );

    if (result != null) {
      setState(() {
        _selectedPlaceId = result['id'];
        _selectedPlaceCategory = result['category'];
        _selectedPlaceName = result['name'];
        if (_locationController.text.isEmpty) {
          _locationController.text = result['name'] ?? '';
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier qu'on a soit un fichier, soit une URL
    if (_videoFile == null && _videoUrlController.text.trim().isEmpty && _existingVideoUrl == null) {
      setState(() => _error = 'Veuillez sélectionner une vidéo ou entrer une URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _uploadProgress = 0;
      _compressionProgress = 0;
      _progressMessage = 'Préparation...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non authentifié');

      String videoUrl;

      // Upload si fichier local
      if (_videoFile != null) {
        // Étape 1: Compression
        File? videoToUpload = _videoFile;

        // Compresser uniquement si la vidéo fait plus de 10MB
        final fileSize = await _videoFile!.length();
        if (fileSize > 10 * 1024 * 1024) {
          debugPrint('Vidéo grande (${fileSize ~/ 1024}KB), compression...');
          final compressed = await _compressVideo(_videoFile!);
          if (compressed != null) {
            videoToUpload = compressed;
          } else {
            // Si la compression échoue, utiliser l'original
            debugPrint('Utilisation de la vidéo originale après échec compression');
            videoToUpload = _videoFile;
          }
        } else {
          debugPrint('Vidéo petite (${fileSize ~/ 1024}KB), pas de compression nécessaire');
          setState(() {
            _progressMessage = 'Vidéo de taille optimale, pas de compression nécessaire';
          });
        }

        // Étape 2: Upload
        final uploadedUrl = await _uploadVideo(videoToUpload!);
        if (uploadedUrl == null) {
          throw Exception('Échec de l\'upload de la vidéo');
        }
        videoUrl = uploadedUrl;

        // Nettoyer le fichier compressé s'il est différent de l'original
        if (videoToUpload != _videoFile) {
          try {
            await videoToUpload.delete();
          } catch (e) {
            debugPrint('Erreur lors de la suppression du fichier temporaire: $e');
          }
        }
      } else if (_videoUrlController.text.trim().isNotEmpty) {
        videoUrl = _videoUrlController.text.trim();
      } else {
        videoUrl = _existingVideoUrl!;
      }

      setState(() {
        _progressMessage = 'Enregistrement des données...';
      });

      final data = {
        'videoUrl': videoUrl,
        'authorName': _authorNameController.text.trim(),
        'authorAvatar': user.photoURL ?? '',
        'caption': _captionController.text.trim(),
        'location': _locationController.text.trim(),
        'musicLabel': _musicLabelController.text.trim().isEmpty ? null : _musicLabelController.text.trim(),
        'placeId': _selectedPlaceId,
        'placeCategory': _selectedPlaceCategory,
        'placeName': _selectedPlaceName,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(widget.existingReel!.id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = user.uid;
        data['likes'] = 0;
        data['comments'] = 0;
        await FirebaseFirestore.instance.collection('reels').add(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Reel mis à jour !' : 'Reel ajouté !'),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _progressMessage = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCompressing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le reel' : 'Ajouter un reel'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: _green),
              label: const Text('Enregistrer', style: TextStyle(color: _green)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Formulaire principal
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Vidéo
                const _SectionTitle(title: 'Vidéo', icon: Icons.video_library),
                const SizedBox(height: 12),

                // Sélection de vidéo
                GestureDetector(
                  onTap: _isLoading ? null : _pickVideo,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: _videoFile != null
                        ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Icon(
                              Icons.video_file,
                              size: 64,
                              color: _green.withOpacity(0.5),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 48,
                          color: _green.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Toucher pour sélectionner',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_videoFile != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<int>(
                    future: _videoFile!.length(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final sizeInMB = snapshot.data! / (1024 * 1024);
                        return Text(
                          'Taille: ${sizeInMB.toStringAsFixed(2)} MB',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                const SizedBox(height: 12),
                const Text(
                  'ou',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // URL alternative
                TextFormField(
                  controller: _videoUrlController,
                  enabled: !_isLoading && _videoFile == null,
                  decoration: _inputDecoration(
                    theme,
                    label: 'URL de la vidéo',
                    hint: 'https://...',
                    icon: Icons.link,
                  ),
                  validator: (v) {
                    if (_videoFile == null &&
                        (v == null || v.trim().isEmpty) &&
                        _existingVideoUrl == null) {
                      return 'Vidéo requise';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Informations
                const _SectionTitle(title: 'Informations', icon: Icons.info_outline),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _captionController,
                  enabled: !_isLoading,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    theme,
                    label: 'Légende',
                    hint: 'Décrivez votre reel...',
                    icon: Icons.text_fields,
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Légende requise' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _locationController,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    theme,
                    label: 'Lieu',
                    hint: 'Ex: Kinshasa, RDC',
                    icon: Icons.location_on,
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Lieu requis' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _authorNameController,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    theme,
                    label: 'Auteur',
                    icon: Icons.person,
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Auteur requis' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _musicLabelController,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    theme,
                    label: 'Musique (optionnel)',
                    hint: 'Artiste - Titre',
                    icon: Icons.music_note,
                  ),
                ),

                const SizedBox(height: 24),

                // Lieu lié
                const _SectionTitle(title: 'Lieu associé', icon: Icons.place),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _selectPlace,
                  icon: const Icon(Icons.search, color: _green),
                  label: Text(
                    _selectedPlaceName ?? 'Sélectionner un lieu',
                    style: const TextStyle(color: _green),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_selectedPlaceName != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(_selectedPlaceName!),
                    onDeleted: _isLoading
                        ? null
                        : () {
                      setState(() {
                        _selectedPlaceId = null;
                        _selectedPlaceCategory = null;
                        _selectedPlaceName = null;
                      });
                    },
                    deleteIconColor: _green,
                  ),
                ],

                const SizedBox(height: 24),

                // Statut
                SwitchListTile(
                  value: _isActive,
                  onChanged: _isLoading ? null : (v) => setState(() => _isActive = v),
                  title: const Text('Reel actif'),
                  subtitle: Text(_isActive ? 'Visible par tous' : 'Masqué'),
                  activeColor: _green,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 24),

                // Erreur
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80), // Espace pour le bottom sheet
              ],
            ),
          ),

          // Barre de progression (overlay)
          if (_isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ProgressOverlay(
                isCompressing: _isCompressing,
                compressionProgress: _compressionProgress,
                uploadProgress: _uploadProgress,
                message: _progressMessage,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      ThemeData theme, {
        required String label,
        String? hint,
        IconData? icon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: _green) : null,
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _green, width: 2),
      ),
    );
  }
}

/// Widget pour afficher la progression de compression et d'upload
class _ProgressOverlay extends StatelessWidget {
  final bool isCompressing;
  final double compressionProgress;
  final double uploadProgress;
  final String message;

  const _ProgressOverlay({
    required this.isCompressing,
    required this.compressionProgress,
    required this.uploadProgress,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalProgress = isCompressing ? compressionProgress : uploadProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône animée
            SizedBox(
              height: 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isCompressing
                    ? const Icon(
                  Icons.compress,
                  size: 40,
                  color: Color(0xFF0B7A4A),
                  key: ValueKey('compress'),
                )
                    : const Icon(
                  Icons.cloud_upload,
                  size: 40,
                  color: Color(0xFF0B7A4A),
                  key: ValueKey('upload'),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Barre de progression
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: totalProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B7A4A), Color(0xFF0D9F5F)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Pourcentage
            Text(
              '${(totalProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0B7A4A),
              ),
            ),

            const SizedBox(height: 8),

            // Détails de progression
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProgressStep(
                  label: 'Compression',
                  isActive: isCompressing,
                  isCompleted: !isCompressing && compressionProgress > 0,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                _ProgressStep(
                  label: 'Upload',
                  isActive: !isCompressing,
                  isCompleted: uploadProgress >= 1.0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicateur d'étape de progression
class _ProgressStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _ProgressStep({
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0B7A4A).withOpacity(0.1)
            : isCompleted
            ? Colors.green.shade50
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? const Color(0xFF0B7A4A)
              : isCompleted
              ? Colors.green
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle,
            size: 14,
            color: isActive
                ? const Color(0xFF0B7A4A)
                : isCompleted
                ? Colors.green
                : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? const Color(0xFF0B7A4A)
                  : isCompleted
                  ? Colors.green
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0B7A4A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// ✅ Sélecteur de lieu
class _PlaceSelector extends StatefulWidget {
  const _PlaceSelector();

  @override
  State<_PlaceSelector> createState() => _PlaceSelectorState();
}

class _PlaceSelectorState extends State<_PlaceSelector> {
  String _selectedCategory = 'sites';
  String _searchQuery = '';

  final _categories = {
    'sites': 'Sites touristiques',
    'hotels': 'Hôtels',
    'restaurants': 'Restaurants',
    'events': 'Événements',
    'business': 'Entreprises',
    'shopping': 'Shopping',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sélectionner un lieu',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Catégories
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _categories.entries.map((e) {
                    final isSelected = _selectedCategory == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = e.key),
                        selectedColor: const Color(0xFF0B7A4A).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF0B7A4A) : null,
                          fontWeight: isSelected ? FontWeight.w700 : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Recherche
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Liste des lieux
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(_selectedCategory)
                      .orderBy('nom')
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = snapshot.data!.docs;

                    // Filtrer par recherche
                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((d) {
                        final nom = (d.data()['nom'] ?? '').toString().toLowerCase();
                        return nom.contains(_searchQuery);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return const Center(child: Text('Aucun lieu trouvé'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final nom = (data['nom'] ?? 'Sans nom').toString();
                        final photos = data['photos'] as List?;
                        final firstPhoto = photos?.isNotEmpty == true ? photos!.first.toString() : null;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: firstPhoto != null
                                ? (firstPhoto.startsWith('assets/')
                                ? AssetImage(firstPhoto) as ImageProvider
                                : NetworkImage(firstPhoto))
                                : null,
                            backgroundColor: const Color(0xFF0B7A4A).withOpacity(0.1),
                            child: firstPhoto == null
                                ? const Icon(Icons.place, color: Color(0xFF0B7A4A))
                                : null,
                          ),
                          title: Text(
                            nom,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_categories[_selectedCategory] ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).pop({
                              'id': doc.id,
                              'category': _selectedCategory,
                              'name': nom,
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}