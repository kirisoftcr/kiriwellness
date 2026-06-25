import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../shared/models/review_model.dart';
import '../../../shared/widgets/section_header.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  ReviewStatus? _filterStatus; // null = todas

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(allReviewsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Reseñas',
              subtitle: 'Modera las reseñas de los clientes',
            ),
            const SizedBox(height: 20),
            // ── Filtros de estado ──────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                _FilterChip(
                  label: 'Pendientes',
                  color: AppTheme.warning,
                  selected: _filterStatus == ReviewStatus.pending,
                  onTap: () =>
                      setState(() => _filterStatus = ReviewStatus.pending),
                ),
                _FilterChip(
                  label: 'Aprobadas',
                  color: AppTheme.success,
                  selected: _filterStatus == ReviewStatus.approved,
                  onTap: () =>
                      setState(() => _filterStatus = ReviewStatus.approved),
                ),
                _FilterChip(
                  label: 'Rechazadas',
                  color: AppTheme.error,
                  selected: _filterStatus == ReviewStatus.rejected,
                  onTap: () =>
                      setState(() => _filterStatus = ReviewStatus.rejected),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ── Lista ──────────────────────────────────────────────────
            reviewsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error al cargar reseñas: $e',
                    style: const TextStyle(color: AppTheme.error)),
              ),
              data: (reviews) {
                final filtered = _filterStatus == null
                    ? reviews
                    : reviews
                        .where((r) => r.status == _filterStatus)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(
                        'No hay reseñas en esta categoría.',
                        style: GoogleFonts.lato(
                            color: AppTheme.textSecondary, fontSize: 15),
                      ),
                    ),
                  );
                }

                return Column(
                  children: filtered
                      .map((r) => _ReviewAdminCard(review: r))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? chipColor
                : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? chipColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Admin card ───────────────────────────────────────────────────────────────

class _ReviewAdminCard extends ConsumerStatefulWidget {
  final ReviewModel review;
  const _ReviewAdminCard({required this.review});

  @override
  ConsumerState<_ReviewAdminCard> createState() => _ReviewAdminCardState();
}

class _ReviewAdminCardState extends ConsumerState<_ReviewAdminCard> {
  bool _busy = false;

  Future<void> _action(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final repo = ref.read(reviewRepositoryProvider);

    final (statusColor, statusLabel) = switch (r.status) {
      ReviewStatus.approved => (AppTheme.success, 'Aprobada'),
      ReviewStatus.rejected => (AppTheme.error, 'Rechazada'),
      ReviewStatus.pending  => (AppTheme.warning, 'Pendiente'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ─────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  r.clientName.isNotEmpty
                      ? r.clientName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // ── Contenido ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.displayName,
                          style: GoogleFonts.lato(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(width: 8),
                      // Estrellas
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => Icon(
                          i < r.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFD4A017),
                          size: 14,
                        )),
                      ),
                      const Spacer(),
                      // Chip de estado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(statusLabel,
                            style: GoogleFonts.lato(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r.reviewText,
                      style: GoogleFonts.lato(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.6)),
                  const SizedBox(height: 10),
                  // Fecha
                  Text(
                    '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                    style: GoogleFonts.lato(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── Acciones ─────────────────────────────────────────
            if (_busy)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary))
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.status != ReviewStatus.approved)
                    Tooltip(
                      message: 'Aprobar',
                      child: IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: AppTheme.success),
                        onPressed: () =>
                            _action(() => repo.approve(r.id)),
                      ),
                    ),
                  if (r.status != ReviewStatus.rejected)
                    Tooltip(
                      message: 'Rechazar',
                      child: IconButton(
                        icon: const Icon(Icons.cancel_outlined,
                            color: AppTheme.error),
                        onPressed: () =>
                            _action(() => repo.reject(r.id)),
                      ),
                    ),
                  Tooltip(
                    message: 'Eliminar',
                    child: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.grey.shade400),
                      onPressed: () => _confirmDelete(context, repo),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReviewRepository repo) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: const Text(
            '¿Estás segura de que deseas eliminar permanentemente esta reseña?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _action(() => repo.delete(widget.review.id));
      }
    });
  }
}
