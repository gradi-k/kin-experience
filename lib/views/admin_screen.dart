// lib/views/admin_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/place_enums.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  PlaceCategory _selected = PlaceCategory.restaurants;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(_selected.collectionName);

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _collection.add({
        'name': _nameCtrl.text.trim(),
        'imageUrl': _imageCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _nameCtrl.clear();
      _imageCtrl.clear();
      _locationCtrl.clear();
      _descCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajouté avec succès')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _update(String docId, Map<String, dynamic> current) async {
    final nameCtrl = TextEditingController(text: (current['name'] ?? '').toString());
    final imageCtrl = TextEditingController(text: (current['imageUrl'] ?? '').toString());
    final locationCtrl = TextEditingController(text: (current['location'] ?? '').toString());
    final descCtrl = TextEditingController(text: (current['description'] ?? '').toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Modifier', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: imageCtrl,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Localisation'),
              ),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _collection.doc(docId).update({
                        'name': nameCtrl.text.trim(),
                        'imageUrl': imageCtrl.text.trim(),
                        'location': locationCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Modifié avec succès')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
    imageCtrl.dispose();
    locationCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _delete(String docId) async {
    try {
      await _collection.doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            // Category picker
            Text('Catégorie', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: PlaceCategory.values.map((c) {
                final selected = c == _selected;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Create form
            Text('Ajouter un élément', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _imageCtrl,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Image URL requise' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(labelText: 'Localisation'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Localisation requise' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Description requise' : null,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _create,
                      child: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Ajouter'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Items list
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Éléments (${_selected.label})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  'Collection: ${_selected.collectionName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _collection.orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('Erreur: ${snap.error}'),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('Aucun élément dans ${_selected.label}.'),
                  );
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final name = (data['name'] ?? '').toString();
                    final location = (data['location'] ?? '').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: theme.dividerColor.withOpacity(0.08),
                                child: const Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                          ),
                        ),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _update(d.id, data),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(d.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
