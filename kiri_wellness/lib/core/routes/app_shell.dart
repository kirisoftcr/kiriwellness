import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
import '../theme/app_theme.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

const _navItems = [
  _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, route: '/dashboard'),
  _NavItem(label: 'Citas', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, route: '/appointments'),
  _NavItem(label: 'Servicios', icon: Icons.spa_outlined, activeIcon: Icons.spa, route: '/services'),
  _NavItem(label: 'Paquetes', icon: Icons.card_giftcard_outlined, activeIcon: Icons.card_giftcard, route: '/packages'),
  _NavItem(label: 'Clientes', icon: Icons.people_outline, activeIcon: Icons.people, route: '/clients'),
  _NavItem(label: 'Horarios', icon: Icons.schedule_outlined, activeIcon: Icons.schedule, route: '/schedule'),
  _NavItem(label: 'Configuración', icon: Icons.settings_outlined, activeIcon: Icons.settings, route: '/settings'),
  _NavItem(label: 'Reportes', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, route: '/reports'),
];

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return isWide ? _WideLayout(child: child) : _NarrowLayout(child: child);
  }
}

// ── Desktop / Tablet: Navigation Rail ──────────────────────────────────────
class _WideLayout extends StatelessWidget {
  final Widget child;
  const _WideLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _navItems.indexWhere(
      (item) => GoRouterState.of(context).uri.path.startsWith(item.route),
    );

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.spa, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kiri', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          Text('Wellness', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _navItems.length,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final isSelected = selectedIndex == index;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            size: 22,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                          ),
                          onTap: () => context.go(item.route),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Consumer(
                  builder: (context, ref, _) => ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.textSecondary, size: 20),
                    title: const Text('Cerrar sesión',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Mobile: Bottom Navigation Bar ──────────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  final Widget child;
  const _NarrowLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _navItems.indexWhere(
      (item) => GoRouterState.of(context).uri.path.startsWith(item.route),
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primaryLight.withValues(alpha: 0.4),
        onDestinationSelected: (index) => context.go(_navItems[index].route),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon, color: AppTheme.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}
