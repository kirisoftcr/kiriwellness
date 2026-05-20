import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

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
              title: 'Paquetes',
              subtitle: 'Gestiona paquetes de sesiones con descuento',
              action: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Paquete'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            ..._mockPackages.map((p) => _PackageCard(data: p)),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PackageCard({required this.data});

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
                  child: const Icon(Icons.card_giftcard, color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'], style: Theme.of(context).textTheme.titleLarge),
                      Text(data['description'], style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₡${data['price']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primary,
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${data['discount']}% OFF', style: const TextStyle(
                        color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700,
                      )),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(icon: Icons.confirmation_number_outlined, label: '${data['sessions']} sesiones'),
                const SizedBox(width: 12),
                _InfoChip(icon: Icons.calendar_today_outlined, label: 'Válido ${data['validity']} días'),
                const SizedBox(width: 12),
                _InfoChip(icon: Icons.people_outlined, label: '${data['sold']} vendidos'),
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
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textSecondary, fontSize: 13,
        )),
      ],
    );
  }
}

const _mockPackages = [
  {'name': 'Pack Relajación Total', 'description': '5 masajes relajantes de 60 min', 'price': 200, 'discount': 11, 'sessions': 5, 'validity': 90, 'sold': 8},
  {'name': 'Pack Deportivo Pro', 'description': '4 masajes deportivos + evaluación postural', 'price': 195, 'discount': 11, 'sessions': 4, 'validity': 60, 'sold': 5},
  {'name': 'Pack Bienestar Mensual', 'description': '8 sesiones de masaje a elección', 'price': 320, 'discount': 11, 'sessions': 8, 'validity': 30, 'sold': 3},
];
