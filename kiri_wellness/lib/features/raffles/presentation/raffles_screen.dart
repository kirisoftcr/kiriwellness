import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/section_header.dart';

class RafflesScreen extends StatelessWidget {
  const RafflesScreen({super.key});

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
              title: 'Rifas',
              subtitle: 'Organiza sorteos para tus clientes',
              action: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Rifa'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            ..._mockRaffles.map((r) => _RaffleCard(data: r)),
          ],
        ),
      ),
    );
  }
}

class _RaffleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RaffleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data['sold'] / data['total'];
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.confirmation_number, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'], style: Theme.of(context).textTheme.titleLarge),
                      Text('Premio: ${data['prize']}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${data['ticketPrice']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primary,
                    )),
                    const Text('por boleto', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Boletos vendidos: ${data['sold']}/${data['total']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                Text('Sorteo: ${data['drawDate']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.people_outlined, size: 16),
                    label: const Text('Ver Boletos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: data['sold'] > 0 ? () {} : null,
                    icon: const Icon(Icons.casino_outlined, size: 16),
                    label: const Text('Realizar Sorteo'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _mockRaffles = [
  {'title': 'Rifa Día de la Madre', 'prize': '3 masajes relajantes gratis', 'ticketPrice': 5, 'sold': 45, 'total': 100, 'drawDate': '26 Mayo'},
  {'title': 'Gran Rifa de Junio', 'prize': 'Pack Bienestar Total (10 sesiones)', 'ticketPrice': 10, 'sold': 12, 'total': 50, 'drawDate': '30 Jun'},
];
