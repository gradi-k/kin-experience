import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/categories_controller.dart';
import '../../../models/category_config.dart';
import 'category_form_screen.dart';

/// Gestion des catégories : créer, modifier, réordonner, activer, supprimer.
///
/// L'ordre de cette liste pilote celui de la home, des filtres et de la
/// rangée d'icônes.
class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur de chargement : $e'),
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) return const _EmptyState();

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Glissez pour réordonner. L\'ordre s\'applique à l\'accueil '
                  'et aux filtres.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final reordered = [...categories];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);

                    await ref
                        .read(categoriesServiceProvider)
                        .reorder(reordered.map((c) => c.key).toList());
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _CategoryTile(
                      key: ValueKey(cat.key),
                      category: cat,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final CategoryConfig category;

  const _CategoryTile({super.key, required this.category});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final service = ref.read(categoriesServiceProvider);
    final count = await service.countPlaces(category.key);

    if (!context.mounted) return;

    // Une catégorie qui contient des lieux ne peut pas être supprimée : ils
    // deviendraient inatteignables. On oriente vers la désactivation.
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suppression impossible'),
          content: Text(
            '$count lieu(x) sont rattachés à « ${category.labelFor('fr')} ».\n\n'
            'Désactivez plutôt la catégorie : elle disparaîtra de '
            'l\'application et ses lieux seront conservés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                service.setEnabled(category.key, false);
              },
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          '« ${category.labelFor('fr')} » ne contient aucun lieu. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.deleteCategory(category.key);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is StateError ? e.message : 'Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(categoryPlaceCountProvider(category.key));
    final accent = category.color ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withOpacity(category.enabled ? 0.15 : 0.05),
          child: Icon(
            category.icon,
            color: category.enabled ? accent : theme.disabledColor,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                category.labelFor('fr'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: category.enabled ? null : theme.disabledColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!category.enabled) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.disabledColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Masquée', style: TextStyle(fontSize: 10)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            category.key,
            countAsync.when(
              data: (n) => '$n lieu${n > 1 ? 'x' : ''}',
              loading: () => '…',
              error: (_, __) => '— lieux',
            ),
            if (category.fields.isNotEmpty)
              '${category.fields.length} champ'
                  '${category.fields.length > 1 ? 's' : ''}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: category.enabled,
              onChanged: (v) => ref
                  .read(categoriesServiceProvider)
                  .setEnabled(category.key, v),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryFormScreen(existing: category),
                    ),
                  );
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryFormScreen(existing: category),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune catégorie',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première catégorie, ou lancez le script de '
              'migration pour importer les six catégories existantes.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
