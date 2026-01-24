import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:kin_experience/services/ad_service.dart';


/// Admin screen: edit an ad (same form as Add, + toggle + delete handled in list).
class EditAdForm extends StatefulWidget {
  final AdModel ad;

  const EditAdForm({super.key, required this.ad});

  @override
  State<EditAdForm> createState() => _EditAdFormState();
}

class _EditAdFormState extends State<EditAdForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _ctaCtrl;
  late final TextEditingController _linkCtrl;

  bool _isActive = true;
  bool _loading = false;
  File? _newImage;

  final _ads = AdsService();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.ad.title);
    _subtitleCtrl = TextEditingController(text: widget.ad.subtitle);
    _ctaCtrl = TextEditingController(text: widget.ad.ctaLabel);
    _linkCtrl = TextEditingController(text: widget.ad.link);
    _isActive = widget.ad.isActive;
  }

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
    setState(() => _newImage = File(x.path));
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _ads.updateAd(
        adId: widget.ad.id,
        title: _titleCtrl.text,
        subtitle: _subtitleCtrl.text,
        ctaLabel: _ctaCtrl.text,
        link: _linkCtrl.text,
        isActive: _isActive,
        newImageFile: _newImage,
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

  Widget _previewImage(ThemeData theme) {
    final current = widget.ad.image;
    final isNetwork = current.startsWith('http://') || current.startsWith('https://');

    if (_newImage != null) {
      return Image.file(_newImage!, fit: BoxFit.cover);
    }
    if (isNetwork) {
      return Image.network(current, fit: BoxFit.cover);
    }
    // legacy asset
    return Image.asset(current, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la publicité'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    child: _previewImage(theme),
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
