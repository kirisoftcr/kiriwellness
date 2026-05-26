import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../shared/models/appointment_model.dart';
import '../../../shared/widgets/section_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtCRC(double v) =>
    '₡\u00a0${NumberFormat('#,##0', 'es_CR').format(v).replaceAll(',', '.')}';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

final _monthNames = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: SectionHeader(
              title: 'Reportes Contables',
              subtitle: 'Ingresos y resumen de servicios',
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Por mes'),
                Tab(icon: Icon(Icons.date_range_outlined, size: 18), text: 'Rango de fechas'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _MonthlyReportTab(),
                _RangeReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly tab
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyReportTab extends ConsumerStatefulWidget {
  const _MonthlyReportTab();

  @override
  ConsumerState<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends ConsumerState<_MonthlyReportTab> {
  final now = DateTime.now();
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _selectedMonth = DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allAppointmentsStreamProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      data: (all) {
        final prefix = '${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}';
        final filtered = all
            .where((a) =>
                a.status == AppointmentStatus.completed &&
                a.date.startsWith(prefix))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month / year selector
              Row(children: [
                _YearMonthPicker(
                  year: _selectedYear,
                  month: _selectedMonth,
                  onChanged: (y, m) => setState(() { _selectedYear = y; _selectedMonth = m; }),
                ),
              ]),
              const SizedBox(height: 24),
              _ReportContent(appointments: filtered),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Range tab
// ─────────────────────────────────────────────────────────────────────────────

class _RangeReportTab extends ConsumerStatefulWidget {
  const _RangeReportTab();

  @override
  ConsumerState<_RangeReportTab> createState() => _RangeReportTabState();
}

class _RangeReportTabState extends ConsumerState<_RangeReportTab> {
  DateTimeRange? _range;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _range ??
          DateTimeRange(
              start: DateTime(now.year, now.month, 1), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allAppointmentsStreamProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      data: (all) {
        final range = _range;
        final filtered = range == null
            ? <AppointmentModel>[]
            : all
                .where((a) {
                  if (a.status != AppointmentStatus.completed) return false;
                  final parts = a.date.split('-').map(int.parse).toList();
                  final d = DateTime(parts[0], parts[1], parts[2]);
                  return !d.isBefore(range.start) &&
                      !d.isAfter(range.end.add(const Duration(days: 1)));
                })
                .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range picker button
              OutlinedButton.icon(
                onPressed: () => _pickRange(context),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(range == null
                    ? 'Seleccionar rango de fechas'
                    : '${_fmtDate(range.start)}  →  ${_fmtDate(range.end)}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (range == null)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text('Selecciona un rango de fechas para ver el reporte.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else ...[
                const SizedBox(height: 24),
                _ReportContent(appointments: filtered),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared report content
// ─────────────────────────────────────────────────────────────────────────────

class _ReportContent extends StatelessWidget {
  final List<AppointmentModel> appointments;
  const _ReportContent({required this.appointments});

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text('No hay citas completadas en este período.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    // Exclude reward appointments (price = 0, isReward = true) from revenue metrics
    final billableAppointments =
        appointments.where((a) => !a.isReward).toList();

    final total =
        billableAppointments.fold<double>(0, (s, a) => s + a.servicePrice);
    final count = billableAppointments.length;

    // Group by service — only billable appointments
    final serviceMap = <String, _ServiceSummary>{};
    for (final a in billableAppointments) {
      final entry = serviceMap.putIfAbsent(
          a.serviceName,
          () => _ServiceSummary(name: a.serviceName));
      entry.count++;
      entry.revenue += a.servicePrice;
    }
    final services = serviceMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPI Cards ──────────────────────────────────────────────────────
        LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 600;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            children: [
              Flexible(
                flex: wide ? 1 : 0,
                child: _KpiCard(
                  icon: Icons.attach_money,
                  color: AppTheme.success,
                  label: 'Ingresos totales',
                  value: _fmtCRC(total),
                ),
              ),
              SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 12),
              Flexible(
                flex: wide ? 1 : 0,
                child: _KpiCard(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.primary,
                  label: 'Citas completadas',
                  value: '$count',
                ),
              ),
              SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 12),
              Flexible(
                flex: wide ? 1 : 0,
                child: _KpiCard(
                  icon: Icons.trending_up,
                  color: AppTheme.accent,
                  label: 'Promedio por cita',
                  value: _fmtCRC(count > 0 ? total / count : 0),
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 28),

        // ── Services breakdown ─────────────────────────────────────────────
        Text('Desglose por servicio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                // Header row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    const Expanded(
                        flex: 4,
                        child: Text('Servicio',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark))),
                    const Expanded(
                        flex: 1,
                        child: Text('Citas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark))),
                    const Expanded(
                        flex: 2,
                        child: Text('Ingresos',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark))),
                    const Expanded(
                        flex: 1,
                        child: Text('%',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark))),
                  ]),
                ),
                ...services.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final pct = total > 0 ? (s.revenue / total * 100) : 0.0;
                  return Column(children: [
                    Container(
                      color: i.isEven
                          ? Colors.transparent
                          : AppTheme.background.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          flex: 4,
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: _serviceColor(i),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.name,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppTheme.textPrimary)),
                            ),
                          ]),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('${s.count}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_fmtCRC(s.revenue),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('${pct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ),
                      ]),
                    ),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: AppTheme.background,
                        color: _serviceColor(i),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ]);
                }),
                // Total row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    const Expanded(
                        flex: 4,
                        child: Text('TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppTheme.primaryDark))),
                    Expanded(
                        flex: 1,
                        child: Text('$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryDark))),
                    Expanded(
                        flex: 2,
                        child: Text(_fmtCRC(total),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppTheme.success))),
                    const Expanded(flex: 1, child: SizedBox()),
                  ]),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Appointment detail list ─────────────────────────────────────────
        Text('Detalle de citas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              // header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(children: const [
                  Expanded(
                      flex: 2,
                      child: Text('Fecha',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark))),
                  Expanded(
                      flex: 3,
                      child: Text('Cliente',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark))),
                  Expanded(
                      flex: 3,
                      child: Text('Servicio',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark))),
                  Expanded(
                      flex: 2,
                      child: Text('Monto',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark))),
                ]),
              ),
              ...appointments.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                final parts = a.date.split('-').map(int.parse).toList();
                final d = DateTime(parts[0], parts[1], parts[2]);
                return Container(
                  color: i.isEven
                      ? Colors.transparent
                      : AppTheme.background.withValues(alpha: 0.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Text(_fmtDate(d),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text(
                            '${a.clientName} ${a.clientLastName}'.trim(),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        flex: 3,
                        child: Text(a.serviceName,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        flex: 2,
                        child: a.isReward
                            ? const Text('Regalía',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.secondary))
                            : Text(_fmtCRC(a.servicePrice),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryDark))),
                  ]),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Color _serviceColor(int index) {
    const colors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.accent,
      AppTheme.warning,
      AppTheme.secondary,
      AppTheme.primaryDark,
    ];
    return colors[index % colors.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Card
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _KpiCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year / Month picker
// ─────────────────────────────────────────────────────────────────────────────

class _YearMonthPicker extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;
  const _YearMonthPicker(
      {required this.year,
      required this.month,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years =
        List.generate(now.year - 2023, (i) => 2024 + i)..add(now.year);

    return Row(children: [
      DropdownButton<int>(
        value: year,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v, month); },
      ),
      const SizedBox(width: 8),
      DropdownButton<int>(
        value: month,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: List.generate(
            12,
            (i) => DropdownMenuItem(
                value: i + 1, child: Text(_monthNames[i + 1]))),
        onChanged: (v) { if (v != null) onChanged(year, v); },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceSummary {
  final String name;
  int count = 0;
  double revenue = 0;
  _ServiceSummary({required this.name});
}
