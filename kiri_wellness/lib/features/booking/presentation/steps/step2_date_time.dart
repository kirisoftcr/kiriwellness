import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../booking_page.dart';

final _availableSlotsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String date, String serviceId})>(
        (ref, args) async {
  return ref
      .watch(appointmentRepositoryProvider)
      .getAvailableSlots(date: args.date, serviceId: args.serviceId);
});

class Step2DateTime extends ConsumerStatefulWidget {
  const Step2DateTime({super.key});

  @override
  ConsumerState<Step2DateTime> createState() => _Step2DateTimeState();
}

class _Step2DateTimeState extends ConsumerState<Step2DateTime> {
  DateTime _focusedDay = DateTime.now();
  final _timeSlotsKey = GlobalKey();

  final _emailCtrl = TextEditingController();
  bool _lookingUp = false;
  bool _lookupDone = false;
  String? _lookupError;
  List<Map<String, dynamic>> _pendingRewards = [];
  Map<String, dynamic>? _selectedReward;
  String _foundClientId = '';

  @override
  void initState() {
    super.initState();
    final email = ref.read(bookingProvider).prefilledEmail ?? '';
    if (email.isNotEmpty) {
      _emailCtrl.text = email;
      // Auto-lookup so rewards appear without the user having to click Verificar
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupEmail());
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _scrollToTimeSlots() {
    final isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) return;
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

  Future<void> _lookupEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _lookupError = 'Ingresa un correo válido.');
      return;
    }
    setState(() {
      _lookingUp = true;
      _lookupError = null;
      _pendingRewards = [];
      _selectedReward = null;
    });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupClientByEmail')
          .call<Map<String, dynamic>>({'email': email});
      final data = result.data;
      if (data['found'] == true) {
        _foundClientId = data['clientId'] as String? ?? '';
        final rawRewards = data['pendingRewards'] as List? ?? [];
        final valid = rawRewards
            .map((r) => Map<String, dynamic>.from(r as Map))
            .where((r) {
          final expires = r['expiresAt'];
          if (expires != null && expires is Map) {
            final secs = (expires['_seconds'] as num?)?.toInt();
            if (secs != null &&
                DateTime.now().isAfter(
                    DateTime.fromMillisecondsSinceEpoch(secs * 1000))) {
              return false;
            }
          }
          return true;
        }).toList();
        if (mounted) setState(() => _pendingRewards = valid);
      }
    } catch (_) {
      // Non-critical
    } finally {
      if (mounted) {
        setState(() {
          _lookingUp = false;
          _lookupDone = true;
        });
        ref.read(bookingProvider.notifier).setPrefilledEmail(email);
      }
    }
  }

  String? get _effectiveServiceId =>
      _selectedReward?['serviceId'] as String? ??
      ref.read(bookingProvider).selectedService?.id;

  Future<void> _handleContinue() async {
    final booking = ref.read(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);

    if (_selectedReward != null) {
      final email = _emailCtrl.text.trim();
      final rewardServiceId =
          _selectedReward!['serviceId'] as String? ?? booking.selectedService!.id;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RewardOtpDialog(
          email: email,
          clientId: _foundClientId,
          reward: _selectedReward!,
          serviceId: rewardServiceId,
        ),
      );
      if (result != null && mounted) {
        notifier.submitWithClient(
          clientCode: result['clientCode'] as String,
          clientId: result['clientId'] as String,
          firstName: result['firstName'] as String,
          lastName: result['lastName'] as String,
          phone: result['phone'] as String,
          email: email,
          notes: '',
        );
      }
    } else {
      notifier.goToStep3();
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    final selectedDate = booking.selectedDate;
    final selectedTime = booking.selectedTime;
    final isWide = MediaQuery.of(context).size.width >= 800;

    final rewardServiceName = _selectedReward?['serviceName'] as String?;
    final serviceLabel = rewardServiceName ?? booking.selectedService?.name;
    final serviceDuration = booking.selectedService?.durationMinutes;
    final effectiveSvcId = _effectiveServiceId;
    final canContinue = selectedDate != null && selectedTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elige fecha y hora',
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          'Selecciona el día y la hora disponible para tu cita',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        _EmailLookupSection(
          emailCtrl: _emailCtrl,
          lookingUp: _lookingUp,
          lookupDone: _lookupDone,
          lookupError: _lookupError,
          pendingRewards: _pendingRewards,
          selectedReward: _selectedReward,
          onLookup: _lookupEmail,
          onRewardSelected: (reward) {
            final prevSvcId = _selectedReward?['serviceId'] as String?;
            final newSvcId = reward['serviceId'] as String?;
            setState(() {
              _selectedReward =
                  (_selectedReward != null && _selectedReward!['id'] == reward['id'])
                      ? null
                      : reward;
            });
            if (prevSvcId != newSvcId) {
              notifier.selectTime(const TimeOfDay(hour: 0, minute: 0));
            }
          },
        ),
        const SizedBox(height: 20),

        if (serviceLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _selectedReward != null
                  ? AppTheme.secondary.withValues(alpha: 0.12)
                  : AppTheme.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedReward != null
                      ? AppTheme.secondary.withValues(alpha: 0.5)
                      : AppTheme.primaryLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedReward != null
                      ? Icons.card_giftcard_outlined
                      : Icons.spa_outlined,
                  size: 18,
                  color: _selectedReward != null
                      ? AppTheme.secondary
                      : AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  serviceLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedReward != null
                          ? AppTheme.secondary
                          : AppTheme.primaryDark),
                ),
                if (_selectedReward != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('REGALÍA',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ] else if (serviceDuration != null) ...[
                  const SizedBox(width: 8),
                  Text('· $serviceDuration min',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),

        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _CalendarCard(
                focusedDay: _focusedDay,
                selectedDay: selectedDate,
                onDaySelected: (day) {
                  setState(() => _focusedDay = day);
                  notifier.selectDate(day);
                  notifier.selectTime(const TimeOfDay(hour: 0, minute: 0));
                },
              )),
              const SizedBox(width: 20),
              Expanded(
                child: _TimeSlotsCard(
                  selectedDate: selectedDate,
                  selectedTime: selectedTime,
                  serviceId: effectiveSvcId,
                  onTimeSelected: (time, _) => notifier.selectTime(time),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
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
              const SizedBox(height: 16),
              _TimeSlotsCard(
                key: _timeSlotsKey,
                selectedDate: selectedDate,
                selectedTime: selectedTime,
                serviceId: effectiveSvcId,
                onTimeSelected: (time, _) => notifier.selectTime(time),
              ),
            ],
          ),

        const SizedBox(height: 28),
        _BottomNav(
          canContinue: canContinue,
          onBack: notifier.back,
          onNext: _handleContinue,
          isReward: _selectedReward != null,
        ),
      ],
    );
  }
}

class _EmailLookupSection extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool lookingUp;
  final bool lookupDone;
  final String? lookupError;
  final List<Map<String, dynamic>> pendingRewards;
  final Map<String, dynamic>? selectedReward;
  final VoidCallback onLookup;
  final void Function(Map<String, dynamic>) onRewardSelected;

  const _EmailLookupSection({
    required this.emailCtrl,
    required this.lookingUp,
    required this.lookupDone,
    required this.lookupError,
    required this.pendingRewards,
    required this.selectedReward,
    required this.onLookup,
    required this.onRewardSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pendingRewards.isNotEmpty
                ? AppTheme.secondary.withValues(alpha: 0.5)
                : const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Tienes una regalía o paquete?',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primaryDark)),
          const SizedBox(height: 4),
          const Text('Ingresa tu correo para verificar',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => onLookup(),
                  decoration: InputDecoration(
                    hintText: 'tu@correo.com',
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: AppTheme.primary, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    errorText: lookupError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: lookingUp ? null : onLookup,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: lookingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verificar'),
              ),
            ],
          ),
          if (lookupDone && pendingRewards.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.card_giftcard_outlined, color: AppTheme.secondary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '¡Tienes ${pendingRewards.length} regal${pendingRewards.length == 1 ? 'ía' : 'ías'} disponible${pendingRewards.length == 1 ? '' : 's'}!',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pendingRewards.map((r) {
              final isSelected = selectedReward != null && selectedReward!['id'] == r['id'];
              final svcName = r['serviceName'] as String? ?? '';
              final desc = r['description'] as String? ?? '';
              return GestureDetector(
                onTap: () => onRewardSelected(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.secondary.withValues(alpha: 0.12)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? AppTheme.secondary : const Color(0xFFE0E0E0),
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.secondary : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(svcName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected ? AppTheme.secondary : AppTheme.textPrimary)),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(desc,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('SELECCIONADA',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (lookupDone && pendingRewards.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'No se encontraron regalías pendientes para este correo.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

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
        selectedDayPredicate: (d) => selectedDay != null && isSameDay(d, selectedDay!),
        onDaySelected: (selected, _) => onDaySelected(selected),
        enabledDayPredicate: (day) =>
            day.weekday != DateTime.sunday && !day.isBefore(now),
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primary),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          weekendStyle: TextStyle(color: AppTheme.error, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          disabledTextStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
          defaultTextStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          weekendTextStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _TimeSlotsCard extends ConsumerWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? serviceId;
  final void Function(TimeOfDay, String) onTimeSelected;

  const _TimeSlotsCard({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.serviceId,
    required this.onTimeSelected,
  });

  TimeOfDay _parse24(String slot) {
    final parts = slot.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatAmPm(String slot) {
    final parts = slot.split(':');
    int h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedDate == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined, color: AppTheme.primaryLight, size: 40),
              SizedBox(height: 12),
              Text('Selecciona una fecha primero',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (serviceId == null) return const SizedBox.shrink();

    final d = selectedDate!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final slotsAsync =
        ref.watch(_availableSlotsProvider((date: dateStr, serviceId: serviceId!)));
    final dateLabel = DateFormat("EEEE d 'de' MMMM", 'es').format(selectedDate!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primaryDark)),
          const SizedBox(height: 4),
          const Text('Horarios disponibles',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          slotsAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) =>
                Text('Error al cargar horarios: $e',
                    style: const TextStyle(color: AppTheme.error, fontSize: 13)),
            data: (slots) {
              if (slots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay horarios disponibles para este día.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((slot) {
                  final time = _parse24(slot);
                  final isSelected = selectedTime != null &&
                      selectedTime!.hour == time.hour &&
                      selectedTime!.minute == time.minute;
                  return _TimeChip(
                    label: _formatAmPm(slot),
                    selected: isSelected,
                    disabled: false,
                    onTap: () => onTimeSelected(time, slot),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _TimeChip({
    required this.label,
    required this.selected,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : disabled
                  ? const Color(0xFFF0F0F0)
                  : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : disabled
                    ? const Color(0xFFE0E0E0)
                    : AppTheme.primaryLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Colors.white
                : disabled
                    ? const Color(0xFFBBBBBB)
                    : AppTheme.textPrimary,
            decoration: disabled ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final bool canContinue;
  final bool isReward;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.canContinue,
    required this.onBack,
    required this.onNext,
    this.isReward = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onBack,
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
          onPressed: canContinue ? onNext : null,
          icon: Icon(isReward ? Icons.redeem_outlined : Icons.arrow_forward, size: 18),
          label: Text(isReward ? 'Canjear regalía' : 'Continuar'),
          style: FilledButton.styleFrom(
            backgroundColor: isReward ? AppTheme.secondary : AppTheme.primary,
            disabledBackgroundColor: AppTheme.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

enum _RwdOtpPhase { sending, verify, booking }

class _RewardOtpDialog extends ConsumerStatefulWidget {
  final String email;
  final String clientId;
  final Map<String, dynamic> reward;
  final String serviceId;

  const _RewardOtpDialog({
    required this.email,
    required this.clientId,
    required this.reward,
    required this.serviceId,
  });

  @override
  ConsumerState<_RewardOtpDialog> createState() => _RewardOtpDialogState();
}

class _RewardOtpDialogState extends ConsumerState<_RewardOtpDialog> {
  _RwdOtpPhase _phase = _RwdOtpPhase.sending;
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
    setState(() {
      _phase = _RwdOtpPhase.sending;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendVerificationCode')
          .call({'email': widget.email});
      if (mounted) setState(() => _phase = _RwdOtpPhase.verify);
    } catch (_) {
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
      final verifyResult = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyClientCode')
          .call<Map<String, dynamic>>({'email': widget.email, 'code': code});
      final clientId = verifyResult.data['clientId'] as String;
      final clientData = verifyResult.data['client'] as Map<String, dynamic>? ?? {};

      final booking = ref.read(bookingProvider);
      final date = booking.selectedDate!;
      final time = booking.selectedTime!;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createRewardAppointment')
          .call<Map<String, dynamic>>({
        'clientId': clientId,
        'rewardId': widget.reward['id'] as String,
        'serviceId': widget.serviceId,
        'serviceName': widget.reward['serviceName'] as String? ?? '',
        'date': dateStr,
        'time': timeStr,
      });

      if (mounted) {
        Navigator.of(context).pop({
          'clientCode': clientData['clientCode'] as String? ?? '',
          'clientId': clientId,
          'firstName': clientData['firstName'] as String? ??
              clientData['name'] as String? ?? '',
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
    final isBusy = _phase == _RwdOtpPhase.sending || _phase == _RwdOtpPhase.booking;
    final svcName = widget.reward['serviceName'] as String? ?? '';

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.card_giftcard_outlined, color: AppTheme.secondary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(svcName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.primaryDark)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (_phase == _RwdOtpPhase.sending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(color: AppTheme.secondary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Enviando código de verificación...',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else if (_phase == _RwdOtpPhase.booking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    CircularProgressIndicator(color: AppTheme.secondary, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Agendando tu cita con regalía...',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                )
              else ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Enviamos un código de 6 dígitos a '),
                      TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                              color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
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
                      fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Código',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.pin_outlined, color: AppTheme.secondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.secondary, width: 2),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verificar y canjear',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Reenviar código',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
