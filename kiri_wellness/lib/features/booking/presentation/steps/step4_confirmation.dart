import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../booking_page.dart';

class Step4Confirmation extends ConsumerWidget {
  const Step4Confirmation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;

    final dateLabel = booking.selectedDate != null
        ? _capitalize(
            DateFormat('EEEE d \'de\' MMMM yyyy', 'es')
                .format(booking.selectedDate!))
        : '—';
    final timeLabel = booking.selectedTime != null
        ? _formatAmPm(booking.selectedTime!)
        : '—';
    final fullName = [
      booking.clientName,
      booking.clientLastName
    ].where((s) => s.isNotEmpty).join(' ');

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 520 : double.infinity),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Success animation container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              '¡Solicitud enviada!',
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppTheme.primaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu solicitud de cita ha sido recibida.\nKiri se pondrá en contacto contigo para confirmar.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Client code badge
            if (booking.clientCode != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tu código de cliente',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text(
                          booking.clientCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (booking.clientCode != null)
              Text(
                'Guarda este código para consultar tus citas.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),

            // Confirmation card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.spa_outlined,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.selectedService?.name ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Text(
                              '${booking.selectedService?.durationMinutes ?? '—'} min  ·  ₡${booking.selectedService?.price.toStringAsFixed(0) ?? '—'}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                      icon: Icons.calendar_today_outlined, label: dateLabel),
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.schedule, label: timeLabel),
                  const Divider(height: 24),
                  _DetailRow(
                      icon: Icons.person_outline,
                      label: fullName),
                  const SizedBox(height: 10),
                  _DetailRow(
                      icon: Icons.phone_outlined, label: booking.clientPhone),
                  if (booking.clientEmail.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailRow(
                        icon: Icons.email_outlined, label: booking.clientEmail),
                  ],
                  if (booking.notes.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.note_outlined, label: booking.notes),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Status notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta solicitud está pendiente de confirmación. Recibirás un mensaje de WhatsApp o correo en las próximas horas.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Book another
            FilledButton.icon(
              onPressed: () =>
                  ref.read(bookingProvider.notifier).reset(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Reservar otra cita'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _formatAmPm(TimeOfDay time) {
    final h = time.hour;
    final m = time.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final minuteStr = m.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary)),
        ),
      ],
    );
  }
}
