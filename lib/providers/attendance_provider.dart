import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/attendance_service.dart';

/// AttendanceProvider manages the state for attendance records,
/// active filters, loading status, and error messages.
class AttendanceProvider extends ChangeNotifier {
  final AttendanceService? _attendanceService;

  AttendanceProvider({AttendanceService? attendanceService})
      : _attendanceService = attendanceService;

  List<Attendance> _attendances = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, List<String>> _fieldErrors = {};

  // Active filters
  int? _filterEmployeeId;
  String? _filterDateFrom;
  String? _filterDateTo;

  List<Attendance> get attendances => _attendances;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  /// Backward-compatible alias for [errorMessage].
  String? get error => _errorMessage;

  // Filter getters
  int? get filterEmployeeId => _filterEmployeeId;
  String? get filterDateFrom => _filterDateFrom;
  String? get filterDateTo => _filterDateTo;

  /// Clears any existing error state.
  void clearErrors() {
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();
  }

  /// Sets the active filters without fetching.
  void setFilters({
    int? employeeId,
    String? dateFrom,
    String? dateTo,
  }) {
    _filterEmployeeId = employeeId;
    _filterDateFrom = dateFrom;
    _filterDateTo = dateTo;
  }

  /// Clears all active filters.
  void clearFilters() {
    _filterEmployeeId = null;
    _filterDateFrom = null;
    _filterDateTo = null;
  }

  /// Fetches attendances from the API with optional filters.
  /// If filters are provided, they override the stored active filters.
  Future<void> fetchAll({
    int? employeeId,
    String? dateFrom,
    String? dateTo,
  }) async {
    if (_attendanceService == null) return;

    // Update active filters if provided
    if (employeeId != null) _filterEmployeeId = employeeId;
    if (dateFrom != null) _filterDateFrom = dateFrom;
    if (dateTo != null) _filterDateTo = dateTo;

    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      _attendances = await _attendanceService.getAll(
        employeeId: _filterEmployeeId,
        dateFrom: _filterDateFrom,
        dateTo: _filterDateTo,
      );
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible alias: loads attendances for a specific date.
  Future<void> loadAttendances({DateTime? date}) async {
    if (_attendanceService == null) return;

    String? dateStr;
    if (date != null) {
      dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    await fetchAll(dateFrom: dateStr, dateTo: dateStr);
  }

  /// Creates a new attendance record. Returns true on success, false on failure.
  /// On HTTP 422, populates [errorMessage] and [fieldErrors].
  Future<bool> create({
    required int employeeId,
    required int shiftId,
    required String attendanceDate,
    required String status,
  }) async {
    if (_attendanceService == null) return false;

    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final newAttendance = await _attendanceService.create(
        employeeId: employeeId,
        shiftId: shiftId,
        attendanceDate: attendanceDate,
        status: status,
      );
      _attendances.add(newAttendance);
      return true;
    } on AttendanceValidationException catch (e) {
      _errorMessage = e.message;
      _fieldErrors = e.fieldErrors;
      return false;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the status of an existing attendance record.
  /// Returns true on success, false on failure.
  Future<bool> update({
    required int id,
    required String status,
  }) async {
    if (_attendanceService == null) return false;

    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final updated = await _attendanceService.update(
        id: id,
        status: status,
      );
      final index = _attendances.indexWhere((a) => a.id == updated.id);
      if (index >= 0) {
        _attendances[index] = updated;
      }
      return true;
    } on AttendanceValidationException catch (e) {
      _errorMessage = e.message;
      _fieldErrors = e.fieldErrors;
      return false;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible helper: finds attendance for a specific employee on a date.
  Attendance attendanceForEmployee(int employeeId, DateTime date) {
    return _attendances.firstWhere(
      (attendance) =>
          attendance.employeeId == employeeId &&
          attendance.attendanceDate.year == date.year &&
          attendance.attendanceDate.month == date.month &&
          attendance.attendanceDate.day == date.day,
      orElse: () => Attendance(
        id: 0,
        employeeId: employeeId,
        shiftId: 0,
        attendanceDate: date,
        status: 'tidak hadir',
      ),
    );
  }

  /// Backward-compatible method to save attendance from an Employee object.
  Future<bool> saveAttendance(
    Employee employee,
    DateTime date,
    String status, {
    int shiftId = 0,
  }) async {
    if (_attendanceService == null) return false;

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Check if an attendance already exists for this employee on this date
    final existing = _attendances.where(
      (a) =>
          a.employeeId == employee.id &&
          a.attendanceDate.year == date.year &&
          a.attendanceDate.month == date.month &&
          a.attendanceDate.day == date.day,
    );

    if (existing.isNotEmpty) {
      // Update existing record
      return update(id: existing.first.id, status: status);
    } else {
      // Create new record
      final success = await create(
        employeeId: employee.id,
        shiftId: shiftId,
        attendanceDate: dateStr,
        status: status,
      );
      if (success) {
        await loadAttendances(date: date);
      }
      return success;
    }
  }
}
