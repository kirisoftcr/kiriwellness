import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/calendar_helper.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../shared/models/appointment_model.dart';
import '../../../shared/models/client_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/widgets/section_header.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = _selectedDay != null
        ? ref.watch(appointmentsByDateProvider(_dateStr(_selectedDay!)))
        : ref.watch(upcomingAppointmentsStreamProvider);

    final allAsync = ref.watch(allAppointmentsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _NewAppointmentDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Citas',
              subtitle: 'Gestiona el calendario de citas',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: allAsync.when(
                  loading: () => TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2027, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (f) => setState(() => _calendarFormat = f),
                    calendarStyle: _calStyle(),
                    headerStyle: _headerStyle(),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (all) {
                    final dateMap = <String, int>{};
                    for (final a in all) {
                      dateMap[a.date] = (dateMap[a.date] ?? 0) + 1;
                    }
                    return TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2027, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (d) =>
                          _selectedDay != null && isSameDay(_selectedDay, d),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
                          _focusedDay = focused;
                        });
                      },
                      onFormatChanged: (f) => setState(() => _calendarFormat = f),
                      calendarStyle: _calStyle(),
                      headerStyle: _headerStyle(),
                      eventLoader: (day) {
                        final count = dateMap[_dateStr(day)] ?? 0;
                        return List.filled(count.clamp(0, 3), '');
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedDay != null ? _formatDate(_selectedDay!) : 'Próximas citas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: AppTheme.error)),
              data: (apts) {
                if (apts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No hay citas para este período.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  );
                }
                return Column(
                  children: apts.map((a) => _AppointmentCard(key: ValueKey(a.id), appointment: a)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final s = DateFormat("EEEE d 'de' MMMM yyyy", 'es').format(date);
    return s[0].toUpperCase() + s.substring(1);
  }

  CalendarStyle _calStyle() => CalendarStyle(
        selectedDecoration: const BoxDecoration(
            color: AppTheme.primary, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.6),
            shape: BoxShape.circle),
        markerDecoration: const BoxDecoration(
            color: AppTheme.secondary, shape: BoxShape.circle),
      );

  HeaderStyle _headerStyle() => HeaderStyle(
        formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary),
            borderRadius: BorderRadius.circular(12)),
        formatButtonTextStyle: const TextStyle(color: AppTheme.primary),
      );
}

class _AppointmentCard extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  const _AppointmentCard({super.key, required this.appointment});

  @override
  ConsumerState<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<_AppointmentCard> {
  bool _updating = false;

  Future<void> _updateStatus(AppointmentStatus status) async {
    setState(() => _updating = true);
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .updateStatus(widget.appointment.id, status);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.appointment;
    String dateLabel = apt.date;
    try {
      final d = DateFormat('yyyy-MM-dd').parse(apt.date);
      final s = DateFormat('EEE d MMM yyyy', 'es').format(d);
      dateLabel = s[0].toUpperCase() + s.substring(1);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.fullClientName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(apt.serviceName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary)),
                      Text('$dateLabel · ${apt.time}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _StatusBadge(apt.status),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  tooltip: 'Agregar al calendario',
                  color: AppTheme.textSecondary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showAddToCalendar(
                    context,
                    id: apt.id,
                    serviceName: apt.serviceName,
                    date: apt.date,
                    time: apt.time,
                    durationMin: apt.serviceDurationMin,
                  ),
                ),
              ],
            ),
            if (apt.status != AppointmentStatus.cancelled &&
                apt.status != AppointmentStatus.completed) ...[
              const SizedBox(height: 12),
              if (_updating)
                const Center(child: SizedBox(
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Wrap(
                  spacing: 8,
                  children: [
                    if (apt.status == AppointmentStatus.requested)
                      _ActionBtn(
                        label: 'Confirmar',
                        color: const Color(0xFF2E7D32),
                        icon: Icons.check_circle_outline,
                        onTap: () => _updateStatus(AppointmentStatus.confirmed),
                      ),
                    _ActionBtn(
                      label: 'Completar',
                      color: AppTheme.primary,
                      icon: Icons.done_all,
                      onTap: () => _updateStatus(AppointmentStatus.completed),
                    ),
                    _ActionBtn(
                      label: 'Cancelar',
                      color: AppTheme.error,
                      icon: Icons.cancel_outlined,
                      onTap: () => _updateStatus(AppointmentStatus.cancelled),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      AppointmentStatus.requested => (AppTheme.primary, AppTheme.primaryLight.withValues(alpha: 0.3)),
      AppointmentStatus.confirmed => (const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      AppointmentStatus.cancelled => (AppTheme.error, const Color(0xFFFFEBEE)),
      AppointmentStatus.completed => (AppTheme.textSecondary, const Color(0xFFF5F5F5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Appointment Dialog (admin)
// ─────────────────────────────────────────────────────────────────────────────

class _NewAppointmentDialog extends ConsumerStatefulWidget {
  const _NewAppointmentDialog();

  @override
  ConsumerState<_NewAppointmentDialog> createState() =>
      _NewAppointmentDialogState();
}

class _NewAppointmentDialogState
    extends ConsumerState<_NewAppointmentDialog> {
  // Step 1: client search
  final _searchCtrl = TextEditingController();
  ClientModel? _selectedClient;

  // Step 2: service / date / time
  ServiceModel? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTime;
  final _notesCtrl = TextEditingController();

  bool _loadingSlots = false;
  List<String> _slots = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
      _slots = [];
    });
    if (_selectedService != null) await _loadSlots();
  }

  Future<void> _loadSlots() async {
    if (_selectedDate == null || _selectedService == null) return;
    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    setState(() {
      _loadingSlots = true;
      _slots = [];
      _selectedTime = null;
    });
    try {
      final slots = await ref
          .read(appointmentRepositoryProvider)
          .getAvailableSlots(date: dateStr, serviceId: _selectedService!.id);
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } catch (e) {
      setState(() {
        _loadingSlots = false;
        _error = 'Error al cargar horarios: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedClient == null ||
        _selectedService == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      setState(() => _error = 'Completa todos los campos requeridos.');
      return;
    }
    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(appointmentRepositoryProvider).createBooking(
            firstName: _selectedClient!.name,
            lastName: _selectedClient!.lastName,
            phone: _selectedClient!.phone,
            email: _selectedClient!.email,
            serviceId: _selectedService!.id,
            serviceName: _selectedService!.name,
            serviceDurationMin: _selectedService!.durationMinutes,
            servicePrice: _selectedService!.price,
            date: dateStr,
            time: _selectedTime!,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Cita agendada para ${_selectedClient!.fullName}'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsStreamProvider);
    final servicesAsync = ref.watch(activeServicesStreamProvider);

    // Filtered client list for search
    final allClients = clientsAsync.valueOrNull ?? [];
    final q = _searchCtrl.text.toLowerCase();
    final filteredClients = q.isEmpty
        ? allClients
        : allClients.where((c) {
            return c.fullName.toLowerCase().contains(q) ||
                c.phone.contains(q) ||
                c.clientCode.toLowerCase().contains(q);
          }).toList();

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: AppTheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Nueva cita', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[  
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: AppTheme.error)),
                ),
                const SizedBox(height: 12),
              ],

              // ── Client picker ───────────────────────────────────────────
              const Text('Cliente *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (_selectedClient != null)
                _SelectedChip(
                  label:
                      '${_selectedClient!.fullName}  ·  ${_selectedClient!.clientCode}',
                  onClear: () => setState(() {
                    _selectedClient = null;
                    _searchCtrl.clear();
                  }),
                )
              else ...[  
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, teléfono o código...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),
                if (clientsAsync.isLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredClients.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = filteredClients[i];
                        return InkWell(
                          onTap: () => setState(() {
                            _selectedClient = c;
                            _searchCtrl.clear();
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(c.fullName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ),
                                Text(c.clientCode,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              // ── Service ─────────────────────────────────────────────────
              servicesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2)),
                error: (e, _) => Text('Error: $e',
                    style:
                        const TextStyle(color: AppTheme.error)),
                data: (services) =>
                    DropdownButtonFormField<ServiceModel>(
                  value: _selectedService,
                  decoration:
                      const InputDecoration(labelText: 'Servicio *'),
                  items: services
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                '${s.name} (${s.durationMinutes} min)'),
                          ))
                      .toList(),
                  onChanged: (s) {
                    setState(() {
                      _selectedService = s;
                      _selectedTime = null;
                      _slots = [];
                    });
                    if (s != null && _selectedDate != null) _loadSlots();
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── Date ────────────────────────────────────────────────────
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Fecha *'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? _fmtDate(_selectedDate!)
                              : 'Seleccionar fecha',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Time slot ───────────────────────────────────────────────
              if (_loadingSlots)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2),
                ))
              else
                DropdownButtonFormField<String>(
                  value: _selectedTime,
                  decoration: const InputDecoration(labelText: 'Hora *'),
                  hint: Text(
                    _selectedDate == null || _selectedService == null
                        ? 'Selecciona servicio y fecha primero'
                        : _slots.isEmpty
                            ? 'Sin horarios disponibles'
                            : 'Seleccionar hora',
                  ),
                  items: _slots
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: _slots.isEmpty
                      ? null
                      : (t) => setState(() => _selectedTime = t),
                ),
              const SizedBox(height: 12),

              // ── Notes ───────────────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notas (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Agendar cita'),
        ),
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _SelectedChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(4),
            child: const Icon(Icons.close,
                size: 16, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
