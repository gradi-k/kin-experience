// lib/widgets/schedule_picker_field.dart
//
// Widget réutilisable pour saisir des horaires structurés.
// Génère un format compatible avec le parser de detail_screen.dart :
//   "Lun-Ven: 9h-18h, Sam: 10h-14h"
//
// Utilisation :
//   SchedulePickerField(
//     controller: _scheduleController,
//   )

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Données statiques
// ─────────────────────────────────────────────────────────────

const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

List<String> _buildTimeSlots() {
  final slots = <String>[];
  for (int h = 0; h < 24; h++) {
    slots.add('${h}h');
    slots.add('${h}h30');
  }
  return slots;
}

final _timeSlots = _buildTimeSlots();

// ─────────────────────────────────────────────────────────────
// Modèle d'une entrée horaire
// ─────────────────────────────────────────────────────────────

class _ScheduleEntry {
  String dayFrom;
  String dayTo;
  String timeFrom;
  String timeTo;

  _ScheduleEntry({
    required this.dayFrom,
    required this.dayTo,
    required this.timeFrom,
    required this.timeTo,
  });

  /// Ex: "Lun-Ven: 9h-18h"  ou  "Sam: 10h-14h"
  String toScheduleString() {
    final dayPart = dayFrom == dayTo ? dayFrom : '$dayFrom-$dayTo';
    return '$dayPart: $timeFrom-$timeTo';
  }
}

// ─────────────────────────────────────────────────────────────
// Parser : string → List<_ScheduleEntry>
// ─────────────────────────────────────────────────────────────

List<_ScheduleEntry> _parseSchedule(String raw) {
  if (raw.trim().isEmpty) return [];

  final entries = <_ScheduleEntry>[];
  final parts = raw.split(RegExp(r'[,\n]+'));

  for (final part in parts) {
    final s = part.trim();
    if (s.isEmpty) continue;

    final colonIdx = s.indexOf(':');
    if (colonIdx < 0) continue;

    final dayPart  = s.substring(0, colonIdx).trim();
    final timePart = s.substring(colonIdx + 1).trim();

    // jours
    final dayTokens = dayPart.split(RegExp(r'[-–]'));
    final df = _closestDay(dayTokens.first.trim());
    final dt = dayTokens.length >= 2
        ? _closestDay(dayTokens[1].trim())
        : df;

    // horaires
    final timeTokens = timePart.split(RegExp(r'[-–]'));
    if (timeTokens.length < 2) continue;
    final tf = _closestTime(timeTokens[0].trim());
    final tt = _closestTime(timeTokens[1].trim());

    entries.add(_ScheduleEntry(dayFrom: df, dayTo: dt, timeFrom: tf, timeTo: tt));
  }
  return entries;
}

String _closestDay(String raw) {
  final lower = raw.toLowerCase();
  for (final d in _days) {
    if (lower.startsWith(d.toLowerCase())) return d;
  }
  return _days.first;
}

String _closestTime(String raw) {
  // normalise "9h", "9h00", "9h30", "09:00", "09:30" → slot
  final hRe = RegExp(r'^(\d{1,2})h(\d{0,2})$');
  final cRe = RegExp(r'^(\d{1,2}):(\d{2})$');

  final hm = hRe.firstMatch(raw);
  if (hm != null) {
    final h  = int.parse(hm.group(1)!);
    final m  = hm.group(2)!.isEmpty ? 0 : int.parse(hm.group(2)!);
    final slot = m >= 15 ? '${h}h30' : '${h}h';
    return _timeSlots.contains(slot) ? slot : '${h}h';
  }

  final cm = cRe.firstMatch(raw);
  if (cm != null) {
    final h  = int.parse(cm.group(1)!);
    final m  = int.parse(cm.group(2)!);
    final slot = m >= 15 ? '${h}h30' : '${h}h';
    return _timeSlots.contains(slot) ? slot : '${h}h';
  }

  return _timeSlots.first;
}

// ─────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────

class SchedulePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;

  const SchedulePickerField({
    super.key,
    required this.controller,
    this.label,
  });

  @override
  State<SchedulePickerField> createState() => _SchedulePickerFieldState();
}

class _SchedulePickerFieldState extends State<SchedulePickerField> {
  String get _currentValue => widget.controller.text;

  void _openPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SchedulePickerSheet(
        initialValue: widget.controller.text,
      ),
    );

    if (result != null) {
      widget.controller.text = result;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = _currentValue.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label ?? 'Horaires',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(12),
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : theme.cardColor,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasValue
                      ? _ScheduleChips(value: _currentValue)
                      : Text(
                    'Définir les horaires d\'ouverture',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.hintColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Affichage en chips de l'horaire courant
// ─────────────────────────────────────────────────────────────

class _ScheduleChips extends StatelessWidget {
  final String value;
  const _ScheduleChips({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = value.split(RegExp(r'[,\n]+')).where((s) => s.trim().isNotEmpty).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: parts.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            p.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom Sheet de saisie
// ─────────────────────────────────────────────────────────────

class _SchedulePickerSheet extends StatefulWidget {
  final String initialValue;

  const _SchedulePickerSheet({required this.initialValue});

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  late List<_ScheduleEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _parseSchedule(widget.initialValue);
    if (_entries.isEmpty) _addDefault();
  }

  void _addDefault() {
    _entries.add(_ScheduleEntry(
      dayFrom: 'Lun',
      dayTo: 'Ven',
      timeFrom: '8h',
      timeTo: '18h',
    ));
  }

  String _buildResult() {
    return _entries.map((e) => e.toScheduleString()).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Titre ──────────────────────────────────────
              Text(
                'Horaires d\'ouverture',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ajoutez un créneau par ligne de jours.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 16),

              // ── Liste des créneaux ─────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _EntryCard(
                    entry: _entries[i],
                    onChanged: () => setState(() {}),
                    onDelete: _entries.length > 1
                        ? () => setState(() => _entries.removeAt(i))
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Ajouter un créneau ─────────────────────────
              OutlinedButton.icon(
                onPressed: () => setState(() => _addDefault()),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un créneau'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Prévisualisation ───────────────────────────
              if (_entries.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.20),
                    ),
                  ),
                  child: Text(
                    _buildResult(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Valider ────────────────────────────────────
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_buildResult()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirmer',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Carte d'une entrée horaire (dropdowns)
// ─────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final _ScheduleEntry entry;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _EntryCard({
    required this.entry,
    required this.onChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey.shade50
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête carte ──────────────────────────────────
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Jours',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: theme.colorScheme.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Sélection des jours ────────────────────────────
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Du',
                  value: entry.dayFrom,
                  items: _days,
                  onChanged: (v) {
                    if (v != null) {
                      entry.dayFrom = v;
                      // si dayTo devient avant dayFrom, on aligne
                      final fi = _days.indexOf(v);
                      final ti = _days.indexOf(entry.dayTo);
                      if (ti < fi) entry.dayTo = v;
                      onChanged();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('au',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: _DropdownField(
                  label: 'Au',
                  value: entry.dayTo,
                  items: _days,
                  onChanged: (v) {
                    if (v != null) {
                      entry.dayTo = v;
                      onChanged();
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Horaires',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Sélection des heures ───────────────────────────
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Ouverture',
                  value: entry.timeFrom,
                  items: _timeSlots,
                  onChanged: (v) {
                    if (v != null) {
                      entry.timeFrom = v;
                      onChanged();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('à',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: _DropdownField(
                  label: 'Fermeture',
                  value: entry.timeTo,
                  items: _timeSlots,
                  onChanged: (v) {
                    if (v != null) {
                      entry.timeTo = v;
                      onChanged();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dropdown stylisé
// ─────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.bodySmall,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}