import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/gift_card_repository.dart';
import '../../../features/gift_cards/domain/gift_card_image_service.dart';
import '../../../shared/models/gift_card_model.dart';
import '../../../shared/widgets/section_header.dart';

// ---------------------------------------------------------------------------
// Notifiers
// ---------------------------------------------------------------------------

/// Tracks batch-generation progress so the UI can show a progress bar.
class _BatchNotifier extends StateNotifier<_BatchState> {
  _BatchNotifier() : super(const _BatchState());

  void start(int total) => state = _BatchState(running: true, total: total);
  void increment() =>
      state = state.copyWith(done: state.done + 1);
  void finish() => state = state.copyWith(running: false);
}

class _BatchState {
  final bool running;
  final int total;
  final int done;

  const _BatchState({
    this.running = false,
    this.total = 0,
    this.done = 0,
  });

  _BatchState copyWith({bool? running, int? total, int? done}) => _BatchState(
        running: running ?? this.running,
        total: total ?? this.total,
        done: done ?? this.done,
      );

  double get progress => total == 0 ? 0 : done / total;
}

final _batchNotifierProvider =
    StateNotifierProvider.autoDispose<_BatchNotifier, _BatchState>(
  (ref) => _BatchNotifier(),
);

// ---------------------------------------------------------------------------
// GiftCardsScreen
// ---------------------------------------------------------------------------

class GiftCardsScreen extends ConsumerStatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  ConsumerState<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends ConsumerState<GiftCardsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(_batchNotifierProvider);
    final allAsync = ref.watch(giftCardsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: SectionHeader(
              title: 'Tarjetas de Regalo',
              subtitle: 'Genera, vende y controla el ciclo de vida de tus gift cards',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: batch.running
                        ? null
                        : () => _showGenerateDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Generar tarjetas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Batch progress indicator
          if (batch.running)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generando tarjetas… ${batch.done} / ${batch.total}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: batch.progress,
                    backgroundColor: AppTheme.oliveLight,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Stats row
          allAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cards) => _StatsRow(cards: cards),
          ),
          const SizedBox(height: 8),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Todas'),
                Tab(text: 'Disponibles'),
                Tab(text: 'Activas'),
                Tab(text: 'Canjeadas'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CardList(filter: null),
                _CardList(filter: GiftCardStatus.available),
                _CardList(filter: GiftCardStatus.active),
                _CardList(filter: GiftCardStatus.redeemed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateDialog(BuildContext context) async {
    int count = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Generar tarjetas de regalo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona cuántas tarjetas deseas generar. Cada tarjeta tendrá un código único y se generará una imagen lista para imprimir.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      onPressed: count > 1 ? () => setS(() => count--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '$count',
                        style: Theme.of(ctx).textTheme.displayMedium,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed:
                          count < 50 ? () => setS(() => count++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Máximo 50 tarjetas por lote',
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _generateBatch(count);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary),
                child: Text('Generar $count tarjeta${count == 1 ? '' : 's'}'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _generateBatch(int count) async {
    final notifier = ref.read(_batchNotifierProvider.notifier);
    final service = ref.read(giftCardImageServiceProvider);
    notifier.start(count);
    try {
      for (var i = 0; i < count; i++) {
        await service.createCard();
        notifier.increment();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando tarjetas: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      notifier.finish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ $count tarjeta${count == 1 ? '' : 's'} generada${count == 1 ? '' : 's'} correctamente'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final List<GiftCardModel> cards;
  const _StatsRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    final available =
        cards.where((c) => c.status == GiftCardStatus.available).length;
    final active =
        cards.where((c) => c.status == GiftCardStatus.active).length;
    final redeemed =
        cards.where((c) => c.status == GiftCardStatus.redeemed).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatChip(
              label: 'Disponibles',
              count: available,
              color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Activas', count: active, color: AppTheme.primary),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Canjeadas', count: redeemed, color: AppTheme.success),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Total', count: cards.length, color: AppTheme.primaryDark),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card List (filterable)
// ---------------------------------------------------------------------------

class _CardList extends ConsumerWidget {
  final GiftCardStatus? filter;
  const _CardList({this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = filter == null
        ? ref.watch(giftCardsStreamProvider)
        : ref.watch(giftCardsByStatusProvider(filter!));

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Error: $e')),
      data: (cards) {
        if (cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard,
                    size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  'No hay tarjetas',
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          itemCount: cards.length,
          itemBuilder: (_, i) => _GiftCardTile(card: cards[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual tile
// ---------------------------------------------------------------------------

class _GiftCardTile extends ConsumerWidget {
  final GiftCardModel card;
  const _GiftCardTile({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(card.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 72,
                height: 46,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.oliveLight,
                ),
                child: card.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: card.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 1)),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 20),
                      )
                    : const Icon(Icons.card_giftcard,
                        color: AppTheme.textSecondary, size: 24),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.2,
                        fontFamily: 'Courier',
                      ),
                    ),
                    if (card.buyerName != null && card.buyerName!.isNotEmpty)
                      Text(
                        'Cliente: ${card.buyerName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    Text(
                      DateFormat("d MMM yyyy", 'es').format(card.createdAt),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  card.status.label,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(GiftCardStatus s) {
    switch (s) {
      case GiftCardStatus.available:
        return AppTheme.textSecondary;
      case GiftCardStatus.active:
        return AppTheme.primary;
      case GiftCardStatus.redeemed:
        return AppTheme.success;
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _GiftCardDetailDialog(card: card),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail / action dialog
// ---------------------------------------------------------------------------

class _GiftCardDetailDialog extends ConsumerStatefulWidget {
  final GiftCardModel card;
  const _GiftCardDetailDialog({required this.card});

  @override
  ConsumerState<_GiftCardDetailDialog> createState() =>
      _GiftCardDetailDialogState();
}

class _GiftCardDetailDialogState
    extends ConsumerState<_GiftCardDetailDialog> {
  final _buyerCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _buyerCtrl.text = widget.card.buyerName ?? '';
  }

  @override
  void dispose() {
    _buyerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.card_giftcard, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              card.code,
              style: const TextStyle(
                  letterSpacing: 1.4,
                  fontFamily: 'Courier',
                  fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              if (card.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: card.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 190,
                    placeholder: (_, __) => const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 100,
                      child: Center(
                          child: Text('No se pudo cargar la imagen')),
                    ),
                  ),
                )
              else if (card.status == GiftCardStatus.redeemed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.oliveLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '🗑️ Imagen eliminada tras el canje',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Meta info
              _InfoRow('Estado', card.status.label),
              _InfoRow(
                  'Creada',
                  DateFormat("d 'de' MMMM yyyy, HH:mm", 'es')
                      .format(card.createdAt)),
              if (card.activatedAt != null)
                _InfoRow(
                    'Activada',
                    DateFormat("d 'de' MMMM yyyy, HH:mm", 'es')
                        .format(card.activatedAt!)),
              if (card.redeemedAt != null)
                _InfoRow(
                    'Canjeada',
                    DateFormat("d 'de' MMMM yyyy, HH:mm", 'es')
                        .format(card.redeemedAt!)),
              if (card.appointmentId != null)
                _InfoRow('ID Cita', card.appointmentId!),

              // ── Actions ────────────────────────────────────────────────
              if (card.status == GiftCardStatus.available) ...[
                const Divider(height: 28),
                const Text(
                  'Marcar como vendida',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _buyerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del comprador',
                    hintText: 'Ej: María González',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _markAsActive,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sell, size: 18),
                    label: const Text('Marcar como Activa (vendida)'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _markAsActive() async {
    final buyerName = _buyerCtrl.text.trim();
    if (buyerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el nombre del comprador'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(giftCardRepositoryProvider)
          .markAsActive(widget.card.id, buyerName: buyerName);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Tarjeta ${widget.card.code} marcada como Activa'),
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
