import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../models/shift.dart';
import '../providers/auth_provider.dart';
import '../services/employee_service.dart';
import '../services/shift_service.dart';
import '../utils/notification_helper.dart';
import '../widgets/app_bottom_nav.dart';

class ShiftScreen extends StatefulWidget {
  final ShiftService shiftService;
  final EmployeeService employeeService;

  const ShiftScreen({
    super.key,
    required this.shiftService,
    required this.employeeService,
  });

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  List<Shift> _shifts = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = context.read<AuthProvider>().currentUser;
      final isAdmin = user?.role == 'admin';

      if (isAdmin) {
        final results = await Future.wait([
          widget.shiftService.getAll(),
          widget.employeeService.getAll(),
        ]);
        setState(() {
          _shifts = results[0] as List<Shift>;
          _employees = results[1] as List<Employee>;
          _isLoading = false;
        });
      } else {
        final shifts = await widget.shiftService.getAll();
        setState(() {
          _shifts = shifts;
          _employees = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat data: $e'; _isLoading = false; });
    }
  }

  String _getEmployeeName(int employeeId) {
    final employee = _employees.where((e) => e.id == employeeId).firstOrNull;
    return employee?.employeeName ?? 'Karyawan #$employeeId';
  }

  Future<void> _showAddShiftDialog() async {
    Employee? selectedEmployee;
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFFDF8F8),
              title: const Text('Tambah Shift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Employee>(
                        isExpanded: true,
                        value: selectedEmployee,
                        hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Pilih karyawan', style: TextStyle(color: Color(0xFF858383)))),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        items: _employees.map((employee) {
                          return DropdownMenuItem<Employee>(value: employee, child: Text(employee.employeeName));
                        }).toList(),
                        onChanged: (value) { setDialogState(() { selectedEmployee = value; }); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (date != null) { setDialogState(() { selectedDate = date; }); }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF444748)),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'Pilih Tanggal',
                            style: TextStyle(fontSize: 14, color: selectedDate != null ? const Color(0xFF1C1B1B) : const Color(0xFF858383)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal', style: TextStyle(color: Color(0xFF444748)))),
                ElevatedButton(
                  onPressed: (selectedEmployee != null && selectedDate != null)
                      ? () { Navigator.pop(dialogContext, {'employee': selectedEmployee, 'date': selectedDate}); }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null) {
        await _createShift(result['employee'] as Employee, result['date'] as DateTime);
      }
    });
  }

  Future<void> _createShift(Employee employee, DateTime date) async {
    try {
      await widget.shiftService.create(employeeId: employee.id, shiftDate: date);
      await _loadData();
      if (mounted) {
        showSuccessPopup(context, 'Shift berhasil ditambahkan');
      }
    } on ConflictException catch (e) {
      if (mounted) {
        showErrorPopup(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        showErrorPopup(context, 'Gagal menambah shift: $e');
      }
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Shift'),
          content: const Text('Apakah Anda yakin ingin menghapus shift ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Color(0xFF444748)))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Color(0xFFBA1A1A)))),
          ],
        );
      },
    );
    if (confirmed == true) {
      try {
        await widget.shiftService.delete(shift.id);
        await _loadData();
        if (mounted) {
          showSuccessPopup(context, 'Shift berhasil dihapus');
        }
      } catch (e) {
        if (mounted) {
          showErrorPopup(context, 'Gagal menghapus shift: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B)))
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A))))
                        : _shifts.isEmpty
                            ? const Center(child: Text('Belum ada data shift.', style: TextStyle(color: Color(0xFF444748))))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _shifts.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: Text(
                                        isAdmin ? 'Shift Management' : 'My Shifts',
                                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B), letterSpacing: -0.6),
                                      ),
                                    );
                                  }
                                  final shift = _shifts[index - 1];
                                  return _buildShiftCard(shift);
                                },
                              ),
              ),
            ),
            const AppBottomNav(),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1C1B1B),
              onPressed: _showAddShiftDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    final user = context.watch<AuthProvider>().currentUser;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1C1B1B)),
          ),
          const SizedBox(width: 12),
          Text(
            user?.role == 'admin' ? 'Admin Portal' : 'Employee Portal',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Shift shift) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.role == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFF1EDEC), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.schedule_outlined, size: 20, color: Color(0xFF1C1B1B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.employeeName ?? _getEmployeeName(shift.employeeId),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('yyyy-MM-dd').format(shift.shiftDate)} • Rp${NumberFormat('#,###').format(shift.wagePerShift)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF444748)),
                ),
              ],
            ),
          ),
          if (isAdmin)
            GestureDetector(
              onTap: () => _deleteShift(shift),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFFFDF8F8), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outlined, size: 16, color: Color(0xFFBA1A1A)),
              ),
            ),
        ],
      ),
    );
  }
}
