import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cityguide/services/ad_service.dart';



/// Admin screen: create a new ad.
/// This file keeps UI intentionally simple so you can apply your existing theme/styles
/// without changing your app's design elsewhere.
class AddAdForm extends StatefulWidget {
  const AddAdForm({super.key});

  @override
  State<AddAdForm> createState() => _AddAdFormState();
}

class _AddAdFormState extends State<AddAdForm> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController(text: 'Boutique');
  final _linkCtrl = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  double _uploadProgress = 0.0;  // ✅ Ajouté : Progression de l'upload (0.0 à 1.0)
  File? _image;

  final _ads = AdsService();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _ctaCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (x == null) return;

    setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une image.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _uploadProgress = 0.0;  // ✅ Reset progrès
    });

    try {
      // ✅ Simuler la progression de l'upload
      // Note: Pour un vrai progrès Firebase, modifie AdsService.createAd
      // pour retourner un Stream<double> ou utilise uploadTask.snapshotEvents

      // Début de l'upload
      setState(() => _uploadProgress = 0.1);

      // Appel du service (l'upload réel se fait ici)
      final uploadFuture = _ads.createAd(
        title: _titleCtrl.text,
        subtitle: _subtitleCtrl.text,
        ctaLabel: _ctaCtrl.text,
        link: _linkCtrl.text,
        isActive: _isActive,
        imageFile: _image!,
      );

      // Simuler la progression pendant l'upload
      // (remplace ça par un vrai listener Firebase si possible)
      _simulateProgress();

      await uploadFuture;

      // Upload terminé
      setState(() => _uploadProgress = 1.0);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadProgress = 0.0;  // ✅ Reset après
        });
      }
    }
  }

  // ✅ Méthode pour simuler la progression (temporaire)
  // TODO: Remplacer par un vrai listener Firebase Storage
  void _simulateProgress() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_loading && mounted && _uploadProgress < 0.9) {
        setState(() => _uploadProgress += 0.15);
        _simulateProgress();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une publicité'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: theme.cardColor,
                      border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _image == null
                        ? const Center(child: Text('Choisir une image'))
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // vide accepté
                      //if (v.length < 3) return 'Minimum 3 caractères';
                      return null;
                    }
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleCtrl,
                  decoration: const InputDecoration(labelText: 'Sous-titre'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // vide accepté
                      //if (v.length < 3) return 'Minimum 3 caractères';
                      return null;
                    }
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ctaCtrl,
                  decoration: const InputDecoration(labelText: 'Label CTA'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // vide accepté

                      return null;
                    }
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(labelText: 'Lien (URL)'),
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activer la publicité'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),

                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Enregistrer'),
                ),

                // ✅ Barre de progression
                if (_loading && _uploadProgress > 0) ...[
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: theme.dividerColor.withOpacity(0.2),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload en cours... ${(_uploadProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}