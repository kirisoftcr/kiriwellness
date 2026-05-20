import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/models/schedule_model.dart';
import '../../../data/repositories/schedule_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Horarios de atención',
              subtitle: 'Define los bloques horarios en los que ofreces servicios',
              action: FilledButton.icon(
                onPressed: () => _showScheduleDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo horario'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 28),
            const _ScheduleByDay(),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog(BuildContext context, WidgetRef ref,
      [ScheduleModel? schedule]) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          _ScheduleDialog(schedule: schedule, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule grouped by day
// ---------------------------------------------------------------------------

class _ScheduleByDay extends ConsumerWidget {
  const _ScheduleByDay();

  static const _dayOrder = [1, 2, 3, 4, 5, 6, 7];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(schedulesStreamProvider);

    return stream.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => Center(
        child: Text('Error al cargar horarios: $e',
            style: const TextStyle(color: AppTheme.error)),
      ),
      data: (schedules) {
        if (schedules.isEmpty) {
          return _EmptyState(
            onAdd: () => showDialog(
              context: context,
              builder: (_) => _ScheduleDialog(ref: ref),
            ),
          );
        }

        // Group by day
        final Map<int, List<ScheduleModel>> byDay = {};
        for (final s in schedules) {
          byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
        }

        return Column(
          children: _dayOrder
              .where((d) => byDay.containsKey(d))
              .map((day) => _DayCard(
                    day: day,
                    slots: byDay[day]!,
                    ref: ref,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day card
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  final int day;
  final List<ScheduleModel> slots;
  final WidgetRef ref;

  const _DayCard({
    required this.day,
    required this.slots,
    required this.ref,
  });

  static const _dayNames = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  static const _dayIcons = {
    1: Icons.looks_one_outlined,
    2: Icons.looks_two_outlined,
    3: Icons.looks_3_outlined,
    4: Icons.looks_4_outlined,
    5: Icons.looks_5_outlined,
    6: Icons.looks_6_outlined,
    7: Icons.looks_one_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final activeSlots = slots.where((s) => s.isActive).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _dayIcons[day] ?? Icons.calendar_today,
                    color: AppTheme.primaryDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayNames[day] ?? 'Día $day',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '$activeSlots bloque${activeSlots != 1 ? 's' : ''} activo${activeSlots != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add slot for this day
                IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _ScheduleDialog(
                      ref: ref,
                      preselectedDay: day,
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primary),
                  tooltip: 'Agregar bloque',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Slots
          ...slots.map((slot) => _SlotTile(slot: slot, ref: ref)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slot tile
// ---------------------------------------------------------------------------

class _SlotTile extends StatelessWidget {
  final ScheduleModel slot;
  final WidgetRef ref;

  const _SlotTile({required this.slot, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Time chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: slot.isActive
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: slot.isActive
                    ? AppTheme.primary.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: slot.isActive
                      ? AppTheme.primaryDark
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  slot.timeRange,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: slot.isActive
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Active toggle
          Switch(
            value: slot.isActive,
            activeColor: AppTheme.primary,
            onChanged: (val) async {
              try {
                await ref
                    .read(scheduleRepositoryProvider)
                    .setActive(slot.id, val);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                showDialog(
                  context: context,
                  builder: (_) =>
                      _ScheduleDialog(schedule: slot, ref: ref),
                );
              } else if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar',
                        style: TextStyle(color: Colors.red)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar horario'),
        content: Text(
            '¿Eliminar el bloque ${slot.timeRange} del ${slot.dayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(scheduleRepositoryProvider)
                    .delete(slot.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Horario eliminado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin horarios definidos',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega los bloques horarios en los que\nofreces tus servicios',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar horario'),
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / Edit dialog
// ---------------------------------------------------------------------------

class _ScheduleDialog extends StatefulWidget {
  final ScheduleModel? schedule;
  final WidgetRef ref;
  final int? preselectedDay;

  const _ScheduleDialog({
    this.schedule,
    required this.ref,
    this.preselectedDay,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  static const _days = [
    (1, 'Lunes'),
    (2, 'Martes'),
    (3, 'Miércoles'),
    (4, 'Jueves'),
    (5, 'Viernes'),
    (6, 'Sábado'),
    (7, 'Domingo'),
  ];

  late int _selectedDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _selectedDay = s?.dayOfWeek ?? widget.preselectedDay ?? 1;
    _startTime = s != null ? _parseTime(s.startTime) : const TimeOfDay(hour: 8, minute: 0);
    _endTime = s != null ? _parseTime(s.endTime) : const TimeOfDay(hour: 12, minute: 0);
    _isActive = s?.isActive ?? true;
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _isEditing => widget.schedule != null;

  bool get _timeValid {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_timeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('La hora de fin debe ser posterior a la hora de inicio')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = widget.ref.read(scheduleRepositoryProvider);
      if (_isEditing) {
        await repo.update(widget.schedule!.id, {
          'dayOfWeek': _selectedDay,
          'startTime': _formatTime(_startTime),
          'endTime': _formatTime(_endTime),
          'isActive': _isActive,
        });
      } else {
        await repo.create(ScheduleModel(
          id: '',
          dayOfWeek: _selectedDay,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          isActive: _isActive,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule,
                        color: AppTheme.primaryDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Editar horario' : 'Nuevo horario',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Day selector
              const Text('Día de la semana',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((d) {
                  final (dayNum, dayLabel) = d;
                  final selected = _selectedDay == dayNum;
                  return ChoiceChip(
                    label: Text(dayLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                    selected: selected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.background,
                    onSelected: (_) =>
                        setState(() => _selectedDay = dayNum),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Time pickers
              const Text('Horario',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TimePicker(
                      label: 'Inicio',
                      time: _startTime,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                  Expanded(
                    child: _TimePicker(
                      label: 'Fin',
                      time: _endTime,
                      onTap: () => _pickTime(false),
                      hasError: !_timeValid,
                    ),
                  ),
                ],
              ),
              if (!_timeValid) ...[
                const SizedBox(height: 6),
                const Text(
                  'La hora de fin debe ser posterior a la de inicio',
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),

              // Active toggle
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activo',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('El bloque estará disponible para reservas',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _loading || !_timeValid ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Guardar' : 'Crear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time picker widget
// ---------------------------------------------------------------------------

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool hasError;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
    this.hasError = false,
  });

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasError ? AppTheme.error : Colors.grey.shade300,
            width: hasError ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.background,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  _format(time),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
