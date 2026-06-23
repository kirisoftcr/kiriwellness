import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/repositories/gift_card_repository.dart';
import '../booking_page.dart';

// ---------------------------------------------------------------------------
// Available slots provider — autoDispose keeps slots fresh between bookings
// ---------------------------------------------------------------------------

final _availableSlotsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String date, String serviceId})>(
        (ref, args) async {
  return ref
      .watch(appointmentRepositoryProvider)
      .getAvailableSlots(date: args.date, serviceId: args.serviceId);
});

// ---------------------------------------------------------------------------
// Step 2 — Combined: client data + rewards/packages + date/time
// ---------------------------------------------------------------------------

class Step2DateTime extends ConsumerStatefulWidget {
  const Step2DateTime({super.key});

  @override
  ConsumerState<Step2DateTime> createState() => _Step2DateTimeState();
}

class _Step2DateTimeState extends ConsumerState<Step2DateTime> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _lookingUp = false;
  bool _lookupDone = false;
  bool _isReturningClient = false;
  String _foundClientId = '';
  List<Map<String, dynamic>> _pendingRewards = [];
  List<Map<String, dynamic>> _matchingPackages = [];
  Map<String, dynamic>? _selectedReward;
  Map<String, dynamic>? _selectedPackage;
  bool _submitting = false;
  bool _confirmDirectly = false;

  DateTime _focusedDay = DateTime.now();
  final _timeSlotsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final b = ref.read(bookingProvider);
    // Restore any previously entered data
    _nameCtrl.text = b.clientName;
    _lastNameCtrl.text = b.clientLastName;
    _phoneCtrl.text = b.clientPhone;
    _notesCtrl.text = b.notes;
    final email = b.prefilledEmail ?? b.clientEmail;
    if (email.isNotEmpty) {
      _emailCtrl.text = email;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupEmail());
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Email lookup ──────────────────────────────────────────────────────────

  Future<void> _lookupEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() {
      _lookingUp = true;
      _pendingRewards = [];
      _matchingPackages = [];
      _selectedReward = null;
      _selectedPackage = null;
      _isReturningClient = false;
    });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupClientByEmail')
          .call<Map<String, dynamic>>({'email': email});
      final data = result.data;
      if (data['found'] == true) {
        _foundClientId = data['clientId'] as String? ?? '';
        _nameCtrl.text = data['firstName'] as String? ?? _nameCtrl.text;
        _lastNameCtrl.text = data['lastName'] as String? ?? _lastNameCtrl.text;
        _phoneCtrl.text = data['phone'] as String? ?? _phoneCtrl.text;
        if (mounted) setState(() => _isReturningClient = true);

        // Load rewards — CF already filters by status=pending & expiresAt > now
        final rawRewards = data['pendingRewards'];
        final rewardsList = (rawRewards is List ? rawRewards : [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (mounted) setState(() => _pendingRewards = rewardsList);

        // Load packages (filtered to current service)
        if (_foundClientId.isNotEmpty) {
          _loadPackages(_foundClientId);
        }
      } else {
        if (mounted) setState(() => _isReturningClient = false);
      }
    } catch (_) {
      // Non-critical — client can still fill the form manually
    } finally {
      if (mounted) {
        setState(() { _lookingUp = false; _lookupDone = true; });
        ref.read(bookingProvider.notifier).setPrefilledEmail(email);
      }
    }
  }

  Future<void> _loadPackages(String clientId) async {
    final serviceId = ref.read(bookingProvider).selectedService?.id ?? '';
    if (serviceId.isEmpty) return;
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getClientPackages')
          .call<Map<String, dynamic>>({'clientId': clientId});
      final raw = result.data['packages'] as List? ?? [];
      final matching = raw.cast<Map<String, dynamic>>().where((p) {
        if (p['status'] != 'active') return false;
        final services = p['services'] as List<dynamic>? ?? [];
        return services.any((s) {
          final svc = s as Map<String, dynamic>;
          final remaining = (svc['totalSessions'] as num? ?? 0).toInt() -
              (svc['usedSessions'] as num? ?? 0).toInt();
          return svc['serviceId'] == serviceId && remaining > 0;
        });
      }).toList();
      if (mounted) setState(() => _matchingPackages = matching);
    } catch (_) {}
  }

  // ── Effective service (reward/package may override) ───────────────────────

  String? get _effectiveServiceId =>
      _selectedReward?['serviceId'] as String? ??
      ref.read(bookingProvider).selectedService?.id;

  String get _effectiveServiceName =>
      _selectedReward?['serviceName'] as String? ??
      ref.read(bookingProvider).selectedService?.name ?? '';

  // ── Scroll to time slots on mobile ───────────────────────────────────────

  void _scrollToTimeSlots() {
    if (MediaQuery.of(context).size.width >= 800) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _timeSlotsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.05);
      }
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final booking = ref.read(bookingProvider);
    if (booking.selectedDate == null || booking.selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona una fecha y hora primero.'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    if (_selectedReward != null) {
      await _submitReward();
    } else if (_selectedPackage != null) {
      await _submitPackage();
    } else {
      await _submitNormal();
    }
  }

  Future<void> _submitNormal() async {
    setState(() => _submitting = true);
    final booking = ref.read(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    try {
      final date = booking.selectedDate!;
      final time = booking.selectedTime!;
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final timeStr =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createBooking')
          .call<Map<String, dynamic>>({
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
      final appointmentId = data['appointmentId'] as String?;

      // Link gift card to the appointment (if one was applied)
      if (appointmentId != null &&
          booking.giftCardId != null &&
          booking.giftCardId!.isNotEmpty) {
        await ref.read(appointmentRepositoryProvider).linkGiftCard(
              appointmentId,
              giftCardId: booking.giftCardId!,
              giftCardCode: booking.giftCardCode!,
            );
      }

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
        if (e.code == 'already-exists') {
          // Slot taken — reset date/time
          ref.read(bookingProvider.notifier).selectDate(DateTime.now());
          ref.read(bookingProvider.notifier).selectTime(const TimeOfDay(hour: 0, minute: 0));
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'El horario ya no está disponible.'),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 4),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: AppTheme.error,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar la cita: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitReward() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(
        email: _emailCtrl.text.trim(),
        title: 'Canjear regalía',
        icon: Icons.redeem_outlined,
        iconColor: AppTheme.secondary,
        descriptionWidget: _RewardChip(reward: _selectedReward!),
        onVerified: (clientId, clientData) async {
          final booking = ref.read(bookingProvider);
          final date = booking.selectedDate!;
          final time = booking.selectedTime!;
          final dateStr =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          final timeStr =
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('createRewardAppointment')
              .call<Map<String, dynamic>>({
            'clientId': clientId,
            'rewardId': _selectedReward!['id'] as String,
            'serviceId': _selectedReward!['serviceId'] as String? ??
                booking.selectedService!.id,
            'serviceName': _selectedReward!['serviceName'] as String? ??
                booking.selectedService!.name,
            'date': dateStr,
            'time': timeStr,
          });
        },
      ),
    );
    if (result != null && mounted) {
      ref.read(bookingProvider.notifier).submitWithClient(
        clientCode: result['clientCode'] as String,
        clientId: result['clientId'] as String,
        firstName: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : result['firstName'] as String,
        lastName: _lastNameCtrl.text.trim().isNotEmpty
            ? _lastNameCtrl.text.trim()
            : result['lastName'] as String,
        phone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : result['phone'] as String,
        email: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
    }
  }

  Future<void> _submitPackage() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(
        email: _emailCtrl.text.trim(),
        title: 'Usar sesión del paquete',
        icon: Icons.card_giftcard_outlined,
        iconColor: AppTheme.primary,
        descriptionWidget: _PackageChip(pkg: _selectedPackage!),
        onVerified: (clientId, clientData) async {
          final booking = ref.read(bookingProvider);
          final date = booking.selectedDate!;
          final time = booking.selectedTime!;
          final dateStr =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          final timeStr =
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
          final services =
              (_selectedPackage!['services'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();
          final svcEntry = services.firstWhere(
            (s) => s['serviceId'] == booking.selectedService?.id,
            orElse: () => {},
          );
          await FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('createPackageAppointment')
              .call<Map<String, dynamic>>({
            'clientId': clientId,
            'clientPackageId': _selectedPackage!['id'] as String,
            'serviceId': booking.selectedService!.id,
            'serviceName': svcEntry.isNotEmpty
                ? svcEntry['serviceName'] as String? ??
                    booking.selectedService!.name
                : booking.selectedService!.name,
            'date': dateStr,
            'time': timeStr,
            'notes': '',
          });
        },
      ),
    );
    if (result != null && mounted) {
      ref.read(bookingProvider.notifier).submitWithClient(
        clientCode: result['clientCode'] as String,
        clientId: result['clientId'] as String,
        firstName: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : result['firstName'] as String,
        lastName: _lastNameCtrl.text.trim().isNotEmpty
            ? _lastNameCtrl.text.trim()
            : result['lastName'] as String,
        phone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : result['phone'] as String,
        email: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    final selectedDate = booking.selectedDate;
    final selectedTime = booking.selectedTime;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final effectiveSvcId = _effectiveServiceId;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus datos y fecha',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'Ingresa tus datos y elige el día y hora de tu cita',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // ── 1. Email lookup ───────────────────────────────────────────────
          _SectionLabel(label: 'Correo electrónico', icon: Icons.email_outlined),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (_) => _lookupEmail(),
                decoration: _inputDeco(
                  label: 'tu@correo.com',
                  icon: Icons.email_outlined,
                ),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _lookingUp ? null : _lookupEmail,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _lookingUp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Verificar'),
            ),
          ]),

          // Returning client banner
          if (_lookupDone && _isReturningClient) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryLight),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Bienvenida de vuelta! Hemos pre-llenado tus datos.',
                    style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // ── 2. Client form ────────────────────────────────────────────────
          _SectionLabel(label: 'Tus datos', icon: Icons.person_outline),
          const SizedBox(height: 10),
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _nameField()),
              const SizedBox(width: 14),
              Expanded(child: _lastNameField()),
            ])
          else ...[_nameField(), const SizedBox(height: 14), _lastNameField()],
          const SizedBox(height: 14),
          _phoneField(),
          const SizedBox(height: 20),

          // ── 3. Rewards ────────────────────────────────────────────────────
          if (_pendingRewards.isNotEmpty) ...[
            _SectionLabel(
              label: 'Tus regalías disponibles',
              icon: Icons.redeem_outlined,
              color: AppTheme.secondary,
            ),
            const SizedBox(height: 8),
            ..._pendingRewards.map((r) {
              final isSelected =
                  _selectedReward != null && _selectedReward!['id'] == r['id'];
              return _SelectableCard(
                selected: isSelected,
                selectedColor: AppTheme.secondary,
                icon: Icons.card_giftcard_outlined,
                title: r['serviceName'] as String? ?? '',
                subtitle: r['description'] as String?,
                badge: 'REGALÍA',
                badgeColor: AppTheme.secondary,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedReward = null;
                  } else {
                    _selectedReward = r;
                    _selectedPackage = null;
                  }
                  // Reset time when service changes
                  notifier.selectTime(const TimeOfDay(hour: 0, minute: 0));
                }),
              );
            }),
            const SizedBox(height: 12),
          ],

          // ── 4. Packages ───────────────────────────────────────────────────
          if (_matchingPackages.isNotEmpty) ...[
            _SectionLabel(
              label: 'Tus sesiones de paquete',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            ..._matchingPackages.map((p) {
              final isSelected =
                  _selectedPackage != null && _selectedPackage!['id'] == p['id'];
              return _SelectableCard(
                selected: isSelected,
                selectedColor: AppTheme.primary,
                icon: Icons.card_giftcard_outlined,
                title: p['packageName'] as String? ?? '',
                subtitle: _packageSubtitle(p),
                badge: 'PAQUETE',
                badgeColor: AppTheme.primary,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedPackage = null;
                  } else {
                    _selectedPackage = p;
                    _selectedReward = null;
                  }
                }),
              );
            }),
            const SizedBox(height: 12),
          ],

          // ── 5. Active service chip ────────────────────────────────────────
          _ServiceChip(
            name: _effectiveServiceName,
            isReward: _selectedReward != null,
            isPackage: _selectedPackage != null,
            durationMinutes: booking.selectedService?.durationMinutes,
          ),
          const SizedBox(height: 20),

          // ── 6. Calendar + time slots ──────────────────────────────────────
          _SectionLabel(label: 'Fecha y hora', icon: Icons.calendar_today_outlined),
          const SizedBox(height: 10),
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _CalendarCard(
                  focusedDay: _focusedDay,
                  selectedDay: selectedDate,
                  onDaySelected: (day) {
                    setState(() => _focusedDay = day);
                    notifier.selectDate(day);
                    notifier.selectTime(const TimeOfDay(hour: 0, minute: 0));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TimeSlotsCard(
                  selectedDate: selectedDate,
                  selectedTime: selectedTime,
                  serviceId: effectiveSvcId,
                  onTimeSelected: (time) => notifier.selectTime(time),
                ),
              ),
            ])
          else
            Column(children: [
              _CalendarCard(
                focusedDay: _focusedDay,
                selectedDay: selectedDate,
                onDaySelected: (day) {
                  setState(() => _focusedDay = day);
                  notifier.selectDate(day);
                  notifier.selectTime(const TimeOfDay(hour: 0, minute: 0));
                  _scrollToTimeSlots();
                },
              ),
              const SizedBox(height: 12),
              _TimeSlotsCard(
                key: _timeSlotsKey,
                selectedDate: selectedDate,
                selectedTime: selectedTime,
                serviceId: effectiveSvcId,
                onTimeSelected: (time) => notifier.selectTime(time),
              ),
            ]),
          const SizedBox(height: 20),

          // ── 7. Notes ──────────────────────────────────────────────────────
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDeco(
              label: 'Notas adicionales (opcional)',
              icon: Icons.note_outlined,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '* Recibirás la confirmación por WhatsApp o correo electrónico.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // ── 8. Gift card code ─────────────────────────────────────────────
          _GiftCardSection(
            onValidated: (code, id) =>
                ref.read(bookingProvider.notifier).setGiftCard(code: code, id: id),
            onCleared: () => ref.read(bookingProvider.notifier).clearGiftCard(),
          ),
          const SizedBox(height: 8),

          // ── 9. Confirm directly checkbox (admin) ─────────────────────────
          CheckboxListTile(
            value: _confirmDirectly,
            onChanged: (v) => setState(() => _confirmDirectly = v ?? false),
            title: const Text(
              'Confirmar cita directamente',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 16),

          // ── 9. Navigation ─────────────────────────────────────────────────
          Row(children: [
            OutlinedButton.icon(
              onPressed: notifier.back,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Atrás'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  : Icon(
                      _selectedReward != null
                          ? Icons.redeem_outlined
                          : _selectedPackage != null
                              ? Icons.card_giftcard_outlined
                              : Icons.check,
                      size: 18,
                    ),
              label: Text(_submitting
                  ? 'Guardando...'
                  : _selectedReward != null
                      ? 'Canjear regalía'
                      : _selectedPackage != null
                          ? 'Usar sesión'
                          : 'Solicitar cita'),
              style: FilledButton.styleFrom(
                backgroundColor: _selectedReward != null
                    ? AppTheme.secondary
                    : AppTheme.primary,
                disabledBackgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Form helpers ──────────────────────────────────────────────────────────

  String? _packageSubtitle(Map<String, dynamic> pkg) {
    final serviceId = ref.read(bookingProvider).selectedService?.id ?? '';
    final services = (pkg['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final svcEntry = services.firstWhere(
        (s) => s['serviceId'] == serviceId, orElse: () => {});
    if (svcEntry.isEmpty) return null;
    final remaining = (svcEntry['totalSessions'] as num? ?? 0).toInt() -
        (svcEntry['usedSessions'] as num? ?? 0).toInt();
    return "$remaining sesión${remaining == 1 ? '' : 'es'} disponible${remaining == 1 ? '' : 's'}";
  }

  Widget _nameField() => TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: _inputDeco(label: 'Nombre', icon: Icons.person_outline),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
      );

  Widget _lastNameField() => TextFormField(
        controller: _lastNameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: _inputDeco(label: 'Apellidos', icon: Icons.person_outline),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Ingresa tus apellidos' : null,
      );

  Widget _phoneField() => TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration:
            _inputDeco(label: 'Teléfono / WhatsApp', icon: Icons.phone_outlined),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'Por favor ingresa tu teléfono'
            : null,
      );

  InputDecoration _inputDeco({required String label, required IconData icon}) =>
      InputDecoration(
        labelText: label,
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

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionLabel({
    required this.label,
    required this.icon,
    this.color = AppTheme.primaryDark,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color)),
      ]);
}

// ---------------------------------------------------------------------------
// Selectable card (reward / package)
// ---------------------------------------------------------------------------

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final Color selectedColor;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.selected,
    required this.selectedColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.08)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? selectedColor : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? selectedColor : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? selectedColor
                              : AppTheme.textPrimary)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeColor, borderRadius: BorderRadius.circular(6)),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5)),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Service chip
// ---------------------------------------------------------------------------

class _ServiceChip extends StatelessWidget {
  final String name;
  final bool isReward;
  final bool isPackage;
  final int? durationMinutes;
  const _ServiceChip({
    required this.name,
    required this.isReward,
    required this.isPackage,
    this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReward ? AppTheme.secondary : AppTheme.primary;
    final bgColor = isReward
        ? AppTheme.secondary.withValues(alpha: 0.1)
        : AppTheme.primaryLight.withValues(alpha: 0.3);
    final borderColor = isReward
        ? AppTheme.secondary.withValues(alpha: 0.5)
        : AppTheme.primaryLight;
    final icon = isReward
        ? Icons.redeem_outlined
        : isPackage
            ? Icons.card_giftcard_outlined
            : Icons.spa_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(name,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color)),
        ),
        if (isReward || isPackage) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(isReward ? 'REGALÍA' : 'PAQUETE',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5)),
          ),
        ] else if (durationMinutes != null) ...[
          const SizedBox(width: 8),
          Text('· $durationMinutes min',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar card
// ---------------------------------------------------------------------------

class _CalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime) onDaySelected;

  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TableCalendar(
        firstDay: now,
        lastDay: now.add(const Duration(days: 90)),
        focusedDay: focusedDay,
        selectedDayPredicate: (d) =>
            selectedDay != null && isSameDay(d, selectedDay!),
        onDaySelected: (selected, _) => onDaySelected(selected),
        enabledDayPredicate: (day) =>
            day.weekday != DateTime.sunday && !day.isBefore(now),
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: AppTheme.primary),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: AppTheme.primary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          weekendStyle: TextStyle(color: AppTheme.error, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
              color: AppTheme.primaryLight, shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
          disabledTextStyle:
              const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
          defaultTextStyle:
              const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          weekendTextStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time slots card
// ---------------------------------------------------------------------------

class _TimeSlotsCard extends ConsumerWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? serviceId;
  final void Function(TimeOfDay) onTimeSelected;

  const _TimeSlotsCard({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.serviceId,
    required this.onTimeSelected,
  });

  TimeOfDay _parse(String slot) {
    final p = slot.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(String slot) {
    final p = slot.split(':');
    int h = int.parse(p[0]);
    final m = p[1];
    final period = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedDate == null || serviceId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8))),
        child: const Center(
          child: Column(children: [
            Icon(Icons.calendar_today_outlined,
                color: AppTheme.primaryLight, size: 36),
            SizedBox(height: 10),
            Text('Selecciona una fecha primero',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    final d = selectedDate!;
    final dateStr =
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final slotsAsync =
        ref.watch(_availableSlotsProvider((date: dateStr, serviceId: serviceId!)));
    final dateLabel =
        DateFormat("EEEE d 'de' MMMM", 'es_MX').format(selectedDate!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_capitalize(dateLabel),
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.primaryDark)),
        const SizedBox(height: 4),
        const Text('Horarios disponibles',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        slotsAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text('Error al cargar horarios: $e',
              style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          data: (slots) {
            if (slots.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No hay horarios disponibles para este día.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((slot) {
                final time = _parse(slot);
                final isSelected = selectedTime != null &&
                    selectedTime!.hour == time.hour &&
                    selectedTime!.minute == time.minute;
                return _TimeChip(
                  label: _fmt(slot),
                  selected: isSelected,
                  onTap: () => onTimeSelected(time),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TimeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.primaryLight),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : AppTheme.textPrimary)),
        ),
      );
}

// ---------------------------------------------------------------------------
// OTP Dialog — reusable for reward & package
// ---------------------------------------------------------------------------

typedef _OnVerifiedCallback = Future<void> Function(
    String clientId, Map<String, dynamic> clientData);

enum _OtpPhase { sending, verify, submitting }

class _RewardChip extends StatelessWidget {
  final Map<String, dynamic> reward;
  const _RewardChip({required this.reward});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.card_giftcard_outlined,
              color: AppTheme.secondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(reward['serviceName'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryDark))),
        ]),
      );
}

class _PackageChip extends StatelessWidget {
  final Map<String, dynamic> pkg;
  const _PackageChip({required this.pkg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(pkg['packageName'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryDark))),
        ]),
      );
}

class _OtpDialog extends StatefulWidget {
  final String email;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget descriptionWidget;
  final _OnVerifiedCallback onVerified;

  const _OtpDialog({
    required this.email,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.descriptionWidget,
    required this.onVerified,
  });

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  _OtpPhase _phase = _OtpPhase.sending;
  final _otpCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() { _phase = _OtpPhase.sending; _error = null; });
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendVerificationCode')
          .call({'email': widget.email});
      if (mounted) setState(() => _phase = _OtpPhase.verify);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Error al enviar código. Intenta de nuevo.';
          _phase = _OtpPhase.verify;
        });
      }
    }
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) return;
    setState(() { _phase = _OtpPhase.submitting; _error = null; });
    try {
      final verifyResult = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyClientCode')
          .call<Map<String, dynamic>>({'email': widget.email, 'code': code});
      final clientId = verifyResult.data['clientId'] as String;
      final clientData =
          verifyResult.data['client'] as Map<String, dynamic>? ?? {};
      await widget.onVerified(clientId, clientData);
      if (mounted) {
        Navigator.of(context).pop({
          'clientCode': clientData['clientCode'] as String? ?? '',
          'clientId': clientId,
          'firstName': clientData['firstName'] as String? ??
              clientData['name'] as String? ?? '',
          'lastName': clientData['lastName'] as String? ?? '',
          'phone': clientData['phone'] as String? ?? '',
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Error. Intenta de nuevo.';
          _phase = _OtpPhase.verify;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _phase = _OtpPhase.verify; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _phase == _OtpPhase.sending || _phase == _OtpPhase.submitting;
    final busyMsg = _phase == _OtpPhase.sending
        ? 'Enviando código de verificación...'
        : 'Procesando tu cita...';

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
              Row(children: [
                Icon(widget.icon, color: widget.iconColor),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.primaryDark))),
                if (!isBusy)
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20)),
              ]),
              const Divider(height: 20),
              widget.descriptionWidget,
              const SizedBox(height: 16),
              if (isBusy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(
                        color: widget.iconColor, strokeWidth: 2),
                    const SizedBox(height: 12),
                    Text(busyMsg,
                        style: const TextStyle(
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
                    prefixIcon: Icon(Icons.pin_outlined,
                        color: widget.iconColor, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: widget.iconColor, width: 2),
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
                    backgroundColor: widget.iconColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verificar y confirmar',
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
// ---------------------------------------------------------------------------
// Gift Card Section
// ---------------------------------------------------------------------------

class _GiftCardSection extends ConsumerStatefulWidget {
  final void Function(String code, String id) onValidated;
  final VoidCallback onCleared;

  const _GiftCardSection({
    required this.onValidated,
    required this.onCleared,
  });

  @override
  ConsumerState<_GiftCardSection> createState() => _GiftCardSectionState();
}

class _GiftCardSectionState extends ConsumerState<_GiftCardSection> {
  final _ctrl = TextEditingController();
  bool _expanded = false;
  bool _loading = false;
  bool _valid = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _valid = false;
    });
    try {
      final card =
          await ref.read(giftCardRepositoryProvider).validateCode(code);
      if (card != null) {
        setState(() => _valid = true);
        widget.onValidated(card.code, card.id);
      } else {
        setState(() => _error = 'Código no válido o ya fue utilizado');
        widget.onCleared();
      }
    } catch (e) {
      setState(() => _error = 'Error al validar el código');
      widget.onCleared();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _valid = false;
      _error = null;
    });
    widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _valid
                  ? AppTheme.success.withValues(alpha: 0.08)
                  : AppTheme.oliveLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _valid
                    ? AppTheme.success
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _valid
                      ? Icons.card_giftcard
                      : Icons.card_giftcard_outlined,
                  color: _valid ? AppTheme.success : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _valid
                        ? '✅ Tarjeta de regalo aplicada: ${_ctrl.text.trim().toUpperCase()}'
                        : '¿Tienes una tarjeta de regalo?',
                    style: TextStyle(
                      color: _valid
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          _valid ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (_valid)
                  GestureDetector(
                    onTap: _clear,
                    child: const Icon(Icons.close,
                        size: 18, color: AppTheme.textSecondary),
                  )
                else
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && !_valid) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'KIRI-XXXXXX',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _error,
                  prefixIcon: const Icon(Icons.qr_code_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _loading ? null : _validate,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Validar'),
            ),
          ]),
        ],
      ],
    );
  }
}