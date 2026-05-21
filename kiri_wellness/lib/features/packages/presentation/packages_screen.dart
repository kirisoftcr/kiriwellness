import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/models/package_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../data/repositories/package_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../shared/models/client_model.dart';

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(packagesStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Paquetes',
              subtitle: 'Gestiona paquetes de sesiones para tus clientes',
              action: FilledButton.icon(
                onPressed: () => _showPackageDialog(context, ref, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Paquete'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            packagesAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: AppTheme.primary),
              )),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppTheme.error))),
              data: (packages) {
                if (packages.isEmpty) {
                  return const _EmptyState();
                }
                return Column(
                  children: packages
                      .map((p) => _PackageCard(
                            pkg: p,
                            onEdit: () => _showPackageDialog(context, ref, p),
                            onDelete: () =>
                                _confirmDelete(context, ref, p),
                            onAssign: () =>
                                _showAssignDialog(context, ref, p),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPackageDialog(BuildContext context, WidgetRef ref, PackageModel? existing) {
    showDialog(
      context: context,
      builder: (_) => _PackageDialog(existing: existing, ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PackageModel pkg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar paquete'),
        content: Text('¿Deseas desactivar el paquete "${pkg.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(packageRepositoryProvider).delete(pkg.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref, PackageModel pkg) {
    showDialog(
      context: context,
      builder: (_) => _AssignDialog(package: pkg, ref: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package Card
// ─────────────────────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final PackageModel pkg;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  const _PackageCard({
    required this.pkg,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard,
                      color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pkg.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (pkg.description.isNotEmpty)
                        Text(pkg.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₡${pkg.price.toStringAsFixed(0)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppTheme.primary)),
                    if (pkg.discountPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                            '${pkg.discountPercent.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Services breakdown
            ...pkg.services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.spa_outlined,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('${s.sessionCount}× ${s.serviceName}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textPrimary)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.confirmation_number_outlined,
                    label: '${pkg.totalSessions} sesiones'),
                const SizedBox(width: 12),
                _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Válido ${pkg.validityDays} días'),
                const Spacer(),
                IconButton(
                  tooltip: 'Asignar a cliente',
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_outlined,
                      color: AppTheme.primary),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined,
                      color: AppTheme.primary),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onDelete,
                  icon:
                      const Icon(Icons.delete_outline, color: AppTheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.card_giftcard_outlined,
                size: 56, color: AppTheme.primaryLight),
            SizedBox(height: 16),
            Text('No hay paquetes creados.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            SizedBox(height: 8),
            Text('Haz clic en "Nuevo Paquete" para comenzar.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package Create / Edit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PackageDialog extends ConsumerStatefulWidget {
  final PackageModel? existing;
  final WidgetRef ref;

  const _PackageDialog({required this.existing, required this.ref});

  @override
  ConsumerState<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends ConsumerState<_PackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late final TextEditingController _validity;
  List<_ServiceLine> _serviceLines = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _price = TextEditingController(text: e?.price.toStringAsFixed(0) ?? '');
    _discount =
        TextEditingController(text: e?.discountPercent.toStringAsFixed(0) ?? '0');
    _validity = TextEditingController(text: e?.validityDays.toString() ?? '30');
    if (e != null) {
      _serviceLines = e.services
          .map((s) => _ServiceLine(
                serviceId: s.serviceId,
                serviceName: s.serviceName,
                count: TextEditingController(text: s.sessionCount.toString()),
              ))
          .toList();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _discount.dispose();
    _validity.dispose();
    for (final l in _serviceLines) {
      l.count.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesStreamProvider);
    final isEdit = widget.existing != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEdit ? 'Editar paquete' : 'Nuevo paquete',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(_name, 'Nombre del paquete', required: true),
                        const SizedBox(height: 12),
                        _field(_desc, 'Descripción'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _field(_price, 'Precio (₡)',
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _field(_discount, 'Descuento (%)',
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _field(_validity, 'Validez (días)',
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Servicios incluidos',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        color: AppTheme.primaryDark,
                                        fontWeight: FontWeight.w600)),
                            const Spacer(),
                            servicesAsync.when(
                              loading: () => const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary)),
                              error: (_, __) => const SizedBox(),
                              data: (services) => TextButton.icon(
                                onPressed: () => _addService(services),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Agregar servicio'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_serviceLines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Sin servicios agregados.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          )
                        else
                          ..._serviceLines.asMap().entries.map((entry) {
                            final i = entry.key;
                            final line = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(line.serviceName,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary)),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 64,
                                    child: TextFormField(
                                      controller: line.count,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        labelText: 'Ses.',
                                        filled: true,
                                        fillColor: AppTheme.surface,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 10),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _serviceLines.removeAt(i)),
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppTheme.error, size: 20),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Guardar' : 'Crear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addService(List<ServiceModel> available) {
    final existing = _serviceLines.map((l) => l.serviceId).toSet();
    final options =
        available.where((s) => !existing.contains(s.id)).toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya agregaste todos los servicios.')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Seleccionar servicio'),
        children: options
            .map((s) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _serviceLines.add(_ServiceLine(
                          serviceId: s.id,
                          serviceName: s.name,
                          count: TextEditingController(text: '1')));
                    });
                  },
                  child: Text(s.name),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Agrega al menos un servicio al paquete.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final pkg = PackageModel(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        description: _desc.text.trim(),
        price: double.tryParse(_price.text.trim()) ?? 0,
        services: _serviceLines
            .map((l) => PackageService(
                  serviceId: l.serviceId,
                  serviceName: l.serviceName,
                  sessionCount: int.tryParse(l.count.text.trim()) ?? 1,
                ))
            .toList(),
        discountPercent: double.tryParse(_discount.text.trim()) ?? 0,
        validityDays: int.tryParse(_validity.text.trim()) ?? 30,
        isActive: widget.existing?.isActive ?? true,
      );

      final repo = ref.read(packageRepositoryProvider);
      if (widget.existing != null) {
        await repo.update(widget.existing!.id, pkg);
      } else {
        await repo.create(pkg);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _ServiceLine {
  final String serviceId;
  final String serviceName;
  final TextEditingController count;

  _ServiceLine(
      {required this.serviceId,
      required this.serviceName,
      required this.count});
}

// ─────────────────────────────────────────────────────────────────────────────
// Assign Package to Client Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AssignDialog extends ConsumerStatefulWidget {
  final PackageModel package;
  final WidgetRef ref;

  const _AssignDialog({required this.package, required this.ref});

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  ClientModel? _selectedClient;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Asignar "${widget.package.name}"',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              clientsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Text('Error: $e',
                    style: const TextStyle(color: AppTheme.error)),
                data: (clients) {
                  final sorted = [...clients]
                    ..sort((a, b) =>
                        '${a.name} ${a.lastName}'
                            .compareTo('${b.name} ${b.lastName}'));
                  return DropdownButtonFormField<ClientModel>(
                    value: _selectedClient,
                    hint: const Text('Seleccionar cliente'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: sorted
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} ${c.lastName}'),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedClient = v),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading || _selectedClient == null
                        ? null
                        : _assign,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Asignar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assign() async {
    setState(() => _loading = true);
    try {
      await ref.read(packageRepositoryProvider).assignPackageToClient(
            clientId: _selectedClient!.id,
            packageId: widget.package.id,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Paquete asignado a ${_selectedClient!.name} ${_selectedClient!.lastName}')));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

