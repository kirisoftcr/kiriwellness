import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../booking_page.dart';

class Step3ClientInfo extends ConsumerStatefulWidget {
  const Step3ClientInfo({super.key});

  @override
  ConsumerState<Step3ClientInfo> createState() => _Step3ClientInfoState();
}

class _Step3ClientInfoState extends ConsumerState<Step3ClientInfo> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;

  // Email lookup state
  final _emailLookupCtrl = TextEditingController();
  bool _lookingUp = false;
  bool _lookupDone = false;
  bool _isReturningClient = false;

  @override
  void initState() {
    super.initState();
    final b = ref.read(bookingProvider);
    _nameCtrl = TextEditingController(text: b.clientName);
    _lastNameCtrl = TextEditingController(text: b.clientLastName);
    _phoneCtrl = TextEditingController(text: b.clientPhone);
    _emailCtrl = TextEditingController(text: b.clientEmail);
    _notesCtrl = TextEditingController(text: b.notes);
    // If email already set (returning from back), skip lookup
    if (b.clientEmail.isNotEmpty) {
      _emailLookupCtrl.text = b.clientEmail;
      _lookupDone = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _emailLookupCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupEmail() async {
    final email = _emailLookupCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() => _lookingUp = true);
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "us-central1").httpsCallable('lookupClientByEmail');
      final result = await callable.call<Map<String, dynamic>>({'email': email});
      final data = result.data;
      if (data['found'] == true) {
        _nameCtrl.text = data['firstName'] as String? ?? '';
        _lastNameCtrl.text = data['lastName'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _emailCtrl.text = email;
        setState(() => _isReturningClient = true);
      } else {
        _emailCtrl.text = email;
        setState(() => _isReturningClient = false);
      }
    } catch (_) {
      // If function fails, just skip pre-fill
      _emailCtrl.text = email;
    } finally {
      if (mounted) setState(() { _lookingUp = false; _lookupDone = true; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final booking = ref.read(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);

    try {
      final date = booking.selectedDate!;
      final time = booking.selectedTime!;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      final callable =
          FirebaseFunctions.instanceFor(region: "us-central1").httpsCallable('createBooking');
      final result = await callable.call<Map<String, dynamic>>({
        'firstName': _nameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'serviceId': booking.selectedService!.id,
        'serviceName': booking.selectedService!.name,
        'serviceDurationMin': booking.selectedService!.durationMinutes,
        'servicePrice': booking.selectedService!.price,
        'date': dateStr,
        'time': timeStr,
        'notes': _notesCtrl.text.trim(),
      });

      final data = result.data;
      notifier.submitWithClient(
        clientCode: data['clientCode'] as String,
        clientId: data['clientId'] as String,
        firstName: _nameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        // If slot is no longer available, go back to date/time step
        if (e.code == 'already-exists') {
          ref.read(bookingProvider.notifier).back();
          ref.read(bookingProvider.notifier).back();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'El horario ya no está disponible.'),
              backgroundColor: AppTheme.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la cita: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;

    // Phase 1: email lookup
    if (!_lookupDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus datos', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            '¿Cuál es tu correo electrónico?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          _BookingSummary(booking: booking),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailLookupCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: _inputDecoration(
              label: 'Correo electrónico (opcional)',
              hint: 'tu@correo.com',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si ya has reservado antes, pre-llenaremos tus datos automáticamente.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: ref.read(bookingProvider.notifier).back,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Atrás'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _lookingUp ? null : _lookupEmail,
                icon: _lookingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(_lookingUp ? 'Buscando...' : 'Continuar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Phase 2: full form
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus datos', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'Necesitamos tus datos para confirmar la cita',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // Booking summary box
          _BookingSummary(booking: booking),
          const SizedBox(height: 16),
          if (_isReturningClient)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryLight),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Bienvenida de vuelta! Hemos pre-llenado tus datos.',
                      style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Form fields — name + lastName side by side on wide
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _nameField()),
                const SizedBox(width: 16),
                Expanded(child: _lastNameField()),
              ],
            )
          else ...[_nameField(), const SizedBox(height: 16), _lastNameField()],

          const SizedBox(height: 16),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _phoneField()),
                const SizedBox(width: 16),
                Expanded(child: _emailField()),
              ],
            )
          else ...[_phoneField(), const SizedBox(height: 16), _emailField()],
          const SizedBox(height: 16),
          _notesField(),
          const SizedBox(height: 8),
          Text(
            '* Recibirás la confirmación por WhatsApp o correo electrónico.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: ref.read(bookingProvider.notifier).back,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Atrás'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label:
                    Text(_submitting ? 'Guardando...' : 'Solicitar cita'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        label: 'Nombre',
        hint: 'Ej. María',
        icon: Icons.person_outline,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
    );
  }

  Widget _lastNameField() {
    return TextFormField(
      controller: _lastNameCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        label: 'Apellidos',
        hint: 'Ej. González Pérez',
        icon: Icons.person_outline,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingresa tus apellidos' : null,
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      decoration: _inputDecoration(
        label: 'Teléfono / WhatsApp',
        hint: '+506 8888 8888',
        icon: Icons.phone_outlined,
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Por favor ingresa tu teléfono'
          : null,
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      decoration: _inputDecoration(
        label: 'Correo electrónico (opcional)',
        hint: 'tu@correo.com',
        icon: Icons.email_outlined,
      ),
      validator: (v) {
        if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
          return 'Por favor ingresa un correo válido';
        }
        return null;
      },
    );
  }

  Widget _notesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(
        label: 'Notas adicionales (opcional)',
        hint: 'Ej. Tengo alergia a ciertos aceites, zona de mayor tensión...',
        icon: Icons.note_outlined,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking summary
// ---------------------------------------------------------------------------

class _BookingSummary extends StatelessWidget {
  final BookingState booking;
  const _BookingSummary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateLabel = booking.selectedDate != null
        ? DateFormat('EEEE d \'de\' MMMM yyyy', 'es')
            .format(booking.selectedDate!)
        : '—';
    final timeLabel = booking.selectedTime != null
        ? booking.selectedTime!.format(context)
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen de tu cita',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
          const Divider(height: 16),
          _SummaryRow(
              icon: Icons.spa_outlined,
              label: booking.selectedService?.name ?? '—'),
          const SizedBox(height: 8),
          _SummaryRow(
              icon: Icons.calendar_today_outlined,
              label: _capitalize(dateLabel)),
          const SizedBox(height: 8),
          _SummaryRow(icon: Icons.schedule, label: timeLabel),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.attach_money,
            label: '₡${booking.selectedService?.price.toStringAsFixed(0) ?? '—'}  ·  ${booking.selectedService?.durationMinutes ?? '—'} min',
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ),
      ],
    );
  }
}
