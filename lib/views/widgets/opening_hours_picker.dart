// lib/widgets/opening_hours_picker.dart
import 'package:flutter/material.dart';

class OpeningHoursPicker extends StatefulWidget {
  final Map<String, dynamic>? initialSchedule;
  final Function(Map<String, dynamic>) onScheduleChanged;

  const OpeningHoursPicker({
    super.key,
    this.initialSchedule,
    required this.onScheduleChanged,
  });

  @override
  State<OpeningHoursPicker> createState() => _OpeningHoursPickerState();
}

class _OpeningHoursPickerState extends State<OpeningHoursPicker> {
  static const List<String> _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  static const List<int> _hours = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  late Map<String, DaySchedule> _schedule;

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
  }

  void _initializeSchedule() {
    _schedule = {};

    if (widget.initialSchedule != null) {
      // Parse existing schedule
      for (final day in _days) {
        if (widget.initialSchedule!.containsKey(day)) {
          final data = widget.initialSchedule![day];
          _schedule[day] = DaySchedule.fromMap(data);
        } else {
          _schedule[day] = DaySchedule(isOpen: false);
        }
      }
    } else {
      // Initialize with default closed
      for (final day in _days) {
        _schedule[day] = DaySchedule(isOpen: false);
      }
    }
  }

  void _notifyChange() {
    final scheduleMap = <String, dynamic>{};
    for (final entry in _schedule.entries) {
      if (entry.value.isOpen) {
        scheduleMap[entry.key] = entry.value.toMap();
      }
    }
    widget.onScheduleChanged(scheduleMap);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._days.map((day) => _buildDayRow(day)),
      ],
    );
  }

  Widget _buildDayRow(String day) {
    final schedule = _schedule[day]!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: schedule.isOpen,
                  onChanged: (value) {
                    setState(() {
                      _schedule[day] = schedule.copyWith(isOpen: value ?? false);
                      _notifyChange();
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (schedule.isOpen)
                  TextButton(
                    onPressed: () => _showTimePickerDialog(day),
                    child: const Text('Modifier'),
                  ),
              ],
            ),
            if (schedule.isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTime(schedule.openHour!, schedule.openPeriod!)} - ${_formatTime(schedule.closeHour!, schedule.closePeriod!)}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(int hour, String period) {
    return '$hour:00 $period';
  }

  Future<void> _showTimePickerDialog(String day) async {
    final schedule = _schedule[day]!;

    int? openHour = schedule.openHour ?? 8;
    String? openPeriod = schedule.openPeriod ?? 'A.M';
    int? closeHour = schedule.closeHour ?? 6;
    String? closePeriod = schedule.closePeriod ?? 'P.M';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Horaires - $day'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Heure d\'ouverture',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: openHour,
                          items: _hours.map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text('$h'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              openHour = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(':00'),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: openPeriod,
                          items: const [
                            DropdownMenuItem(value: 'A.M', child: Text('A.M')),
                            DropdownMenuItem(value: 'P.M', child: Text('P.M')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              openPeriod = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Heure de fermeture',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: closeHour,
                          items: _hours.map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text('$h'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              closeHour = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(':00'),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: closePeriod,
                          items: const [
                            DropdownMenuItem(value: 'A.M', child: Text('A.M')),
                            DropdownMenuItem(value: 'P.M', child: Text('P.M')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              closePeriod = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _schedule[day] = DaySchedule(
                        isOpen: true,
                        openHour: openHour,
                        openPeriod: openPeriod,
                        closeHour: closeHour,
                        closePeriod: closePeriod,
                      );
                      _notifyChange();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class DaySchedule {
  final bool isOpen;
  final int? openHour;
  final String? openPeriod; // 'A.M' or 'P.M'
  final int? closeHour;
  final String? closePeriod;

  DaySchedule({
    required this.isOpen,
    this.openHour,
    this.openPeriod,
    this.closeHour,
    this.closePeriod,
  });

  DaySchedule copyWith({
    bool? isOpen,
    int? openHour,
    String? openPeriod,
    int? closeHour,
    String? closePeriod,
  }) {
    return DaySchedule(
      isOpen: isOpen ?? this.isOpen,
      openHour: openHour ?? this.openHour,
      openPeriod: openPeriod ?? this.openPeriod,
      closeHour: closeHour ?? this.closeHour,
      closePeriod: closePeriod ?? this.closePeriod,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOpen': isOpen,
      'openHour': openHour,
      'openPeriod': openPeriod,
      'closeHour': closeHour,
      'closePeriod': closePeriod,
    };
  }

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    return DaySchedule(
      isOpen: map['isOpen'] ?? false,
      openHour: map['openHour'],
      openPeriod: map['openPeriod'],
      closeHour: map['closeHour'],
      closePeriod: map['closePeriod'],
    );
  }

  /// Vérifie si l'établissement est ouvert à l'heure actuelle
  bool isCurrentlyOpen() {
    if (!isOpen) return false;
    if (openHour == null || openPeriod == null || closeHour == null || closePeriod == null) {
      return false;
    }

    final now = DateTime.now();
    final currentHour = now.hour;

    // Convert to 24h format
    int openHour24 = _to24Hour(openHour!, openPeriod!);
    int closeHour24 = _to24Hour(closeHour!, closePeriod!);

    // Handle overnight hours (e.g., 10 PM to 2 AM)
    if (closeHour24 < openHour24) {
      return currentHour >= openHour24 || currentHour < closeHour24;
    }

    return currentHour >= openHour24 && currentHour < closeHour24;
  }

  int _to24Hour(int hour, String period) {
    if (period == 'A.M') {
      return hour == 12 ? 0 : hour;
    } else {
      return hour == 12 ? 12 : hour + 12;
    }
  }
}

/// Helper pour vérifier si ouvert maintenant
class OpeningHoursHelper {
  static bool isOpenNow(Map<String, dynamic>? schedule) {
    if (schedule == null || schedule.isEmpty) return false;

    final now = DateTime.now();
    final dayNames = [
      '',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    final today = dayNames[now.weekday];

    if (!schedule.containsKey(today)) return false;

    final daySchedule = DaySchedule.fromMap(schedule[today]);
    return daySchedule.isCurrentlyOpen();
  }

  static String getStatusText(Map<String, dynamic>? schedule) {
    return isOpenNow(schedule) ? 'Ouvert' : 'Fermé';
  }

  static Color getStatusColor(Map<String, dynamic>? schedule) {
    return isOpenNow(schedule) ? Colors.green : Colors.red;
  }

  static String getTodayHours(Map<String, dynamic>? schedule) {
    if (schedule == null || schedule.isEmpty) return 'Horaires non disponibles';

    final now = DateTime.now();
    final dayNames = [
      '',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    final today = dayNames[now.weekday];

    if (!schedule.containsKey(today)) return 'Fermé aujourd\'hui';

    final daySchedule = DaySchedule.fromMap(schedule[today]);
    if (!daySchedule.isOpen) return 'Fermé aujourd\'hui';

    return '${daySchedule.openHour}:00 ${daySchedule.openPeriod} - ${daySchedule.closeHour}:00 ${daySchedule.closePeriod}';
  }
}