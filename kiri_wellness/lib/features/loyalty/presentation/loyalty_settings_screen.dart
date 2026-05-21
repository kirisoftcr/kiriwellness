import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/loyalty_repository.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../shared/models/loyalty_model.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/widgets/section_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de Configuración del Programa de Regalías
// Accesible desde Settings → sección Fidelización
// ─────────────────────────────────────────────────────────────────────────────

class LoyaltySettingsScreen extends ConsumerStatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  ConsumerState<LoyaltySettingsScreen> createState() =>
      _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState
    extends ConsumerState<LoyaltySettingsScreen> {
  LoyaltyConfig? _local;
  bool _saving = false;

  final _subjectCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_local == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(loyaltyRepositoryProvider).saveConfig(_local!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada correctamente'),
            backgroundColor: AppTheme.success,
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

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(loyaltyConfigStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: configAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e')),
        data: (config) {
          if (_local == null) {
            _local = config;
            _subjectCtrl.text = config.rewardEmailSubject;
          }
          final s = _local!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Programa de Regalías',
                  subtitle:
                      'Configura recompensas automáticas para clientes frecuentes',
                ),
                const SizedBox(height: 24),

                // ── Master switch ────────────────────────────────────────
                _Card(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard_outlined,
                            color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activar programa de regalías',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              Text(
                                s.enabled
                                    ? 'Las regalías se otorgan automáticamente al completar citas'
                                    : 'Ninguna regalía se otorga mientras esté desactivado',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: s.enabled,
                          activeColor: AppTheme.primary,
                          onChanged: (v) =>
                              setState(() => _local = s.copyWith(enabled: v)),
                        ),
                      ],
                    ),
                    if (s.enabled) ...[
                      const Divider(height: 28),
                      // Subject email
                      Text(
                        'Asunto del email de notificación al cliente',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _subjectCtrl,
                        decoration: const InputDecoration(
                          hintText: '🎁 ¡Tienes una regalía en Kiri Wellness!',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(
                            () => _local = s.copyWith(rewardEmailSubject: v)),
                      ),
                    ],
                  ],
                ),

                if (s.enabled) ...[
                  const SizedBox(height: 20),

                  // ── Rules list ──────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Reglas de Regalías',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva regla'),
                        onPressed: () => _showRuleDialog(context, null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (s.rules.isEmpty)
                    _EmptyRules(
                        onAdd: () => _showRuleDialog(context, null))
                  else
                    ...s.rules.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final rule = entry.value;
                      return _RuleTile(
                        rule: rule,
                        onToggle: (enabled) {
                          final updated = List<LoyaltyRule>.from(s.rules);
                          updated[idx] = rule.copyWith(enabled: enabled);
                          setState(
                              () => _local = s.copyWith(rules: updated));
                        },
                        onEdit: () => _showRuleDialog(context, idx),
                        onDelete: () {
                          final updated = List<LoyaltyRule>.from(s.rules)
                            ..removeAt(idx);
                          setState(
                              () => _local = s.copyWith(rules: updated));
                        },
                      );
                    }),
                ],

                const SizedBox(height: 32),

                // ── Save button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                        _saving ? 'Guardando...' : 'Guardar configuración'),
                    onPressed: _saving ? null : _save,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Rule Dialog ─────────────────────────────────────────────────────────────

  Future<void> _showRuleDialog(BuildContext context, int? editIndex) async {
    final existing = editIndex != null ? _local!.rules[editIndex] : null;
    final result = await showDialog<LoyaltyRule>(
      context: context,
      builder: (_) => _RuleDialog(existing: existing),
    );
    if (result == null) return;

    final rules = List<LoyaltyRule>.from(_local!.rules);
    if (editIndex != null) {
      rules[editIndex] = result;
    } else {
      rules.add(result);
    }
    setState(() => _local = _local!.copyWith(rules: rules));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RuleDialog  –  crear / editar una regla individual
// ─────────────────────────────────────────────────────────────────────────────

class _RuleDialog extends ConsumerStatefulWidget {
  final LoyaltyRule? existing;
  const _RuleDialog({this.existing});

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _milestoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _validityCtrl = TextEditingController();

  bool _isRecurring = true;
  bool _enabled = true;
  ServiceModel? _selectedService;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _milestoneCtrl.text = e.milestone.toString();
      _descCtrl.text = e.description;
      _validityCtrl.text = e.validityDays.toString();
      _isRecurring = e.isRecurring;
      _enabled = e.enabled;
    } else {
      _milestoneCtrl.text = '6';
      _validityCtrl.text = '30';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _milestoneCtrl.dispose();
    _descCtrl.dispose();
    _validityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(allServicesStreamProvider);

    return AlertDialog(
      title: Text(widget.existing != null ? 'Editar regla' : 'Nueva regla'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la regla *',
                    hintText: 'Ej: 6ª cita gratis en Cama Ceragem',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),

                // Milestone
                TextFormField(
                  controller: _milestoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número de cita que activa la regalía *',
                    hintText: 'Ej: 6',
                    border: OutlineInputBorder(),
                    suffixText: 'citas',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Ingresa un número ≥ 1';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // isRecurring
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Regalía recurrente'),
                  subtitle: Text(
                    _isRecurring
                        ? 'Se otorga cada múltiplo (6ª, 12ª, 18ª… cita)'
                        : 'Se otorga una sola vez al llegar al número indicado',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: _isRecurring,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _isRecurring = v),
                ),
                const SizedBox(height: 14),

                // Service picker
                servicesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error cargando servicios: $e'),
                  data: (services) {
                    // Try to pre-select if editing
                    if (_selectedService == null && widget.existing != null) {
                      _selectedService = services.where(
                          (s) => s.id == widget.existing!.serviceId).firstOrNull;
                    }
                    return DropdownButtonFormField<ServiceModel>(
                      value: _selectedService,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Servicio a otorgar gratis *',
                        border: OutlineInputBorder(),
                      ),
                      items: services
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedService = v),
                      validator: (v) =>
                          v == null ? 'Selecciona un servicio' : null,
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción para el cliente',
                    hintText:
                        'Ej: ¡Felicitaciones! Tu 6ª cita es gratis. Disfruta una sesión en la Cama Ceragem.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Validity days
                TextFormField(
                  controller: _validityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Días de validez (0 = sin expiración)',
                    border: OutlineInputBorder(),
                    suffixText: 'días',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Ingresa 0 o más días';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // enabled
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Regla activa'),
                  value: _enabled,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_selectedService == null) return;

            final rule = LoyaltyRule(
              id: widget.existing?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameCtrl.text.trim(),
              milestone: int.parse(_milestoneCtrl.text),
              isRecurring: _isRecurring,
              serviceId: _selectedService!.id,
              serviceName: _selectedService!.name,
              description: _descCtrl.text.trim(),
              validityDays: int.parse(_validityCtrl.text),
              enabled: _enabled,
            );
            Navigator.pop(context, rule);
          },
          child: Text(
              widget.existing != null ? 'Guardar cambios' : 'Agregar regla'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _RuleTile extends StatelessWidget {
  final LoyaltyRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: rule.enabled
              ? AppTheme.primary.withOpacity(0.4)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rule.enabled
                    ? AppTheme.primary.withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${rule.milestone}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: rule.enabled
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${rule.serviceName} · ${rule.isRecurring ? "Recurrente" : "Una vez"}'
                    '${rule.validityDays > 0 ? " · ${rule.validityDays} días" : ""}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: rule.enabled,
              activeColor: AppTheme.primary,
              onChanged: onToggle,
            ),
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppTheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRules extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRules({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.card_giftcard_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No hay reglas configuradas',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar primera regla'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
