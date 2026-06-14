import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../providers/attendance_provider.dart';
import '../providers/employee_provider.dart';
import '../services/shift_service.dart';
import '../utils/notification_helper.dart';
import '../widgets/app_bottom_nav.dart';

class AttendanceScreen extends StatefulWidget {
  final ShiftService shiftService;

  const AttendanceScreen({super.key, required this.shiftService});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int? _filterEmployeeId;
  DateTimeRange? _filterDateRange;
  List<Shift> _shifts = [];
  bool _shiftsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final employeeProvider = context.read<EmployeeProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    await employeeProvider.fetchAll();
    await attendanceProvider.fetchAll();
    await _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _shiftsLoading = true);
    try {
      final shifts = await widget.shiftService.getAll();
      setState(() {
        _shifts = shifts;
        _shiftsLoading = false;
      });
    } catch (_) {
      setState(() => _shiftsLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    String? dateFrom;
    String? dateTo;
    if (_filterDateRange != null) {
      dateFrom = _formatDate(_filterDateRange!.start);
      dateTo = _formatDate(_filterDateRange!.end);
    }
    await attendanceProvider.fetchAll(
      employeeId: _filterEmployeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filterDateRange,
    );
    if (picked != null) {
      setState(() => _filterDateRange = picked);
      await _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _filterEmployeeId = null;
      _filterDateRange = null;
    });
    final attendanceProvider = context.read<AttendanceProvider>();
    attendanceProvider.clearFilters();
    attendanceProvider.fetchAll();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getEmployeeName(int employeeId) {
    final employees = context.read<EmployeeProvider>().employees;
    final employee = employees.where((e) => e.id == employeeId).firstOrNull;
    return employee?.name ?? 'Karyawan #$employeeId';
  }

  void _showAddAttendanceDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _AttendanceFormDialog(
        employees: context.read<EmployeeProvider>().employees,
        shifts: _shifts,
        onSave: (employeeId, shiftId, date, status) async {
          final provider = context.read<AttendanceProvider>();
          final success = await provider.create(
            employeeId: employeeId,
            shiftId: shiftId,
            attendanceDate: _formatDate(date),
            status: status,
          );
          if (success && mounted) {
            showSuccessPopup(context, 'Presensi berhasil dicatat');
            await _applyFilters();
          }
          return success;
        },
        getErrorMessage: () => context.read<AttendanceProvider>().errorMessage,
        getFieldErrors: () => context.read<AttendanceProvider>().fieldErrors,
      ),
    );
  }

  void _showEditAttendanceDialog(Attendance attendance) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditAttendanceDialog(
        attendance: attendance,
        employeeName: _getEmployeeName(attendance.employeeId),
        onSave: (status) async {
          final provider = context.read<AttendanceProvider>();
          final success = await provider.update(
            id: attendance.id,
            status: status,
          );
          if (success && mounted) {
            showSuccessPopup(context, 'Status presensi berhasil diubah');
            await _applyFilters();
          }
          return success;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Column(
                children: [
                  // Filters
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Attendance',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B), letterSpacing: -0.6),
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(employeeProvider),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: _buildAttendanceList(attendanceProvider),
                  ),
                ],
              ),
            ),
            const AppBottomNav(activeIndex: 2),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1C1B1B),
        onPressed: _showAddAttendanceDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          const Text('Admin Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFilterSection(EmployeeProvider employeeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employee filter
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonFormField<int?>(
            key: ValueKey('filter_employee_$_filterEmployeeId'),
            initialValue: _filterEmployeeId,
            decoration: const InputDecoration(
              labelText: 'Employee',
              labelStyle: TextStyle(color: Color(0xFF444748), fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Employees')),
              ...employeeProvider.employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
            ],
            onChanged: (value) {
              setState(() => _filterEmployeeId = value);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(height: 12),
        // Date range
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_outlined, size: 16, color: Color(0xFF444748)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _filterDateRange != null
                              ? '${_formatDateDisplay(_filterDateRange!.start)} - ${_formatDateDisplay(_filterDateRange!.end)}'
                              : 'Select Date Range',
                          style: TextStyle(fontSize: 14, color: _filterDateRange != null ? const Color(0xFF1C1B1B) : const Color(0xFF858383)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_filterEmployeeId != null || _filterDateRange != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearFilters,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.clear, size: 18, color: Color(0xFF444748)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceList(AttendanceProvider attendanceProvider) {
    if (attendanceProvider.isLoading || _shiftsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B)));
    }
    if (attendanceProvider.errorMessage != null) {
      return Center(child: Text(attendanceProvider.errorMessage!, style: const TextStyle(color: Color(0xFFBA1A1A))));
    }
    if (attendanceProvider.attendances.isEmpty) {
      return const Center(child: Text('Tidak ada data presensi.', style: TextStyle(color: Color(0xFF444748))));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: attendanceProvider.attendances.length,
      itemBuilder: (context, index) {
        final attendance = attendanceProvider.attendances[index];
        return _buildAttendanceRow(attendance);
      },
    );
  }

  Widget _buildAttendanceRow(Attendance attendance) {
    final isPresent = attendance.status == 'hadir';
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
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPresent ? const Color(0xFF1C1B1B) : const Color(0xFFBA1A1A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getEmployeeName(attendance.employeeId),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B)),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateDisplay(attendance.attendanceDate),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF444748)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPresent ? const Color(0xFFF7F3F2) : const Color(0xFFFDF8F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              attendance.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isPresent ? const Color(0xFF1C1B1B) : const Color(0xFFBA1A1A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEditAttendanceDialog(attendance),
            child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF444748)),
          ),
        ],
      ),
    );
  }
}

// --- Dialogs (preserved logic, updated styling) ---

class _AttendanceFormDialog extends StatefulWidget {
  final List<Employee> employees;
  final List<Shift> shifts;
  final Future<bool> Function(int employeeId, int shiftId, DateTime date, String status) onSave;
  final String? Function() getErrorMessage;
  final Map<String, List<String>> Function() getFieldErrors;

  const _AttendanceFormDialog({
    required this.employees,
    required this.shifts,
    required this.onSave,
    required this.getErrorMessage,
    required this.getFieldErrors,
  });

  @override
  State<_AttendanceFormDialog> createState() => _AttendanceFormDialogState();
}

class _AttendanceFormDialogState extends State<_AttendanceFormDialog> {
  int? _selectedEmployeeId;
  int? _selectedShiftId;
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'hadir';
  bool _isSaving = false;
  String? _employeeError;
  String? _shiftError;

  List<Shift> get _filteredShifts {
    if (_selectedEmployeeId == null) return [];
    return widget.shifts.where((s) => s.employeeId == _selectedEmployeeId).toList();
  }

  bool _validateLocally() {
    setState(() { _employeeError = null; _shiftError = null; });
    bool valid = true;
    if (_selectedEmployeeId == null) { setState(() => _employeeError = 'Karyawan wajib dipilih'); valid = false; }
    if (_selectedShiftId == null) { setState(() => _shiftError = 'Shift wajib dipilih'); valid = false; }
    return valid;
  }

  Future<void> _save() async {
    if (!_validateLocally()) return;
    setState(() => _isSaving = true);
    final success = await widget.onSave(_selectedEmployeeId!, _selectedShiftId!, _selectedDate, _selectedStatus);
    setState(() => _isSaving = false);
    if (success && mounted) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatShiftLabel(Shift shift) {
    final dateStr = '${shift.shiftDate.day.toString().padLeft(2, '0')}/${shift.shiftDate.month.toString().padLeft(2, '0')}/${shift.shiftDate.year}';
    return 'Shift $dateStr (Rp${shift.wagePerShift.toStringAsFixed(0)})';
  }

  @override
  Widget build(BuildContext context) {
    final serverError = widget.getErrorMessage();
    final fieldErrors = widget.getFieldErrors();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFDF8F8),
      title: const Text('Catat Presensi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              key: ValueKey('form_employee_$_selectedEmployeeId'),
              initialValue: _selectedEmployeeId,
              decoration: InputDecoration(
                labelText: 'Karyawan *',
                filled: true,
                fillColor: const Color(0xFFF7F3F2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                errorText: _employeeError ?? fieldErrors['employee_id']?.firstOrNull,
              ),
              items: widget.employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))).toList(),
              onChanged: (value) { setState(() { _selectedEmployeeId = value; _selectedShiftId = null; _employeeError = null; }); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey('form_shift_${_selectedEmployeeId}_$_selectedShiftId'),
              initialValue: _selectedShiftId,
              decoration: InputDecoration(
                labelText: 'Shift *',
                filled: true,
                fillColor: const Color(0xFFF7F3F2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                errorText: _shiftError ?? fieldErrors['shift_id']?.firstOrNull,
              ),
              items: _filteredShifts.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(_formatShiftLabel(s)))).toList(),
              onChanged: _selectedEmployeeId == null ? null : (value) { setState(() { _selectedShiftId = value; _shiftError = null; }); },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Tanggal: ${_formatDate(_selectedDate)}', style: const TextStyle(color: Color(0xFF1C1B1B)))),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: const Text('Ubah', style: TextStyle(color: Color(0xFF1C1B1B))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                filled: true,
                fillColor: const Color(0xFFF7F3F2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                DropdownMenuItem(value: 'tidak hadir', child: Text('Tidak Hadir')),
              ],
              onChanged: (value) { if (value != null) setState(() => _selectedStatus = value); },
            ),
            if (serverError != null) ...[
              const SizedBox(height: 12),
              Text(serverError, style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Batal', style: TextStyle(color: Color(0xFF444748)))),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _EditAttendanceDialog extends StatefulWidget {
  final Attendance attendance;
  final String employeeName;
  final Future<bool> Function(String status) onSave;

  const _EditAttendanceDialog({required this.attendance, required this.employeeName, required this.onSave});

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  late String _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.attendance.status;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final success = await widget.onSave(_selectedStatus);
    setState(() => _isSaving = false);
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.attendance.attendanceDate.day.toString().padLeft(2, '0')}/${widget.attendance.attendanceDate.month.toString().padLeft(2, '0')}/${widget.attendance.attendanceDate.year}';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFDF8F8),
      title: const Text('Edit Status Presensi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Karyawan: ${widget.employeeName}', style: const TextStyle(color: Color(0xFF1C1B1B))),
          const SizedBox(height: 4),
          Text('Tanggal: $dateStr', style: const TextStyle(color: Color(0xFF444748))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              filled: true,
              fillColor: const Color(0xFFF7F3F2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
              DropdownMenuItem(value: 'tidak hadir', child: Text('Tidak Hadir')),
            ],
            onChanged: (value) { if (value != null) setState(() => _selectedStatus = value); },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Batal', style: TextStyle(color: Color(0xFF444748)))),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
        ),
      ],
    );
  }
}

