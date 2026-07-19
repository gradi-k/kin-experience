import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cityguide/controllers/categories_controller.dart';
import 'package:cityguide/models/category_config.dart';
import 'package:cityguide/views/admin/contents/edit_content_form.dart';

class DraftsScreen extends ConsumerStatefulWidget {
  const DraftsScreen({super.key});

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  static const Color _green = Color(0xFF0B7A4A);
  String _searchQuery = '';

  static const String collectionName = 'places';

  /// Charge tous les brouillons.
  ///
  /// Une seule requête sur `places` remplace les 6 lectures par collection.
  Future<List<_DraftItem>> _loadDrafts() async {
    final categories = await ref.read(categoriesServiceProvider).fetchAll();
    final byKey = {for (final c in categories) c.key: c};

    final snap = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('isDraft', isEqualTo: true)
        .get();

    final drafts = <_DraftItem>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final category = byKey[(data['categoryKey'] ?? '').toString()];

      // Un brouillon dont la catégorie a disparu n'est pas éditable : le
      // formulaire a besoin de sa config (champs, libellé).
      if (category == null) {
        debugPrint('⚠️ Brouillon ${doc.id} : catégorie '
            '"${data['categoryKey']}" introuvable, ignoré');
        continue;
      }

      drafts.add(_DraftItem(
        docId: doc.id,
        data: data,
        category: category,
        collectionName: collectionName,
      ));
    }

    return drafts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brouillons'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.light
                    ? Colors.grey[100]
                    : Colors.grey[800],
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<_DraftItem>>(
              future: _loadDrafts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('❌ Error in FutureBuilder: ${snapshot.error}');
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDrafts = snapshot.data ?? [];
                final drafts = allDrafts.where((draft) {
                  final nom = (draft.data['nom'] ?? '').toString().toLowerCase();
                  return nom.contains(_searchQuery);
                }).toList();

                if (drafts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drafts_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun brouillon',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: drafts.length,
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return _DraftCard(
                      draft: draft,
                      onChanged: () => setState(() {}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftItem {
  final String docId;
  final Map<String, dynamic> data;
  final CategoryConfig category;
  final String collectionName;

  _DraftItem({
    required this.docId,
    required this.data,
    required this.category,
    required this.collectionName,
  });
}

class _DraftCard extends StatelessWidget {
  final _DraftItem draft;
  final VoidCallback onChanged;

  const _DraftCard({
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = draft.data['nom'] ?? 'Sans nom';
    final description = draft.data['description'] ?? '';
    final photos = (draft.data['photos'] as List?)?.cast<String>() ?? [];

    // ✅ CORRECTION 3 : Filtrer les URLs vides
    final validPhotos = photos.where((url) => url.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editDraft(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: validPhotos.isNotEmpty  // ✅ Vérifie les URLs valides
                    ? Image.network(
                  validPhotos.first,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImage(),
                )
                    : _placeholderImage(),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(draft.category.icon, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          draft.category.labelFor('fr'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nom,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _publishDraft(context),
                          icon: const Icon(Icons.publish, size: 18),
                          label: const Text('Publier'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editDraft(context),
                          tooltip: 'Modifier',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(context),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
    );
  }

  void _editDraft(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditContentScreen(
          docId: draft.docId,
          category: draft.category,
          collectionName: draft.collectionName,
          initialData: draft.data,
        ),
      ),
    ).then((_) => onChanged());
  }

  Future<void> _publishDraft(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection(draft.collectionName)
          .doc(draft.docId)
          .update({'isDraft': false});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brouillon publié avec succès')),
        );
      }
      onChanged();
    } catch (e) {
      print('❌ Error publishing draft: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final itemNom = draft.data['nom'] ?? 'Sans nom';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$itemNom" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection(draft.collectionName)
            .doc(draft.docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brouillon supprimé avec succès')),
          );
        }
        onChanged();
      } catch (e) {
        print('❌ Error deleting draft: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}