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
  bool _confirmDirectly = false;

  // Email lookup state
  final _emailLookupCtrl = TextEditingController();
  bool _lookingUp = false;
  bool _lookupDone = false;
  bool _isReturningClient = false;
  String _foundClientId = '';
  List<Map<String, dynamic>> _matchingPackages = [];
  List<Map<String, dynamic>> _matchingRewards = [];

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
        _foundClientId = data['clientId'] as String? ?? '';
        setState(() => _isReturningClient = true);
        // Async check for package sessions matching the selected service
        final serviceId = ref.read(bookingProvider).selectedService?.id ?? '';
        if (_foundClientId.isNotEmpty && serviceId.isNotEmpty) {
          _checkPackageSessions(_foundClientId, serviceId);
          // Use pending rewards returned directly by the CF (avoids auth
          // requirement on the client/{id}/rewards subcollection).
          final rawRewards = data['pendingRewards'] as List? ?? [];
          final allRewards = rawRewards
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          final matchingRewards = allRewards.where((r) {
            final rSvcId = r['serviceId'] as String?;
            final expires = r['expiresAt'];
            // Skip expired
            if (expires != null) {
              DateTime? expDate;
              if (expires is Map) {
                // Firestore Timestamp serialised as {_seconds, _nanoseconds}
                final secs = (expires['_seconds'] as num?)?.toInt();
                if (secs != null) expDate = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
              }
              if (expDate != null && DateTime.now().isAfter(expDate)) return false;
            }
            return rSvcId == null || rSvcId.isEmpty || rSvcId == serviceId;
          }).toList();
          if (mounted) setState(() => _matchingRewards = matchingRewards);
        }
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

  Future<void> _checkPackageSessions(String clientId, String serviceId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getClientPackages');
      final result =
          await callable.call<Map<String, dynamic>>({'clientId': clientId});
      final raw = result.data['packages'] as List? ?? [];
      final pkgs = raw.cast<Map<String, dynamic>>();
      final matching = pkgs.where((p) {
        if (p['status'] != 'active') return false;
        final services = p['services'] as List<dynamic>? ?? [];
        return services.any((s) {
          final svc = s as Map<String, dynamic>;
          final remaining =
              (svc['totalSessions'] as num? ?? 0).toInt() -
                  (svc['usedSessions'] as num? ?? 0).toInt();
          return svc['serviceId'] == serviceId && remaining > 0;
        });
      }).toList();
      if (mounted) setState(() => _matchingPackages = matching);
    } catch (_) {}
  }

  Future<void> _showPackageBookingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PackageOtpBookingDialog(
        email: _emailLookupCtrl.text.trim(),
        packages: _matchingPackages,
        serviceId: ref.read(bookingProvider).selectedService?.id ?? '',
      ),
    );
    if (result != null && mounted) {
      ref.read(bookingProvider.notifier).submitWithClient(
        clientCode: result['clientCode'] as String,
        clientId: result['clientId'] as String,
        firstName: result['firstName'] as String,
        lastName: result['lastName'] as String,
        phone: result['phone'] as String,
        email: result['email'] as String,
        notes: '',
      );
    }
  }

  Future<void> _showRewardBookingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RewardOtpBookingDialog(
        email: _emailLookupCtrl.text.trim(),
        rewards: _matchingRewards,
        serviceId: ref.read(bookingProvider).selectedService?.id ?? '',
      ),
    );
    if (result != null && mounted) {
      ref.read(bookingProvider.notifier).submitWithClient(
        clientCode: result['clientCode'] as String,
        clientId: result['clientId'] as String,
        firstName: result['firstName'] as String,
        lastName: result['lastName'] as String,
        phone: result['phone'] as String,
        email: result['email'] as String,
        notes: '',
      );
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
        if (_confirmDirectly) 'confirmDirectly': true,
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

          // Reward offer card — shown FIRST when client has pending rewards for this service
          if (_matchingRewards.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.card_giftcard_outlined,
                        color: AppTheme.secondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Tienes ${_matchingRewards.length} regal${_matchingRewards.length == 1 ? 'ía' : 'ías'} disponible${_matchingRewards.length == 1 ? '' : 's'}!',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.primaryDark),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Puedes usar una regalía para esta cita de forma completamente gratuita.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showRewardBookingDialog,
                      icon: const Icon(Icons.redeem_outlined, size: 16),
                      label: const Text('Canjear regalía'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'O continúa para reservar como cita normal.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // Package offer card — shown when client has sessions for this service
          if (_matchingPackages.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.card_giftcard_outlined,
                        color: AppTheme.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Tienes sesiones disponibles en tus paquetes!',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.primaryDark),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Puedes usar una sesión de tu paquete para esta cita en lugar de pagar individualmente.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showPackageBookingDialog,
                      icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                      label: const Text('Usar sesión del paquete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'O continúa para reservar como cita normal.',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
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
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _confirmDirectly,
            onChanged: (v) => setState(() => _confirmDirectly = v ?? false),
            title: const Text('Confirmar cita directamente',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text(
                'Tu cita quedará confirmada de inmediato sin paso adicional',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppTheme.primary,
          ),
          const SizedBox(height: 16),

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
// ─────────────────────────────────────────────────────────────────────────────
// Package OTP Booking Dialog
// Sends OTP → verifies → books appointment from package → returns client data
// ─────────────────────────────────────────────────────────────────────────────

enum _PkgOtpPhase { sending, verify, booking }

class _PackageOtpBookingDialog extends ConsumerStatefulWidget {
  final String email;
  final List<Map<String, dynamic>> packages;
  final String serviceId;

  const _PackageOtpBookingDialog({
    required this.email,
    required this.packages,
    required this.serviceId,
  });

  @override
  ConsumerState<_PackageOtpBookingDialog> createState() =>
      _PackageOtpBookingDialogState();
}

class _PackageOtpBookingDialogState
    extends ConsumerState<_PackageOtpBookingDialog> {
  _PkgOtpPhase _phase = _PkgOtpPhase.sending;
  final _otpCtrl = TextEditingController();
  late Map<String, dynamic> _selectedPackage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPackage = widget.packages.first;
    _sendOtp();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() { _phase = _PkgOtpPhase.sending; _error = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendVerificationCode');
      await callable.call({'email': widget.email});
      if (mounted) setState(() => _phase = _PkgOtpPhase.verify);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al enviar código. Intenta de nuevo.';
          _phase = _PkgOtpPhase.verify;
        });
      }
    }
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) return;
    setState(() { _phase = _PkgOtpPhase.booking; _error = null; });
    try {
      // Step 1: Verify OTP → get confirmed clientId
      final verifyCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyClientCode');
      final verifyResult = await verifyCallable.call<Map<String, dynamic>>(
          {'email': widget.email, 'code': code});
      final clientId = verifyResult.data['clientId'] as String;
      final clientData =
          verifyResult.data['client'] as Map<String, dynamic>? ?? {};

      // Step 2: Find service entry in selected package
      final services =
          (_selectedPackage['services'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      final svcEntry = services.firstWhere(
        (s) => s['serviceId'] == widget.serviceId,
        orElse: () => {},
      );

      // Step 3: Get booking date/time from booking provider
      final booking = ref.read(bookingProvider);
      final date = booking.selectedDate!;
      final time = booking.selectedTime!;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      // Step 4: Create appointment from package
      final bookCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createPackageAppointment');
      await bookCallable.call<Map<String, dynamic>>({
        'clientId': clientId,
        'clientPackageId': _selectedPackage['id'] as String,
        'serviceId': widget.serviceId,
        'serviceName': svcEntry.isNotEmpty
            ? svcEntry['serviceName'] as String? ?? booking.selectedService!.name
            : booking.selectedService!.name,
        'date': dateStr,
        'time': timeStr,
        'notes': '',
      });

      if (mounted) {
        Navigator.of(context).pop({
          'clientCode': clientData['clientCode'] as String? ?? '',
          'clientId': clientId,
          'firstName': clientData['firstName'] as String? ?? '',
          'lastName': clientData['lastName'] as String? ?? '',
          'phone': clientData['phone'] as String? ?? '',
          'email': widget.email,
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Error al procesar. Intenta de nuevo.';
          _phase = _PkgOtpPhase.verify;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _phase = _PkgOtpPhase.verify; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _phase == _PkgOtpPhase.sending || _phase == _PkgOtpPhase.booking;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.card_giftcard_outlined, color: AppTheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Usar sesión del paquete',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.primaryDark)),
                ),
                if (!isBusy)
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20)),
              ]),
              const Divider(height: 20),

              // Package selector (if multiple)
              if (widget.packages.length > 1) ...[
                const Text('Selecciona el paquete:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...widget.packages.map((p) {
                  final isSelected = p['id'] == _selectedPackage['id'];
                  return RadioListTile<String>(
                    value: p['id'] as String,
                    groupValue: _selectedPackage['id'] as String,
                    onChanged: isBusy
                        ? null
                        : (v) => setState(() => _selectedPackage =
                            widget.packages.firstWhere((x) => x['id'] == v)),
                    title: Text(p['packageName'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryDark
                                : AppTheme.textPrimary,
                            fontSize: 13)),
                    activeColor: AppTheme.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 8),
              ] else ...[
                // Single package info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(_selectedPackage['packageName'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.primaryDark)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // OTP section
              if (_phase == _PkgOtpPhase.sending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Enviando código de verificación...',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else if (_phase == _PkgOtpPhase.booking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Agendando tu cita...',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Enviamos un código de 6 dígitos a '),
                      TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Código',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.pin_outlined,
                        color: AppTheme.primary, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verificar y agendar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Reenviar código',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward OTP Booking Dialog
// Sends OTP → verifies → books appointment using reward → returns client data
// ─────────────────────────────────────────────────────────────────────────────

enum _RwdOtpPhase { sending, verify, booking }

class _RewardOtpBookingDialog extends ConsumerStatefulWidget {
  final String email;
  final List<Map<String, dynamic>> rewards;
  final String serviceId;

  const _RewardOtpBookingDialog({
    required this.email,
    required this.rewards,
    required this.serviceId,
  });

  @override
  ConsumerState<_RewardOtpBookingDialog> createState() =>
      _RewardOtpBookingDialogState();
}

class _RewardOtpBookingDialogState
    extends ConsumerState<_RewardOtpBookingDialog> {
  _RwdOtpPhase _phase = _RwdOtpPhase.sending;
  final _otpCtrl = TextEditingController();
  late Map<String, dynamic> _selectedReward;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedReward = widget.rewards.first;
    _sendOtp();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _phase = _RwdOtpPhase.sending;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendVerificationCode');
      await callable.call({'email': widget.email});
      if (mounted) setState(() => _phase = _RwdOtpPhase.verify);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al enviar código. Intenta de nuevo.';
          _phase = _RwdOtpPhase.verify;
        });
      }
    }
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) return;
    setState(() {
      _phase = _RwdOtpPhase.booking;
      _error = null;
    });
    try {
      // Step 1: Verify OTP → get confirmed clientId
      final verifyCallable =
          FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('verifyClientCode');
      final verifyResult = await verifyCallable.call<Map<String, dynamic>>(
          {'email': widget.email, 'code': code});
      final clientId = verifyResult.data['clientId'] as String;
      final clientData =
          verifyResult.data['client'] as Map<String, dynamic>? ?? {};

      // Step 2: Get booking date/time from booking provider
      final booking = ref.read(bookingProvider);
      final date = booking.selectedDate!;
      final time = booking.selectedTime!;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      // Step 3: Create appointment using reward
      final bookCallable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createRewardAppointment');
      await bookCallable.call<Map<String, dynamic>>({
        'clientId': clientId,
        'rewardId': _selectedReward['id'] as String,
        'serviceId': widget.serviceId,
        'serviceName': _selectedReward['serviceName'] as String? ??
            booking.selectedService!.name,
        'date': dateStr,
        'time': timeStr,
      });

      if (mounted) {
        Navigator.of(context).pop({
          'clientCode': clientData['clientCode'] as String? ?? '',
          'clientId': clientId,
          'firstName': clientData['firstName'] as String? ?? '',
          'lastName': clientData['lastName'] as String? ?? '',
          'phone': clientData['phone'] as String? ?? '',
          'email': widget.email,
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Error al procesar. Intenta de nuevo.';
          _phase = _RwdOtpPhase.verify;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _RwdOtpPhase.verify;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _phase == _RwdOtpPhase.sending || _phase == _RwdOtpPhase.booking;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.redeem_outlined, color: AppTheme.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Canjear regalía',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.primaryDark)),
                ),
                if (!isBusy)
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20)),
              ]),
              const Divider(height: 20),

              // Reward selector (if multiple)
              if (widget.rewards.length > 1) ...[
                const Text('Selecciona la regalía:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ...widget.rewards.map((r) {
                  final isSelected = r['id'] == _selectedReward['id'];
                  return RadioListTile<String>(
                    value: r['id'] as String,
                    groupValue: _selectedReward['id'] as String,
                    onChanged: isBusy
                        ? null
                        : (v) => setState(() => _selectedReward =
                            widget.rewards.firstWhere((x) => x['id'] == v)),
                    title: Text(r['serviceName'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryDark
                                : AppTheme.textPrimary,
                            fontSize: 13)),
                    subtitle: r['description'] != null &&
                            (r['description'] as String).isNotEmpty
                        ? Text(r['description'] as String,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary))
                        : null,
                    activeColor: AppTheme.secondary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.card_giftcard_outlined,
                        color: AppTheme.secondary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                        _selectedReward['serviceName'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.primaryDark)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // OTP section
              if (_phase == _RwdOtpPhase.sending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(
                        color: AppTheme.secondary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Enviando código de verificación...',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else if (_phase == _RwdOtpPhase.booking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(
                        color: AppTheme.secondary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Agendando tu cita con regalía...',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    children: [
                      const TextSpan(
                          text: 'Enviamos un código de 6 dígitos a '),
                      TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Código',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.pin_outlined,
                        color: AppTheme.secondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.secondary, width: 2),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verificar y canjear',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Reenviar código',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}