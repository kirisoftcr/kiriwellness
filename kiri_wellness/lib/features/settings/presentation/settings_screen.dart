import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/models/settings_model.dart';
import '../../../shared/widgets/section_header.dart';
import '../../loyalty/presentation/loyalty_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppSettings? _local;
  bool _saving = false;
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.error)),
        ),
        data: (settings) {
          // Initialise local editable copy on first load
          _local ??= settings;
          final s = _local!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Configuración',
                  subtitle: 'Ajustes generales de la agenda',
                ),
                const SizedBox(height: 24),

                // ── Card ──────────────────────────────────────────────────
                _Card(
                  children: [
                    // Break minutes slider
                    _SettingLabel(
                      icon: Icons.coffee_outlined,
                      title: 'Descanso entre citas',
                      subtitle:
                          '${s.breakMinutes} minutos de pausa después de cada servicio',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('0',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        Expanded(
                          child: Slider(
                            value: s.breakMinutes.toDouble(),
                            min: 0,
                            max: 60,
                            divisions: 12,
                            label: '${s.breakMinutes} min',
                            activeColor: AppTheme.primary,
                            onChanged: (v) =>
                                setState(() => _local = s.copyWith(
                                    breakMinutes: v.round())),
                          ),
                        ),
                        const Text('60',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),

                    const Divider(height: 28),

                    // Cancellation limit
                    _SettingLabel(
                      icon: Icons.cancel_schedule_send_outlined,
                      title: 'Límite de cancelación',
                      subtitle:
                          'Mínimo ${s.cancellationHoursLimit} horas de anticipación',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('0',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        Expanded(
                          child: Slider(
                            value: s.cancellationHoursLimit.toDouble(),
                            min: 0,
                            max: 72,
                            divisions: 18,
                            label: '${s.cancellationHoursLimit}h',
                            activeColor: AppTheme.primary,
                            onChanged: (v) =>
                                setState(() => _local = s.copyWith(
                                    cancellationHoursLimit: v.round())),
                          ),
                        ),
                        const Text('72h',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),

                    const Divider(height: 28),

                    // Same-day booking toggle
                    Row(
                      children: [
                        const Icon(Icons.today_outlined,
                            size: 20, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reservas para el mismo día',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              Text(
                                s.allowSameDayBooking
                                    ? 'Permitidas'
                                    : 'No permitidas',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: s.allowSameDayBooking,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(
                              () => _local = s.copyWith(allowSameDayBooking: v)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Admin Emails Card ─────────────────────────────────────
                _AdminEmailsCard(
                  emails: s.adminEmails,
                  controller: _emailCtrl,
                  onAdd: () {
                    final email = _emailCtrl.text.trim().toLowerCase();
                    if (email.isEmpty || !email.contains('@')) return;
                    if (s.adminEmails.contains(email)) return;
                    setState(() {
                      _emailCtrl.clear();
                      _local = s.copyWith(
                          adminEmails: [...s.adminEmails, email]);
                    });
                  },
                  onRemove: (email) => setState(() => _local = s.copyWith(
                      adminEmails:
                          s.adminEmails.where((e) => e != email).toList())),
                ),

                const SizedBox(height: 24),

                // ── Loyalty / Fidelización ────────────────────────────────
                _LoyaltyNavigationCard(),

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(s),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(AppSettings settings) async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingLabel(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoyaltyNavigationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Programa de Regalías'),
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
              ),
              body: const LoyaltySettingsScreen(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard_outlined,
                  color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Programa de Regalías',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Configura recompensas automáticas para clientes frecuentes',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}


class _AdminEmailsCard extends StatelessWidget {
  final List<String> emails;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _AdminEmailsCard({
    required this.emails,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.email_outlined,
                  size: 20, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Correos de notificación',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text(
                        'Estos correos recibirán una notificación por cada nueva cita',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chips for existing emails
          if (emails.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emails
                  .map((e) => Chip(
                        label: Text(e, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => onRemove(e),
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                        labelStyle:
                            const TextStyle(color: AppTheme.primaryDark),
                        deleteIconColor: AppTheme.primary,
                      ))
                  .toList(),
            ),
          if (emails.isNotEmpty) const SizedBox(height: 12),
          // Add email row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Agregar correo...',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
