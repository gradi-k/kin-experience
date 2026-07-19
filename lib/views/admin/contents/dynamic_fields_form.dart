import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/field_def.dart';

/// Construit les champs de saisie déclarés par une catégorie
/// (`CategoryConfig.fields`) et écrit les valeurs dans `Place.extras`.
///
/// [values] est muté en place à chaque saisie : le formulaire parent en est
/// propriétaire et le passe tel quel à `Place.extras`.
class DynamicFieldsForm extends StatelessWidget {
  final List<FieldDef> fields;
  final Map<String, dynamic> values;

  /// Notifie le parent d'un changement, pour son `setState`.
  final VoidCallback? onChanged;

  const DynamicFieldsForm({
    super.key,
    required this.fields,
    required this.values,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          _buildField(context, field),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _set(String key, dynamic value) {
    values[key] = value;
    onChanged?.call();
  }

  Widget _buildField(BuildContext context, FieldDef field) {
    final label = field.labelFor('fr') + (field.required ? ' *' : '');

    switch (field.type) {
      case FieldType.bool:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: values[field.key] == true,
          onChanged: (v) => _set(field.key, v),
          title: Text(label),
          subtitle: field.hint == null ? null : Text(field.hint!),
        );

      case FieldType.select:
        // Une valeur enregistrée puis retirée des options ferait planter le
        // Dropdown : on la traite comme non renseignée.
        final current = values[field.key]?.toString();
        final safe = field.options.contains(current) ? current : null;

        return DropdownButtonFormField<String>(
          initialValue: safe,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.hint,
          ),
          items: field.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => _set(field.key, v),
          validator: (v) => field.required && (v == null || v.isEmpty)
              ? 'Ce champ est obligatoire'
              : null,
        );

      case FieldType.multiselect:
        final selected = (values[field.key] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];

        return _MultiSelectField(
          label: label,
          hint: field.hint,
          options: field.options,
          selected: selected,
          required: field.required,
          onChanged: (v) => _set(field.key, v),
        );

      case FieldType.date:
        final raw = values[field.key]?.toString();
        final date = raw == null ? null : DateTime.tryParse(raw);

        return _DateField(
          label: label,
          hint: field.hint,
          value: date,
          required: field.required,
          // ISO 8601 : triable comme chaîne et relisible sans ambiguïté.
          onChanged: (d) =>
              _set(field.key, d?.toIso8601String().split('T').first),
        );

      case FieldType.number:
        return TextFormField(
          initialValue: values[field.key]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: label,
            helperText: field.hint,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
          ],
          onChanged: (v) {
            final normalized = v.replaceAll(',', '.');
            _set(field.key, num.tryParse(normalized));
          },
          validator: (v) {
            if (field.required && (v ?? '').trim().isEmpty) {
              return 'Ce champ est obligatoire';
            }
            if ((v ?? '').trim().isNotEmpty &&
                num.tryParse(v!.replaceAll(',', '.')) == null) {
              return 'Nombre invalide';
            }
            return null;
          },
        );

      case FieldType.text:
      case FieldType.multiline:
      case FieldType.phone:
      case FieldType.url:
        return TextFormField(
          initialValue: values[field.key]?.toString() ?? '',
          decoration: InputDecoration(
            labelText: label,
            helperText: field.hint,
            prefixIcon: _prefixIconFor(field.type),
          ),
          keyboardType: _keyboardFor(field.type),
          maxLines: field.type == FieldType.multiline ? 4 : 1,
          onChanged: (v) => _set(field.key, v.trim().isEmpty ? null : v.trim()),
          validator: (v) => field.required && (v ?? '').trim().isEmpty
              ? 'Ce champ est obligatoire'
              : null,
        );
    }
  }

  static Widget? _prefixIconFor(FieldType type) {
    switch (type) {
      case FieldType.phone:
        return const Icon(Icons.phone);
      case FieldType.url:
        return const Icon(Icons.link);
      default:
        return null;
    }
  }

  static TextInputType _keyboardFor(FieldType type) {
    switch (type) {
      case FieldType.phone:
        return TextInputType.phone;
      case FieldType.url:
        return TextInputType.url;
      case FieldType.multiline:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }
}

class _MultiSelectField extends StatefulWidget {
  final String label;
  final String? hint;
  final List<String> options;
  final List<String> selected;
  final bool required;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    this.hint,
    required this.options,
    required this.selected,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_MultiSelectField> createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<_MultiSelectField> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [...widget.selected];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormField<List<String>>(
      initialValue: _selected,
      validator: (v) => widget.required && (v == null || v.isEmpty)
          ? 'Sélectionnez au moins une option'
          : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: theme.textTheme.bodyMedium),
            if (widget.hint != null)
              Text(widget.hint!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.options.map((option) {
                final isSelected = _selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selected.add(option);
                      } else {
                        _selected.remove(option);
                      }
                    });
                    state.didChange(_selected);
                    widget.onChanged(_selected);
                  },
                );
              }).toList(),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateField extends StatefulWidget {
  final String label;
  final String? hint;
  final DateTime? value;
  final bool required;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    this.hint,
    this.value,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  DateTime? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final text = _value == null
        ? 'Choisir une date'
        : '${_value!.day.toString().padLeft(2, '0')}/'
            '${_value!.month.toString().padLeft(2, '0')}/${_value!.year}';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        errorText: widget.required && _value == null
            ? 'Ce champ est obligatoire'
            : null,
      ),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _value ?? now,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 10),
          );
          if (picked != null) {
            setState(() => _value = picked);
            widget.onChanged(picked);
          }
        },
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}
