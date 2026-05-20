import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Servicios',
              subtitle: 'Administra tus servicios de masoterapia',
              action: FilledButton.icon(
                onPressed: () => _showServiceDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Servicio'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            const _ServicesGrid(),
          ],
        ),
      ),
    );
  }

  void _showServiceDialog(BuildContext context, WidgetRef ref, [ServiceModel? service]) {
    showDialog(
      context: context,
      builder: (_) => _ServiceDialog(service: service, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

class _ServicesGrid extends ConsumerWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(allServicesStreamProvider);

    return stream.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text('Error al cargar servicios: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Text('No hay servicios registrados. Crea el primero.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 600 ? 2 : 1;
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
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _ServiceCard extends ConsumerWidget {
  final ServiceModel service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + menu row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.spa_outlined,
                      color: AppTheme.primary, size: 22),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _onMenuSelected(context, ref, value),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
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
            // Description — grows
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
            const Divider(height: 1, color: Color(0xFFE4E4E4)),
            const SizedBox(height: 12),
            // Footer: duration chip + price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DurationChip(minutes: service.durationMinutes),
                Text(
                  '₡${service.price.toStringAsFixed(service.price % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value) {
    if (value == 'edit') {
      showDialog(
        context: context,
        builder: (_) => _ServiceDialog(service: service, ref: ref),
      );
    } else if (value == 'delete') {
      _confirmDelete(context, ref);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text(
            '¿Estás seguro de que deseas eliminar "${service.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(serviceRepositoryProvider)
                    .delete(service.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Servicio eliminado correctamente')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Duration chip
// ---------------------------------------------------------------------------

class _DurationChip extends StatelessWidget {
  final int minutes;
  const _DurationChip({required this.minutes});

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
          const Icon(Icons.schedule_outlined, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            '$minutes min',
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

// ---------------------------------------------------------------------------
// Dialog (crear / editar)
// ---------------------------------------------------------------------------

class _ServiceDialog extends StatefulWidget {
  final ServiceModel? service;
  final WidgetRef ref;

  const _ServiceDialog({this.service, required this.ref});

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _categoryCtrl;
  bool _isActive = true;
  bool _loading = false;

  bool get _isEditing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _priceCtrl = TextEditingController(
        text: s != null ? s.price.toStringAsFixed(s.price % 1 == 0 ? 0 : 2) : '');
    _durationCtrl =
        TextEditingController(text: s != null ? '${s.durationMinutes}' : '');
    _categoryCtrl = TextEditingController(text: s?.category ?? 'General');
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final repo = widget.ref.read(serviceRepositoryProvider);

    final newService = ServiceModel(
      id: widget.service?.id ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: double.parse(_priceCtrl.text.trim()),
      durationMinutes: int.parse(_durationCtrl.text.trim()),
      category: _categoryCtrl.text.trim().isEmpty
          ? 'General'
          : _categoryCtrl.text.trim(),
      isActive: _isActive,
      benefits: widget.service?.benefits ?? [],
      imageUrl: widget.service?.imageUrl,
    );

    try {
      if (_isEditing) {
        await repo.update(widget.service!.id, newService.toFirestore());
      } else {
        await repo.create(newService);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Servicio' : 'Nuevo Servicio'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del servicio'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Precio (\$)'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (double.tryParse(v.trim()) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Duración (min)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (int.tryParse(v.trim()) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Servicio activo'),
                  value: _isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }
}
