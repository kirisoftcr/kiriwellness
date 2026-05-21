import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/loyalty_repository.dart';
import '../../../shared/models/loyalty_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientRewardsPanel
//
// Widget reutilizable que muestra las regalías de un cliente específico.
// Se usa dentro de la pantalla de administración de clientes (clients_screen).
// ─────────────────────────────────────────────────────────────────────────────

class ClientRewardsPanel extends ConsumerWidget {
  final String clientId;
  final String clientName;

  const ClientRewardsPanel({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(clientRewardsProvider(clientId));

    return rewardsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.error)),
      ),
      data: (rewards) {
        if (rewards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.card_giftcard_outlined,
                    color: Colors.grey.shade400, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Sin regalías aún',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final pending =
            rewards.where((r) => r.status == RewardStatus.pending).toList();
        final others =
            rewards.where((r) => r.status != RewardStatus.pending).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isNotEmpty) ...[
              _SectionLabel(label: 'Disponibles (${pending.length})'),
              ...pending.map((r) => _RewardCard(
                    reward: r,
                    clientId: clientId,
                    onRedeemed: () => ref.invalidate(clientRewardsProvider(clientId)),
                  )),
            ],
            if (others.isNotEmpty) ...[
              _SectionLabel(label: 'Historial'),
              ...others.map((r) => _RewardCard(
                    reward: r,
                    clientId: clientId,
                    onRedeemed: null,
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RewardCard
// ─────────────────────────────────────────────────────────────────────────────

class _RewardCard extends ConsumerWidget {
  final ClientReward reward;
  final String clientId;
  final VoidCallback? onRedeemed;

  const _RewardCard({
    required this.reward,
    required this.clientId,
    this.onRedeemed,
  });

  Color get _statusColor {
    switch (reward.status) {
      case RewardStatus.pending:
        return AppTheme.primary;
      case RewardStatus.redeemed:
        return AppTheme.textSecondary;
      case RewardStatus.expired:
        return AppTheme.error;
    }
  }

  IconData get _statusIcon {
    switch (reward.status) {
      case RewardStatus.pending:
        return Icons.card_giftcard;
      case RewardStatus.redeemed:
        return Icons.check_circle_outline;
      case RewardStatus.expired:
        return Icons.timer_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yyyy');
    final isPending = reward.status == RewardStatus.pending;
    final isExpired = reward.isExpired;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: isPending && !isExpired
            ? AppTheme.primary.withOpacity(0.06)
            : AppTheme.surface,
        border: Border.all(
          color: isPending && !isExpired
              ? AppTheme.primary.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_statusIcon, color: _statusColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reward.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      _StatusChip(status: isExpired ? RewardStatus.expired : reward.status),
                    ],
                  ),
                  if (reward.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reward.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _MetaChip(
                        icon: Icons.emoji_events_outlined,
                        label: 'Cita #${reward.earnedAtMilestone}',
                      ),
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: 'Ganada: ${fmt.format(reward.earnedAt)}',
                      ),
                      if (reward.expiresAt != null)
                        _MetaChip(
                          icon: Icons.event_busy_outlined,
                          label: 'Vence: ${fmt.format(reward.expiresAt!)}',
                          color: isExpired ? AppTheme.error : AppTheme.textSecondary,
                        ),
                      if (reward.redeemedAt != null)
                        _MetaChip(
                          icon: Icons.check_circle_outline,
                          label: 'Canjeada: ${fmt.format(reward.redeemedAt!)}',
                          color: AppTheme.textSecondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Canjear button (only for pending non-expired)
            if (isPending && !isExpired && onRedeemed != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _RedeemButton(
                  clientId: clientId,
                  reward: reward,
                  onSuccess: onRedeemed!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RedeemButton  –  canjear una regalía ingresando el ID de cita
// ─────────────────────────────────────────────────────────────────────────────

class _RedeemButton extends ConsumerStatefulWidget {
  final String clientId;
  final ClientReward reward;
  final VoidCallback onSuccess;

  const _RedeemButton({
    required this.clientId,
    required this.reward,
    required this.onSuccess,
  });

  @override
  ConsumerState<_RedeemButton> createState() => _RedeemButtonState();
}

class _RedeemButtonState extends ConsumerState<_RedeemButton> {
  bool _loading = false;

  Future<void> _showRedeemDialog() async {
    final aptCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Canjear regalía'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vas a canjear: ${widget.reward.serviceName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aptCtrl,
              decoration: const InputDecoration(
                labelText: 'ID de la cita *',
                hintText: 'Pega el ID del documento de Firestore',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El ID de la cita aparece en la barra de administración al seleccionarla.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );

    if (confirmed != true || aptCtrl.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      await ref.read(loyaltyRepositoryProvider).redeemReward(
            clientId: widget.clientId,
            rewardId: widget.reward.id,
            appointmentId: aptCtrl.text.trim(),
          );
      widget.onSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Regalía canjeada correctamente'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.redeem_outlined, size: 14),
            label: const Text('Canjear'),
            onPressed: _showRedeemDialog,
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final RewardStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case RewardStatus.pending:
        bg = AppTheme.primary.withOpacity(0.12);
        fg = AppTheme.primaryDark;
        break;
      case RewardStatus.redeemed:
        bg = Colors.grey.shade200;
        fg = AppTheme.textSecondary;
        break;
      case RewardStatus.expired:
        bg = AppTheme.error.withOpacity(0.1);
        fg = AppTheme.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5),
      ),
    );
  }
}
