import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/categories_controller.dart';
import '../../../models/category_config.dart';
import '../../../models/field_def.dart';
import '../../../utils/category_icons.dart';
import 'icon_picker.dart';

/// Création / édition d'une catégorie.
///
/// [existing] à `null` = création. En édition, la clé est verrouillée : elle
/// sert de `categoryKey` aux lieux, la changer les orphelinerait.
class CategoryFormScreen extends ConsumerStatefulWidget {
  final CategoryConfig? existing;

  const CategoryFormScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _keyCtrl;
  late final TextEditingController _labelFrCtrl;
  late final TextEditingController _labelEnCtrl;
  late final TextEditingController _ctaFrCtrl;
  late final TextEditingController _ctaEnCtrl;

  late String _iconName;
  String? _ctaIconName;
  late bool _enabled;
  late List<FieldDef> _fields;
  Color? _color;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _keyCtrl = TextEditingController(text: e?.key ?? '');
    _labelFrCtrl = TextEditingController(text: e?.label['fr'] ?? '');
    _labelEnCtrl = TextEditingController(text: e?.label['en'] ?? '');
    _ctaFrCtrl = TextEditingController(text: e?.ctaLabel['fr'] ?? '');
    _ctaEnCtrl = TextEditingController(text: e?.ctaLabel['en'] ?? '');

    _iconName = e?.iconName ?? CategoryIcons.fallbackName;
    _ctaIconName = e?.ctaIconName;
    _enabled = e?.enabled ?? true;
    _fields = [...(e?.sortedFields ?? const <FieldDef>[])];
    _color = e?.color;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _labelFrCtrl.dispose();
    _labelEnCtrl.dispose();
    _ctaFrCtrl.dispose();
    _ctaEnCtrl.dispose();
    super.dispose();
  }

  /// Propose une clé à partir du libellé français : minuscules, sans accents
  /// ni espaces. L'admin peut toujours la corriger avant de créer.
  void _suggestKeyFromLabel() {
    if (widget.isEditing || _keyCtrl.text.trim().isNotEmpty) return;

    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';

    var s = _labelFrCtrl.text.trim().toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      s = s.replaceAll(accents[i], plain[i]);
    }
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');

    if (s.isNotEmpty) _keyCtrl.text = s;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final config = CategoryConfig(
      key: _keyCtrl.text.trim(),
      label: {
        'fr': _labelFrCtrl.text.trim(),
        if (_labelEnCtrl.text.trim().isNotEmpty) 'en': _labelEnCtrl.text.trim(),
      },
      iconName: _iconName,
      order: widget.existing?.order ?? 999,
      enabled: _enabled,
      fields: _fields,
      colorValue: _color?.toARGB32(),
      ctaLabel: {
        if (_ctaFrCtrl.text.trim().isNotEmpty) 'fr': _ctaFrCtrl.text.trim(),
        if (_ctaEnCtrl.text.trim().isNotEmpty) 'en': _ctaEnCtrl.text.trim(),
      },
      ctaIconName: _ctaIconName,
    );

    final service = ref.read(categoriesServiceProvider);

    try {
      if (widget.isEditing) {
        await service.updateCategory(config);
      } else {
        await service.createCategory(config);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is StateError ? e.message : 'Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editField({FieldDef? existing, int? index}) async {
    final result = await showModalBottomSheet<FieldDef>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _FieldEditor(existing: existing),
      ),
    );

    if (result == null) return;

    setState(() {
      if (index != null) {
        _fields[index] = result;
      } else {
        _fields.add(result.copyWith(order: _fields.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier la catégorie' : 'Nouvelle catégorie',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // ── Identité ────────────────────────────────────────────────
            _SectionTitle('Identité'),
            TextFormField(
              controller: _labelFrCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom (français) *',
                hintText: 'ex : Pharmacies',
              ),
              onChanged: (_) => _suggestKeyFromLabel(),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Le nom en français est obligatoire'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelEnCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom (anglais)',
                hintText: 'ex : Pharmacies',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _keyCtrl,
              enabled: !widget.isEditing,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              decoration: InputDecoration(
                labelText: 'Clé technique *',
                helperText: widget.isEditing
                    ? 'Non modifiable : les lieux y sont rattachés.'
                    : 'Minuscules, chiffres et _ uniquement. Définitive.',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.key),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'La clé est obligatoire';
                if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s)) {
                  return 'Commence par une lettre ; a-z, 0-9 et _ seulement';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Apparence ───────────────────────────────────────────────
            _SectionTitle('Apparence'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor:
                    (_color ?? theme.colorScheme.primary).withOpacity(0.12),
                child: Icon(
                  CategoryIcons.resolve(_iconName),
                  color: _color ?? theme.colorScheme.primary,
                ),
              ),
              title: const Text('Icône'),
              subtitle: Text(_iconName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked =
                    await showIconPicker(context, selected: _iconName);
                if (picked != null) setState(() => _iconName = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('Visible dans l\'application'),
              subtitle: const Text(
                'Désactivée, la catégorie disparaît de l\'app mais ses lieux '
                'sont conservés.',
              ),
            ),

            const SizedBox(height: 24),

            // ── Bouton d'action ─────────────────────────────────────────
            _SectionTitle('Bouton de la fiche détail'),
            Text(
              'Texte du bouton principal sur la fiche d\'un lieu. '
              'Vide ⇒ « En savoir plus ».',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctaFrCtrl,
              decoration: const InputDecoration(
                labelText: 'Texte du bouton (français)',
                hintText: 'ex : Réserver, Acheter un billet…',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctaEnCtrl,
              decoration: const InputDecoration(
                labelText: 'Texte du bouton (anglais)',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _ctaIconName == null
                    ? CategoryIcons.resolve(_iconName)
                    : CategoryIcons.resolve(_ctaIconName),
              ),
              title: const Text('Icône du bouton'),
              subtitle: Text(_ctaIconName ?? 'Identique à la catégorie'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked =
                    await showIconPicker(context, selected: _ctaIconName);
                if (picked != null) setState(() => _ctaIconName = picked);
              },
            ),

            const SizedBox(height: 24),

            // ── Champs personnalisés ────────────────────────────────────
            _SectionTitle('Champs personnalisés'),
            Text(
              'En plus des champs communs (nom, description, adresse, photos, '
              'localisation, téléphone, horaires…). Ils apparaissent dans le '
              'formulaire d\'ajout de lieu de cette catégorie.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_fields.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun champ personnalisé.'),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _fields.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _fields.removeAt(oldIndex);
                    _fields.insert(newIndex, item);
                    // L'ordre affiché fait foi : on le réécrit sur les champs.
                    for (var i = 0; i < _fields.length; i++) {
                      _fields[i] = _fields[i].copyWith(order: i);
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final f = _fields[index];
                  return Card(
                    key: ValueKey('${f.key}_$index'),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      title: Text(f.labelFor('fr')),
                      subtitle: Text(
                        '${f.key} · ${f.type.name}${f.required ? ' · requis' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                setState(() => _fields.removeAt(index)),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () => _editField(existing: f, index: index),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _editField(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un champ'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isEditing ? 'Enregistrer' : 'Créer la catégorie'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Éditeur d'un champ personnalisé.
class _FieldEditor extends StatefulWidget {
  final FieldDef? existing;

  const _FieldEditor({this.existing});

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _keyCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _optionsCtrl;
  late final TextEditingController _hintCtrl;

  late FieldType _type;
  late bool _required;

  bool get _isEditing => widget.existing != null;

  bool get _needsOptions =>
      _type == FieldType.select || _type == FieldType.multiselect;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _keyCtrl = TextEditingController(text: e?.key ?? '');
    _labelCtrl = TextEditingController(text: e?.label['fr'] ?? '');
    _optionsCtrl = TextEditingController(text: e?.options.join(', ') ?? '');
    _hintCtrl = TextEditingController(text: e?.hint ?? '');
    _type = e?.type ?? FieldType.text;
    _required = e?.required ?? false;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _labelCtrl.dispose();
    _optionsCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final options = _optionsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Navigator.of(context).pop(
      FieldDef(
        key: _keyCtrl.text.trim(),
        label: {'fr': _labelCtrl.text.trim()},
        type: _type,
        required: _required,
        options: options,
        order: widget.existing?.order ?? 0,
        hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Modifier le champ' : 'Nouveau champ',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Libellé *',
                  hintText: 'ex : Garde de nuit',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Libellé obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keyCtrl,
                enabled: !_isEditing,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Clé technique *',
                  helperText: _isEditing
                      ? 'Non modifiable : les valeurs déjà saisies y sont liées.'
                      : 'ex : garde_nuit',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Clé obligatoire';
                  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s)) {
                    return 'a-z, 0-9 et _ ; commence par une lettre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FieldType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: FieldType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(t)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? FieldType.text),
              ),
              if (_needsOptions) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _optionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Options *',
                    helperText: 'Séparées par des virgules',
                    hintText: 'ex : Oui, Non, Sur rendez-vous',
                  ),
                  validator: (v) {
                    if (!_needsOptions) return null;
                    return (v ?? '').trim().isEmpty
                        ? 'Au moins une option est nécessaire'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _hintCtrl,
                decoration: const InputDecoration(
                  labelText: 'Aide (optionnel)',
                  hintText: 'Texte affiché sous le champ',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                onChanged: (v) => setState(() => _required = v),
                title: const Text('Champ obligatoire'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(FieldType t) {
    switch (t) {
      case FieldType.text:
        return 'Texte court';
      case FieldType.multiline:
        return 'Texte long';
      case FieldType.number:
        return 'Nombre';
      case FieldType.bool:
        return 'Oui / Non';
      case FieldType.select:
        return 'Liste (choix unique)';
      case FieldType.multiselect:
        return 'Liste (choix multiples)';
      case FieldType.date:
        return 'Date';
      case FieldType.phone:
        return 'Téléphone';
      case FieldType.url:
        return 'Lien web';
    }
  }
}
