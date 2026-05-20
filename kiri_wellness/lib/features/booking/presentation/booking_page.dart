import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/service_model.dart';
import 'steps/step1_service_selection.dart';
import 'steps/step2_date_time.dart';
import 'steps/step3_client_info.dart';
import 'steps/step4_confirmation.dart';

// ---------------------------------------------------------------------------
// Booking state
// ---------------------------------------------------------------------------

class BookingState {
  final int step;
  final ServiceModel? selectedService;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String clientName;
  final String clientLastName;
  final String clientPhone;
  final String clientEmail;
  final String notes;
  final bool submitted;
  final String? clientCode; // KW-XXXXX assigned after submission
  final String? clientId;  // Firestore document ID

  const BookingState({
    this.step = 0,
    this.selectedService,
    this.selectedDate,
    this.selectedTime,
    this.clientName = '',
    this.clientLastName = '',
    this.clientPhone = '',
    this.clientEmail = '',
    this.notes = '',
    this.submitted = false,
    this.clientCode,
    this.clientId,
  });

  BookingState copyWith({
    int? step,
    ServiceModel? selectedService,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    String? clientName,
    String? clientLastName,
    String? clientPhone,
    String? clientEmail,
    String? notes,
    bool? submitted,
    String? clientCode,
    String? clientId,
  }) {
    return BookingState(
      step: step ?? this.step,
      selectedService: selectedService ?? this.selectedService,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      clientName: clientName ?? this.clientName,
      clientLastName: clientLastName ?? this.clientLastName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      notes: notes ?? this.notes,
      submitted: submitted ?? this.submitted,
      clientCode: clientCode ?? this.clientCode,
      clientId: clientId ?? this.clientId,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier() : super(const BookingState());

  void selectService(ServiceModel service) =>
      state = state.copyWith(selectedService: service, step: 1);

  void selectDate(DateTime date) =>
      state = state.copyWith(selectedDate: date);

  void selectTime(TimeOfDay time) =>
      state = state.copyWith(selectedTime: time);

  void goToStep3() => state = state.copyWith(step: 2);

  void updateClientInfo({
    String? name,
    String? lastName,
    String? phone,
    String? email,
    String? notes,
  }) {
    state = state.copyWith(
      clientName: name ?? state.clientName,
      clientLastName: lastName ?? state.clientLastName,
      clientPhone: phone ?? state.clientPhone,
      clientEmail: email ?? state.clientEmail,
      notes: notes ?? state.notes,
    );
  }

  void submitWithClient({
    required String clientCode,
    required String clientId,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String notes,
  }) =>
      state = state.copyWith(
        step: 3,
        submitted: true,
        clientCode: clientCode,
        clientId: clientId,
        clientName: firstName,
        clientLastName: lastName,
        clientPhone: phone,
        clientEmail: email,
        notes: notes,
      );

  void submit() => state = state.copyWith(step: 3, submitted: true);

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1);
  }

  void reset() => state = const BookingState();
}

final bookingProvider =
    StateNotifierProvider<BookingNotifier, BookingState>(
  (ref) => BookingNotifier(),
);

// ---------------------------------------------------------------------------
// Booking page
// ---------------------------------------------------------------------------

class BookingPage extends ConsumerWidget {
  const BookingPage({super.key});

  static const _stepLabels = ['Servicio', 'Fecha y hora', 'Tus datos', 'Confirmación'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            pinned: true,
            expandedHeight: isWide ? 140 : 110,
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(isWide: isWide),
            ),
          ),
          // Progress stepper
          if (booking.step < 3)
            SliverToBoxAdapter(
              child: _StepIndicator(
                currentStep: booking.step,
                labels: _stepLabels,
              ),
            ),
          // Step content
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 800 : double.infinity),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 24 : 16,
                    vertical: 24,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStep(booking.step, ref),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int step, WidgetRef ref) {
    switch (step) {
      case 0:
        return const Step1ServiceSelection(key: ValueKey(0));
      case 1:
        return const Step2DateTime(key: ValueKey(1));
      case 2:
        return const Step3ClientInfo(key: ValueKey(2));
      case 3:
        return const Step4Confirmation(key: ValueKey(3));
      default:
        return const Step1ServiceSelection(key: ValueKey(0));
    }
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final bool isWide;
  const _Header({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.fromLTRB(24, isWide ? 28 : 36, 24, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/kiri_logo.jpeg',
                height: isWide ? 72 : 54,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: isWide ? 72 : 54,
                  height: isWide ? 72 : 54,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.spa, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KIRI',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: isWide ? 28 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppTheme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'WELLNESS',
                    style: TextStyle(
                      fontSize: isWide ? 13 : 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 5,
                      color: AppTheme.textSecondary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '· tu pausa perfecta ·',
                    style: TextStyle(
                      fontSize: isWide ? 11 : 10,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: TextButton.icon(
              onPressed: () => context.push('/my-appointments'),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: Text(isWide ? 'Ver mis citas' : 'Mis citas',
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const _StepIndicator({required this.currentStep, required this.labels});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 16,
        vertical: 16,
      ),
      child: Row(
        children: List.generate(labels.length - 1, (i) {
          // Only show steps 0-2 in the indicator (step 3 is confirmation)
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Row(
              children: [
                _StepDot(index: i, active: active, done: done),
                if (isWide) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: active
                            ? AppTheme.primary
                            : done
                                ? AppTheme.primaryDark
                                : AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (i < labels.length - 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: done ? AppTheme.primary : AppTheme.primaryLight,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool active;
  final bool done;

  const _StepDot({required this.index, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 32 : 28,
      height: active ? 32 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppTheme.primary
            : active
                ? AppTheme.primary
                : AppTheme.primaryLight,
        border: active
            ? Border.all(color: AppTheme.primaryDark, width: 2)
            : null,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: active ? Colors.white : AppTheme.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
