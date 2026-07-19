import 'package:flutter/material.dart';

import '../../../utils/category_icons.dart';

/// Sélecteur d'icône : grille des icônes de [CategoryIcons] avec recherche.
///
/// Retourne le nom de l'icône choisie, ou `null` si annulé.
Future<String?> showIconPicker(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _IconPickerSheet(selected: selected),
  );
}

class _IconPickerSheet extends StatefulWidget {
  final String? selected;

  const _IconPickerSheet({this.selected});

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = CategoryIcons.all.where((e) {
      if (_query.isEmpty) return true;
      return e.key.contains(_query);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Text(
                'Choisir une icône',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher (ex: pharmacy, school, bank…)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('Aucune icône trouvée'))
                    : GridView.builder(
                        controller: scrollController,
                        itemCount: entries.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 84,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSelected = entry.key == widget.selected;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(entry.key),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? theme.colorScheme.primary
                                        .withOpacity(0.08)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    entry.value,
                                    size: 26,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 2),
                                    child: Text(
                                      entry.key,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(fontSize: 8),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
