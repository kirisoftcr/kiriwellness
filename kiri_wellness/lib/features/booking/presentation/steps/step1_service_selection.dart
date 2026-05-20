import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/service_model.dart';
import '../../../../data/repositories/service_repository.dart';
import '../booking_page.dart';

class Step1ServiceSelection extends ConsumerWidget {
  const Step1ServiceSelection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(activeServicesStreamProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige tu servicio',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Selecciona el tratamiento que deseas reservar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error al cargar servicios: $e',
                style: const TextStyle(color: AppTheme.error)),
          ),
          data: (services) {
            if (services.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No hay servicios disponibles en este momento.',
                    style: TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final Map<String, List<ServiceModel>> byCategory = {};
            for (final s in services) {
              byCategory.putIfAbsent(s.category, () => []).add(s);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: byCategory.entries
                  .map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryLabel(entry.key),
                          const SizedBox(height: 14),
                          if (isWide)
                            _WideServiceGrid(services: entry.value)
                          else
                            _NarrowServiceList(services: entry.value),
                          const SizedBox(height: 28),
                        ],
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category label
// ---------------------------------------------------------------------------

class _CategoryLabel extends StatelessWidget {
  final String label;
  const _CategoryLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Wide grid — equal-width columns, cards match height within each row
// ---------------------------------------------------------------------------

class _WideServiceGrid extends ConsumerWidget {
  final List<ServiceModel> services;
  const _WideServiceGrid({required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 900 ? 3 : 2;
      const gap = 16.0;
      final rows = <List<ServiceModel>>[];
      for (int i = 0; i < services.length; i += cols) {
        rows.add(services.sublist(i, min(i + cols, services.length)));
      }
      return Column(
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          return Padding(
            padding: EdgeInsets.only(bottom: e.key < rows.length - 1 ? gap : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cols; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: i < row.length
                          ? _ServiceCard(service: row[i])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Narrow list
// ---------------------------------------------------------------------------

class _NarrowServiceList extends ConsumerWidget {
  final List<ServiceModel> services;
  const _NarrowServiceList({required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: services
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServiceCard(service: s),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _ServiceCard extends ConsumerStatefulWidget {
  final ServiceModel service;
  const _ServiceCard({required this.service});

  @override
  ConsumerState<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<_ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected =
        ref.watch(bookingProvider).selectedService?.id == widget.service.id;
    final isWide = MediaQuery.of(context).size.width >= 800;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            ref.read(bookingProvider.notifier).selectService(widget.service),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.07)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : _hovered
                      ? AppTheme.primaryLight
                      : const Color(0xFFE4E4E4),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppTheme.primary.withValues(alpha: 0.14)
                    : _hovered
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                blurRadius: selected || _hovered ? 14 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: isWide
              ? _WideCardContent(service: widget.service, selected: selected)
              : _NarrowCardContent(service: widget.service, selected: selected),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide card content — vertical layout filling full height
// ---------------------------------------------------------------------------

class _WideCardContent extends StatelessWidget {
  final ServiceModel service;
  final bool selected;
  const _WideCardContent(
      {required this.service, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + checkmark row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.primaryLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.spa_outlined,
                    color: AppTheme.primary, size: 22),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            service.name,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          // Description — grows, pushes footer down
          Expanded(
            child: Text(
              service.description,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Divider
          Divider(height: 1, color: const Color(0xFFE4E4E4)),
          const SizedBox(height: 12),
          // Footer: duration + price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chip(
                icon: Icons.schedule_outlined,
                label: '${service.durationMinutes} min',
              ),
              Text(
                '₡${service.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.primaryDark : AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow card content — horizontal layout
// ---------------------------------------------------------------------------

class _NarrowCardContent extends StatelessWidget {
  final ServiceModel service;
  final bool selected;
  const _NarrowCardContent(
      {required this.service, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : AppTheme.primaryLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.spa_outlined,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  service.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _Chip(
                  icon: Icons.schedule_outlined,
                  label: '${service.durationMinutes} min',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Price + check
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₡${service.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.primaryDark : AppTheme.primary,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 14),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable chip (duration)
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
