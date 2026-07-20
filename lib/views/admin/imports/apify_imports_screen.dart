// lib/views/admin/imports/apify_imports_screen.dart
//
// Écran admin « Imports Apify » : lancement d'un import de lieux depuis
// Apify (Google Places Crawler) et historique temps réel des runs.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cityguide/controllers/apify_import_controller.dart';
import 'package:cityguide/controllers/categories_controller.dart';
import 'package:cityguide/data/kinshasa_zones.dart';
import 'package:cityguide/models/apify_import_run.dart';
import 'package:cityguide/views/admin/contents/drafts_screen.dart';

const _green = Color(0xFF0B7A4A);

/// Catégories pour lesquelles le mapper Apify côté serveur sait écrire —
/// doit rester synchronisé avec `functions/apify/pipeline.js`
/// (CATEGORY_SEARCH_TERMS).
const Map<String, String> _supportedCategoryLabels = {
  'restaurants': 'Restaurants',
  'hotels': 'Hôtels',
  'sites': 'Sites touristiques',
  'business': 'Business',
  'shopping': 'Shopping',
};

class ApifyImportsScreen extends ConsumerStatefulWidget {
  const ApifyImportsScreen({super.key});

  @override
  ConsumerState<ApifyImportsScreen> createState() =>
      _ApifyImportsScreenState();
}

class _ApifyImportsScreenState extends ConsumerState<ApifyImportsScreen> {
  final _customQueryController = TextEditingController();
  final _maxItemsController = TextEditingController(text: '50');

  String? _categoryKey;
  String? _commune;
  bool _advancedOpen = false;
  bool _launching = false;

  @override
  void dispose() {
    _customQueryController.dispose();
    _maxItemsController.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    final categoryKey = _categoryKey;
    if (categoryKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une catégorie')),
      );
      return;
    }

    setState(() => _launching = true);
    try {
      await startApifyImportCall(
        categoryKey: categoryKey,
        commune: _commune,
        customQuery: _customQueryController.text,
        maxItems: int.tryParse(_maxItemsController.text) ?? 50,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Import lancé — les résultats arriveront en brouillons'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Échec du lancement')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _openDrafts() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DraftsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final availableKeys = categoriesAsync.value == null
        ? _supportedCategoryLabels.keys.toList()
        : categoriesAsync.value!
            .map((c) => c.key)
            .where(_supportedCategoryLabels.containsKey)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imports Apify'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Lancer un import', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryKey,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    items: availableKeys
                        .map((key) => DropdownMenuItem(
                              value: key,
                              child: Text(
                                  _supportedCategoryLabels[key] ?? key),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryKey = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _commune,
                    decoration: const InputDecoration(
                      labelText: 'Commune',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Toute la ville')),
                      ...kinshasaZones.map((z) => DropdownMenuItem(
                            value: z.nom,
                            child: Text(z.nom),
                          )),
                    ],
                    onChanged: (v) => setState(() => _commune = v),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Options avancées'),
                    initiallyExpanded: _advancedOpen,
                    onExpansionChanged: (v) =>
                        setState(() => _advancedOpen = v),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _customQueryController,
                        decoration: const InputDecoration(
                          labelText: 'Requête personnalisée (optionnel)',
                          hintText: 'Ex: pharmacies Gombe Kinshasa',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _maxItemsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nombre max de résultats',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Chaque lieu consomme des crédits Apify.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _launching ? null : _launch,
                    icon: _launching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: const Text("Lancer l'import"),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: _green),
                    onPressed: _openDrafts,
                    icon: const Icon(Icons.feed_outlined),
                    label: const Text('Valider les brouillons'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Historique', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Consumer(builder: (context, ref, _) {
            final runsAsync = ref.watch(apifyImportsProvider);
            return runsAsync.when(
              loading: () =>
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erreur de chargement: $e'),
              ),
              data: (runs) {
                if (runs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun import pour le moment.'),
                  );
                }
                return Column(
                  children: runs.map((r) => _RunTile(run: r)).toList(),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final ApifyImportRun run;
  const _RunTile({required this.run});

  Color _statusColor() {
    switch (run.status) {
      case 'done':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel() {
    switch (run.status) {
      case 'done':
        return 'Terminé';
      case 'failed':
        return 'Échec';
      default:
        return 'En cours';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = run.counts;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 6,
          backgroundColor: _statusColor(),
        ),
        title: Text(run.query ?? run.categoryKey ?? run.id),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statusLabel(),
                style: TextStyle(
                    color: _statusColor(), fontWeight: FontWeight.w600)),
            if (run.status == 'done' && counts != null)
              Text(
                '${counts.created} créés · ${counts.updated} mis à jour · '
                '${counts.skipped} ignorés',
                style: theme.textTheme.bodySmall,
              ),
            if (run.status == 'failed' && run.error != null)
              Text(run.error!, style: theme.textTheme.bodySmall),
          ],
        ),
        isThreeLine: run.status == 'done' || run.status == 'failed',
      ),
    );
  }
}
