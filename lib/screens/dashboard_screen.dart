import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../services/profile_image_service.dart';
import '../widgets/app_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path = await ProfileImageService.getImagePath();
    if (mounted) setState(() { _imagePath = path; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top AppBar
            _buildAppBar(context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Quick Actions
                    _buildSectionLabel('QUICK ACTIONS'),
                    const SizedBox(height: 12),
                    _buildQuickActions(context),
                    const SizedBox(height: 32),
                    // Profile Card
                    _buildSectionLabel('PROFILE'),
                    const SizedBox(height: 12),
                    _buildProfileCard(context),
                    const SizedBox(height: 12),
                    _buildKesanPesanButton(context),
                    const SizedBox(height: 32),
                    // Navigation Grid
                    _buildSectionLabel('MODULES'),
                    const SizedBox(height: 12),
                    _buildModuleGrid(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Bottom Navigation
            const AppBottomNav(activeIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            user?.role == 'admin' ? 'Admin Portal' : 'Employee Portal',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1B1B),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF444748)),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: Color(0xFF444748),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.role == 'admin';
    return Row(
      children: [
        if (isAdmin) ...[
          Expanded(
            child: _QuickActionButton(
              icon: Icons.person_add_outlined,
              label: 'Add Employee',
              onTap: () => Navigator.pushNamed(context, AppRoutes.employeeForm),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _QuickActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Record Attendance',
            onTap: () => Navigator.pushNamed(context, AppRoutes.attendance),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.payments_outlined,
              label: 'Calculate Payroll',
              onTap: () => Navigator.pushNamed(context, AppRoutes.payroll),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initial = (user?.name ?? 'U').substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.profile).then((_) => _loadImage()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1B1B),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _imagePath != null && File(_imagePath!).existsSync()
                    ? Image.file(File(_imagePath!), fit: BoxFit.cover, width: 48, height: 48)
                    : Center(
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF444748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIM: ${user?.nim ?? '-'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF444748),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF444748), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKesanPesanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.kesanPesan),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Kesan & Pesan TPM',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.role == 'admin';
    final modules = [
      if (isAdmin)
        _ModuleItem(icon: Icons.group_outlined, label: 'Staff', route: AppRoutes.employees),
      _ModuleItem(icon: Icons.schedule_outlined, label: 'Shifts', route: AppRoutes.shifts),
      _ModuleItem(icon: Icons.fact_check_outlined, label: 'Attendance', route: AppRoutes.attendance),
      _ModuleItem(icon: Icons.payments_outlined, label: 'Payroll', route: AppRoutes.payroll),
      _ModuleItem(icon: Icons.forum_outlined, label: 'Chatbot', route: AppRoutes.chatbot),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: modules.map((m) => _buildModuleTile(context, m)).toList(),
    );
  }

  Widget _buildModuleTile(BuildContext context, _ModuleItem item) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        width: (MediaQuery.of(context).size.width - 44) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 24, color: const Color(0xFF1C1B1B)),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  final IconData icon;
  final String label;
  final String route;

  _ModuleItem({required this.icon, required this.label, required this.route});
}
