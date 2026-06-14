import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/employee_provider.dart';
import '../routes/app_routes.dart';
import '../utils/notification_helper.dart';
import '../widgets/app_bottom_nav.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(EmployeeProvider provider, int employeeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Karyawan'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus karyawan ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF444748))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Color(0xFFBA1A1A))),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteEmployee(employeeId);
      if (success && mounted) {
        showSuccessPopup(context, 'Karyawan berhasil dihapus');
      } else if (!success && mounted) {
        final errorMsg = provider.errorMessage ?? '';
        final isConflict = errorMsg.contains('409') ||
            errorMsg.toLowerCase().contains('conflict') ||
            errorMsg.contains('data terkait');
        showErrorPopup(
          context,
          isConflict
              ? 'Karyawan memiliki data terkait dan tidak dapat dihapus.'
              : errorMsg.isNotEmpty
                  ? errorMsg
                  : 'Gagal menghapus karyawan.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final employees = provider.employees.where((e) {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.phone.toLowerCase().contains(query);
    }).toList();

    final totalStaff = provider.employees.length;
    final activeCount = provider.employees.where((e) => e.status == 'aktif').length;
    final inactiveCount = provider.employees.where((e) => e.status == 'nonaktif').length;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            _buildAppBar(context),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.loadEmployees,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B)))
                    : provider.error != null
                        ? Center(
                            child: Text(
                              provider.error!,
                              style: const TextStyle(color: Color(0xFFBA1A1A)),
                            ),
                          )
                        : CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Staff Directory',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C1B1B),
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      // Search bar
                                      _buildSearchBar(),
                                      const SizedBox(height: 20),
                                      // Stats row
                                      _buildStatsRow(totalStaff, activeCount, inactiveCount),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                              // Employee cards
                              employees.isEmpty
                                  ? const SliverFillRemaining(
                                      child: Center(
                                        child: Text(
                                          'Belum ada data karyawan.',
                                          style: TextStyle(color: Color(0xFF444748)),
                                        ),
                                      ),
                                    )
                                  : SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final employee = employees[index];
                                            return _buildEmployeeCard(provider, employee);
                                          },
                                          childCount: employees.length,
                                        ),
                                      ),
                                    ),
                              const SliverToBoxAdapter(child: SizedBox(height: 80)),
                            ],
                          ),
              ),
            ),
            // Bottom Navigation
            const AppBottomNav(activeIndex: 1),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1C1B1B),
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.employeeForm);
          if (mounted) {
            provider.loadEmployees();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
          const Text(
            'Admin Portal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1B1B),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Search employees...',
          hintStyle: TextStyle(color: Color(0xFF858383), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Color(0xFF444748)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, int active, int inactive) {
    return Row(
      children: [
        _buildStatChip('Total Staff', '$total'),
        const SizedBox(width: 8),
        _buildStatChip('Active', '$active'),
        const SizedBox(width: 8),
        _buildStatChip('Inactive', '$inactive'),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1B1B),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF444748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeProvider provider, dynamic employee) {
    final isActive = employee.status == 'aktif';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1B1B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1B1B),
                        ),
                      ),
                    ),
                    // Status dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Colors.green : const Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF444748)),
                    const SizedBox(width: 4),
                    Text(
                      employee.phone,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF444748)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.employeeForm,
                    arguments: employee,
                  );
                  if (mounted) {
                    provider.loadEmployees();
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF444748)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _handleDelete(provider, employee.id),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF8F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outlined, size: 16, color: Color(0xFFBA1A1A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

