import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/places_controller.dart';
import '../localization/app_localizations.dart';

/// Écran d’administration permettant de gérer les collections (CRUD) pour
/// les sites, restaurants, hôtels, événements et entreprises.  Seuls les
/// utilisateurs dont l’email correspond à un compte administrateur sont
/// autorisés à accéder à cet écran.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  final Map<PlaceCategory, List<dynamic>> _items = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: PlaceCategory.values.length, vsync: this);
    _loadAll();
  }

  /// Vérifie si l’utilisateur est administrateur.
  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email == 'admin@mail.com';
  }

  /// Charge toutes les collections simultanément.
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      for (final category in PlaceCategory.values) {
        final snapshot = await FirebaseFirestore.instance
            .collection(category.collectionName)
            .get();
        _items[category] = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Ouvre un dialogue pour créer ou modifier un document.
  Future<void> _openEditDialog(
    PlaceCategory category, {
    Map<String, dynamic>? initialData,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final isEdit = initialData != null;
    final TextEditingController nameCtrl =
        TextEditingController(text: initialData?['nom'] ?? '');
    final TextEditingController descCtrl =
        TextEditingController(text: initialData?['description'] ?? '');
    final TextEditingController ratingCtrl = TextEditingController(
        text: initialData?['rating']?.toString() ?? '0');
    final TextEditingController latCtrl = TextEditingController(
        text: initialData?['latitude']?.toString() ?? '0');
    final TextEditingController lngCtrl = TextEditingController(
        text: initialData?['longitude']?.toString() ?? '0');
    final TextEditingController priceCtrl = TextEditingController(
        text: initialData?['prixRange'] ?? '');
    final TextEditingController photoCtrl = TextEditingController(
        text: (initialData?['photos'] as List<dynamic>?)?.isNotEmpty == true
            ? (initialData!['photos'] as List).first
            : '');
    bool isFeatured = initialData?['isFeatured'] ?? false;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? loc.translate('edit') : loc.translate('add')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(loc.translate('name'), nameCtrl),
                _buildTextField(loc.translate('description'), descCtrl),
                _buildTextField(loc.translate('rating'), ratingCtrl, keyboardType: TextInputType.number),
                _buildTextField(loc.translate('latitude'), latCtrl, keyboardType: TextInputType.number),
                _buildTextField(loc.translate('longitude'), lngCtrl, keyboardType: TextInputType.number),
                _buildTextField(loc.translate('price_range'), priceCtrl),
                _buildTextField(loc.translate('photo_url'), photoCtrl),
                Row(
                  children: [
                    Checkbox(
                      value: isFeatured,
                      onChanged: (value) {
                        setState(() {
                          isFeatured = value ?? false;
                        });
                      },
                    ),
                    Text(loc.translate('is_featured')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'nom': nameCtrl.text,
                  'description': descCtrl.text,
                  'rating': double.tryParse(ratingCtrl.text) ?? 0.0,
                  'latitude': double.tryParse(latCtrl.text) ?? 0.0,
                  'longitude': double.tryParse(lngCtrl.text) ?? 0.0,
                  'prixRange': priceCtrl.text,
                  'photos': [photoCtrl.text],
                  'isFeatured': isFeatured,
                };
                Navigator.of(context).pop();
                if (isEdit) {
                  // mise à jour
                  final docId = initialData!['id'];
                  await FirebaseFirestore.instance
                      .collection(category.collectionName)
                      .doc(docId)
                      .update(data);
                } else {
                  // création
                  await FirebaseFirestore.instance
                      .collection(category.collectionName)
                      .add(data);
                }
                await _loadAll();
              },
              child: Text(loc.translate('save')),
            ),
          ],
        );
      },
    );
  }

  /// Construit un champ texte avec label.
  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Supprime un document.
  Future<void> _deleteItem(PlaceCategory category, String id) async {
    await FirebaseFirestore.instance
        .collection(category.collectionName)
        .doc(id)
        .delete();
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('admin_title')),
        ),
        body: Center(
          child: Text('Access denied'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('admin_title')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: PlaceCategory.values.map((category) {
            final key = '${category.collectionName}_label';
            return Tab(text: loc.translate(key));
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: PlaceCategory.values.map((category) {
                    final list = _items[category] ?? [];
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index] as Map<String, dynamic>;
                        return ListTile(
                          title: Text(item['nom'] ?? ''),
                          subtitle: Text(item['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openEditDialog(category,
                                    initialData: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteItem(category, item['id']),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditDialog(
            PlaceCategory.values[_tabController.index]),
        child: const Icon(Icons.add),
      ),
    );
  }
}