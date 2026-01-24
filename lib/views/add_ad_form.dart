import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kin_experience/services/ad_service.dart';


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

    setState(() => _loading = true);
    try {
      await _ads.createAd(
        title: _titleCtrl.text,
        subtitle: _subtitleCtrl.text,
        ctaLabel: _ctaCtrl.text,
        link: _linkCtrl.text,
        isActive: _isActive,
        imageFile: _image!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleCtrl,
                  decoration: const InputDecoration(labelText: 'Sous-titre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ctaCtrl,
                  decoration: const InputDecoration(labelText: 'Label CTA'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
