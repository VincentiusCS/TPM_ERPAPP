import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

/// Reusable bottom navigation bar used across main screens.
///
/// Pass [activeIndex] to highlight the current tab. Use `null` or `-1`
/// for screens that don't correspond to one of the tabs (e.g. currency,
/// time, profile screens).
class AppBottomNav extends StatelessWidget {
  final int activeIndex;

  const AppBottomNav({super.key, this.activeIndex = -1});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.currentUser?.role == 'admin';

    final items = [
      const _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', route: AppRoutes.dashboard),
      if (isAdmin)
        const _NavItem(icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Staff', route: AppRoutes.employees),
      const _NavItem(icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check, label: 'Attendance', route: AppRoutes.attendance),
      const _NavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payroll', route: AppRoutes.payroll),
      const _NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'Support', route: AppRoutes.chatbot),
    ];

    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F8),
        border: Border(top: BorderSide(color: const Color(0xFFC4C7C7).withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final isActive = currentRoute == item.route;
          return GestureDetector(
            onTap: () {
              if (!isActive) Navigator.pushReplacementNamed(context, item.route);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1C1B1B) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 22,
                    color: isActive ? Colors.white : const Color(0xFF444748),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFF444748),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
