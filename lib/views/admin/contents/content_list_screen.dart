import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kin_experience/models/place_enums.dart';
import 'package:kin_experience/views/admin/contents/edit_content_form.dart';

class ContentListScreen extends StatefulWidget {
  final PlaceCategory category;

  const ContentListScreen({super.key, required this.category});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  static const Color _green = Color(0xFF0B7A4A);
  String _searchQuery = '';

  String get collectionName {
    switch (widget.category) {
      case PlaceCategory.site:
        return 'sites';
      case PlaceCategory.hotel:
        return 'hotels';
      case PlaceCategory.resto:
        return 'restaurants';  // ✅ CORRIGÉ : Correspond à Firebase
      case PlaceCategory.event:
        return 'events';
      case PlaceCategory.entreprise:
        return 'business';  // ✅ CORRIGÉ : Correspond à Firebase
      case PlaceCategory.shopping:
        return 'shopping';  // ✅ CORRIGÉ : Correspond à Firebase
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.label}'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de recherche
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

          // Liste des contenus
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionName)
                  .where('isDraft', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('❌ Error loading $collectionName: ${snapshot.error}');
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom = (data['nom'] ?? '').toString().toLowerCase();
                  return nom.contains(_searchQuery);
                }).toList();

                print('✅ Loaded ${docs.length} items from $collectionName');

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun contenu',
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
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _ContentCard(
                      docId: doc.id,
                      data: data,
                      category: widget.category,
                      collectionName: collectionName,
                      onDeleted: () => setState(() {}),
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

class _ContentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final PlaceCategory category;
  final String collectionName;
  final VoidCallback onDeleted;

  const _ContentCard({
    required this.docId,
    required this.data,
    required this.category,
    required this.collectionName,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = data['nom'] ?? 'Sans nom';
    final description = data['description'] ?? '';
    final photos = (data['photos'] as List?)?.cast<String>() ?? [];
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final isFeatured = data['isFeatured'] ?? false;

    // ✅ CORRECTION 3 : Filtrer les URLs vides
    final validPhotos = photos.where((url) => url.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editContent(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
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

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Actions
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editContent(context),
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

  void _editContent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditContentScreen(
          docId: docId,
          category: category,
          collectionName: collectionName,
          initialData: data,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final data = this.data;
    final itemNom = data['nom'] ?? 'Sans nom';
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
            .collection(collectionName)
            .doc(docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contenu supprimé avec succès')),
          );
        }
        onDeleted();
      } catch (e) {
        print('❌ Error deleting content: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}