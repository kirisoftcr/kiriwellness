import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../booking_page.dart';

// Provider: available slots for a given (date, serviceId) pair
final _availableSlotsProvider =
    FutureProvider.family<List<String>, ({String date, String serviceId})>(
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

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToTimeSlots() {
    final isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _timeSlotsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    final selectedDate = booking.selectedDate;
    final selectedTime = booking.selectedTime;
    final isWide = MediaQuery.of(context).size.width >= 800;

    final canContinue = selectedDate != null && selectedTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elige fecha y hora', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          'Selecciona el día y la hora disponible para tu cita',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        // Service summary chip
        if (booking.selectedService != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.spa_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  booking.selectedService!.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 8),
                Text(
                  '· ${booking.selectedService!.durationMinutes} min',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CalendarCard(
                focusedDay: _focusedDay,
                selectedDay: selectedDate,
                onDaySelected: (day) {
                  setState(() => _focusedDay = day);
                  notifier.selectDate(day);
                  notifier.selectTime(
                    const TimeOfDay(hour: 0, minute: 0), // reset time on date change
                  );
                },
              )),
              const SizedBox(width: 20),
              Expanded(
                child: _TimeSlotsCard(
                  selectedDate: selectedDate,
                  selectedTime: selectedTime,
                  serviceId: booking.selectedService?.id,
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
                serviceId: booking.selectedService?.id,
                onTimeSelected: (time, _) => notifier.selectTime(time),
              ),
            ],
          ),

        const SizedBox(height: 28),
        _BottomNav(
          canContinue: canContinue,
          onBack: notifier.back,
          onNext: notifier.goToStep3,
        ),
      ],
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
    final firstDay = now;
    final lastDay = now.add(const Duration(days: 90));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TableCalendar(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: focusedDay,
        selectedDayPredicate: (d) =>
            selectedDay != null && isSameDay(d, selectedDay!),
        onDaySelected: (selected, focused) => onDaySelected(selected),
        enabledDayPredicate: (day) =>
            day.weekday != DateTime.sunday && !day.isBefore(now),
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
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
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
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
              Icon(Icons.calendar_today_outlined,
                  color: AppTheme.primaryLight, size: 40),
              SizedBox(height: 12),
              Text(
                'Selecciona una fecha primero',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (serviceId == null) {
      return const SizedBox.shrink();
    }

    final d = selectedDate!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final slotsAsync = ref.watch(
        _availableSlotsProvider((date: dateStr, serviceId: serviceId!)));

    final dateLabel =
        DateFormat('EEEE d \'de\' MMMM', 'es').format(selectedDate!);

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
          Text(
            dateLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 4),
          const Text('Horarios disponibles',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          slotsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              'Error al cargar horarios: $e',
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
            data: (slots) {
              if (slots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay horarios disponibles para este día.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
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

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.canContinue,
    required this.onBack,
    required this.onNext,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: canContinue ? onNext : null,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Continuar'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            disabledBackgroundColor: AppTheme.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
