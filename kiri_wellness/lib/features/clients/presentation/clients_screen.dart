import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/models/client_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/service_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(clientsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Clientes',
              subtitle: 'Base de clientes registrados',
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, teléfono o código...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 24),
            stream.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text('Error al cargar clientes: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (clients) {
                final q = _search.toLowerCase();
                final filtered = _search.isEmpty
                    ? clients
                    : clients.where((c) {
                        return c.fullName.toLowerCase().contains(q) ||
                            c.phone.contains(q) ||
                            c.clientCode.toLowerCase().contains(q) ||
                            (c.email?.toLowerCase().contains(q) ?? false);
                      }).toList();

                if (clients.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Text(
                        'No hay clientes registrados todavía.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Text(
                        'No se encontraron clientes.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filtered.length} cliente${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...filtered.map(
                      (c) => _ClientTile(
                        key: ValueKey(c.id),
                        client: c,
                        onEdit: () => _openForm(context, c),
                        onDelete: () => _confirmDelete(context, c),
                        onNewAppointment: () => _openNewAppointment(context, c),
                      ),
                    ),
                    const SizedBox(height: 80), // space for FAB
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, ClientModel? client) async {
    await showDialog(
      context: context,
      builder: (_) => _ClientFormDialog(client: client),
    );
  }

  Future<void> _openNewAppointment(BuildContext context, ClientModel client) async {
    await showDialog(
      context: context,
      builder: (_) => _NewAppointmentDialog(client: client),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar cliente'),
        content: Text(
            '¿Seguro que deseas eliminar a ${client.fullName}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(clientRepositoryProvider).delete(client.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${client.fullName} eliminado')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ClientTile extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onNewAppointment;
  const _ClientTile(
      {super.key,
      required this.client,
      required this.onEdit,
      required this.onDelete,
      required this.onNewAppointment});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(client.fullName);
    final hasEmail = client.email != null && client.email!.isNotEmpty;
    final hasNotes = client.notes != null && client.notes!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.35),
              child: Text(
                initials,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          client.fullName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (client.clientCode.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            client.clientCode,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Phone
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: client.phone,
                  ),
                  // Email
                  if (hasEmail) ...[
                    const SizedBox(height: 3),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text: client.email!,
                    ),
                  ],
                  // Notes
                  if (hasNotes) ...[
                    const SizedBox(height: 3),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      text: client.notes!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Footer: date + actions
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Registrado ${_formatDate(client.createdAt)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      // Actions
                      _ActionBtn(
                        icon: Icons.calendar_month_outlined,
                        tooltip: 'Nueva cita',
                        color: AppTheme.primary,
                        onTap: onNewAppointment,
                      ),
                      const SizedBox(width: 2),
                      _ActionBtn(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar',
                        color: AppTheme.textSecondary,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 2),
                      _ActionBtn(
                        icon: Icons.delete_outline,
                        tooltip: 'Eliminar',
                        color: AppTheme.error,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit form dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ClientFormDialog extends ConsumerStatefulWidget {
  final ClientModel? client; // null = create
  const _ClientFormDialog({this.client});

  @override
  ConsumerState<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _lastNameCtrl = TextEditingController(text: c?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(clientRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.client!.id, {
          'name': _nameCtrl.text.trim(),
          'firstName': _nameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          'notes': _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        });
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEdit ? 'Editar cliente' : 'Nuevo cliente'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _nameCtrl,
                      label: 'Nombre *',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _lastNameCtrl,
                      label: 'Apellido *',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phoneCtrl,
                label: 'Teléfono *',
                keyboard: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emailCtrl,
                label: 'Correo electrónico',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _notesCtrl,
                label: 'Notas',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Appointment Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _NewAppointmentDialog extends ConsumerStatefulWidget {
  final ClientModel client;
  const _NewAppointmentDialog({required this.client});

  @override
  ConsumerState<_NewAppointmentDialog> createState() =>
      _NewAppointmentDialogState();
}

class _NewAppointmentDialogState
    extends ConsumerState<_NewAppointmentDialog> {
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
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
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
    if (_selectedService == null ||
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
            firstName: widget.client.name,
            lastName: widget.client.lastName,
            phone: widget.client.phone,
            email: widget.client.email,
            serviceId: _selectedService!.id,
            serviceName: _selectedService!.name,
            serviceDurationMin: _selectedService!.durationMinutes,
            servicePrice: _selectedService!.price,
            date: dateStr,
            time: _selectedTime!,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cita agendada para ${widget.client.fullName}'),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeServicesStreamProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: AppTheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nueva cita — ${widget.client.fullName}',
              style: const TextStyle(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...
                [
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
              // Service selector
              servicesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2)),
                error: (e, _) =>
                    Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
                data: (services) => DropdownButtonFormField<ServiceModel>(
                  value: _selectedService,
                  decoration: const InputDecoration(labelText: 'Servicio *'),
                  items: services
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('${s.name} (${s.durationMinutes} min)'),
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
              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha *'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? _formatDate(_selectedDate!)
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
              // Time slot selector
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
                  hint: Text(_selectedDate == null || _selectedService == null
                      ? 'Selecciona servicio y fecha primero'
                      : _slots.isEmpty
                          ? 'Sin horarios disponibles'
                          : 'Seleccionar hora'),
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
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.keyboard,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
