import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/package_repository.dart';
import '../../../shared/models/appointment_model.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../core/theme/app_theme.dart';

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _monthPrefix() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Dashboard',
              subtitle: 'Resumen general del negocio',
            ),
            const SizedBox(height: 24),
            const _StatsGrid(),
            const SizedBox(height: 32),
            const _TodayAppointments(),
            const SizedBox(height: 32),
            const _QuickActions(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Grid
// ---------------------------------------------------------------------------

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    final todayAsync = ref.watch(appointmentsByDateProvider(_todayStr()));
    final allAsync = ref.watch(allAppointmentsStreamProvider);
    final clientsAsync = ref.watch(clientsStreamProvider);
    final packagesAsync = ref.watch(allActiveClientPackagesStreamProvider);

    // Today stat
    final todayCount = todayAsync.valueOrNull?.length ?? 0;
    final pendingCount = todayAsync.valueOrNull
            ?.where((a) =>
                a.status == AppointmentStatus.requested ||
                a.status == AppointmentStatus.confirmed)
            .length ??
        0;

    // Monthly revenue
    final monthPrefix = _monthPrefix();
    final monthRevenue = allAsync.valueOrNull
            ?.where((a) =>
                a.status == AppointmentStatus.completed &&
                a.date.startsWith(monthPrefix))
            .fold<double>(0, (sum, a) => sum + a.servicePrice) ??
        0.0;

    // Clients total + new this week
    final clients = clientsAsync.valueOrNull ?? [];
    final totalClients = clients.length;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final newThisWeek = clients
        .where((c) => c.createdAt.isAfter(weekAgo))
        .length;

    // Active client packages
    final activePackages = packagesAsync.valueOrNull?.length ?? 0;

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isWide ? 1.6 : 1.4,
      children: [
        StatCard(
          title: 'Citas Hoy',
          value: todayAsync.isLoading ? '...' : '$todayCount',
          icon: Icons.calendar_today,
          color: AppTheme.primary,
          subtitle: '$pendingCount pendientes',
        ),
        StatCard(
          title: 'Ingresos Mes',
          value: allAsync.isLoading
              ? '...'
              : '\$${monthRevenue.toStringAsFixed(0)}',
          icon: Icons.attach_money,
          color: AppTheme.success,
          subtitle: monthPrefix.replaceAll('-', '/'),
        ),
        StatCard(
          title: 'Clientes',
          value: clientsAsync.isLoading ? '...' : '$totalClients',
          icon: Icons.people,
          color: AppTheme.secondary,
          subtitle: '$newThisWeek nuevos esta semana',
        ),
        StatCard(
          title: 'Paquetes Activos',
          value: packagesAsync.isLoading ? '...' : '$activePackages',
          icon: Icons.card_giftcard,
          color: AppTheme.accent,
          subtitle: 'con sesiones restantes',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Today's Appointments
// ---------------------------------------------------------------------------

class _TodayAppointments extends ConsumerWidget {
  const _TodayAppointments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appointmentsByDateProvider(_todayStr()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Citas de Hoy',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/appointments'),
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.red)),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No hay citas para hoy',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  );
                }
                return Column(
                  children: appointments
                      .map((apt) => _AppointmentTile(appointment: apt))
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

class _AppointmentTile extends StatelessWidget {
  final AppointmentModel appointment;
  const _AppointmentTile({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${appointment.clientName} ${appointment.clientLastName}'.trim(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  appointment.serviceName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(appointment.time,
                  style: Theme.of(context).textTheme.titleMedium),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _statusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.confirmed:
        return AppTheme.success;
      case AppointmentStatus.requested:
        return AppTheme.warning;
      case AppointmentStatus.completed:
        return AppTheme.primary;
      case AppointmentStatus.cancelled:
        return AppTheme.textSecondary;
    }
  }
}

// ---------------------------------------------------------------------------
// Quick Actions
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acciones Rápidas',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionButton(
                icon: Icons.calendar_today,
                label: 'Citas',
                color: AppTheme.primary,
                onTap: () => context.go('/appointments')),
            _QuickActionButton(
                icon: Icons.people,
                label: 'Clientes',
                color: AppTheme.secondary,
                onTap: () => context.go('/clients')),
            _QuickActionButton(
                icon: Icons.spa,
                label: 'Servicios',
                color: AppTheme.accent,
                onTap: () => context.go('/services')),
            _QuickActionButton(
                icon: Icons.schedule,
                label: 'Horarios',
                color: AppTheme.primaryDark,
                onTap: () => context.go('/schedule')),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
