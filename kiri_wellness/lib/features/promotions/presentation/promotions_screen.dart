import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Promociones',
              subtitle: 'Crea descuentos y ofertas especiales',
              action: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Promoción'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            ..._mockPromos.map((p) => _PromoCard(data: p)),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PromoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: data['active'] ? AppTheme.success : AppTheme.textSecondary,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_offer, color: AppTheme.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(data['title'], style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      if (data['code'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(data['code'], style: const TextStyle(
                            fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          )),
                        ),
                    ],
                  ),
                  Text(data['description'], style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  )),
                  const SizedBox(height: 4),
                  Text('Válida: ${data['dates']}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12, color: AppTheme.textSecondary,
                  )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${data['value']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.secondary,
                )),
                const SizedBox(height: 4),
                Switch.adaptive(
                  value: data['active'],
                  onChanged: (_) {},
                  activeThumbColor: AppTheme.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _mockPromos = [
  {'title': 'Día de la Madre', 'description': '20% de descuento en todos los servicios', 'value': '20% OFF', 'code': 'MAMA2026', 'dates': '10-15 Mayo', 'active': true},
  {'title': 'Primeros 3 clientes del mes', 'description': 'Sesión gratis en su próxima visita', 'value': '1 Gratis', 'code': null, 'dates': 'Todo Mayo', 'active': true},
  {'title': 'Cumpleaños', 'description': '15% de descuento el mes de tu cumpleaños', 'value': '15% OFF', 'code': 'BDAY', 'dates': 'Permanente', 'active': false},
];
