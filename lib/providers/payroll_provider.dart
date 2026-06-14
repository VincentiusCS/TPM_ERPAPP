import 'package:flutter/material.dart';

import '../models/payroll.dart';
import '../services/payroll_service.dart';

/// PayrollProvider manages the state for payroll calculation results,
/// loading status, error messages, and download operations.
class PayrollProvider extends ChangeNotifier {
  final PayrollService? _payrollService;

  PayrollProvider({PayrollService? payrollService})
      : _payrollService = payrollService;

  List<Payroll> _payrollResults = [];
  int _total = 0;
  String _message = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<Payroll> get payrollResults => _payrollResults;

  /// Backward-compatible alias for [payrollResults].
  List<Payroll> get payrolls => _payrollResults;

  int get total => _total;
  String get message => _message;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Backward-compatible alias for [errorMessage].
  String? get error => _errorMessage;

  /// Clears any existing error state.
  void clearErrors() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Calculates payroll for the given period and optional search keyword.
  /// Stores results in [payrollResults], [total], and [message].
  Future<void> calculate({
    required String periodStart,
    required String periodEnd,
    String? search,
  }) async {
    if (_payrollService == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _payrollService.calculate(
        periodStart: periodStart,
        periodEnd: periodEnd,
        search: search,
      );
      _payrollResults = result.payrolls;
      _total = result.total;
      _message = result.message;
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible method that accepts DateTime parameters.
  Future<void> loadPayrolls({DateTime? start, DateTime? end}) async {
    final periodStart = start ?? DateTime.now().subtract(const Duration(days: 30));
    final periodEnd = end ?? DateTime.now();

    final startStr =
        '${periodStart.year.toString().padLeft(4, '0')}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}';
    final endStr =
        '${periodEnd.year.toString().padLeft(4, '0')}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}';

    await calculate(periodStart: startStr, periodEnd: endStr);
  }

  /// Downloads the payroll report for the given period.
  /// Returns the file path on success, or null on failure.
  Future<String?> downloadReport({
    required String periodStart,
    required String periodEnd,
    required String savePath,
    String? currency,
    String? timezone,
  }) async {
    if (_payrollService == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final filePath = await _payrollService.downloadReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        savePath: savePath,
        currency: currency,
        timezone: timezone,
      );
      return filePath;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Downloads the salary slip for a specific employee.
  /// Returns the file path on success, or null on failure.
  Future<String?> downloadSlip({
    required int employeeId,
    required String periodStart,
    required String periodEnd,
    required String savePath,
    String? currency,
    String? timezone,
  }) async {
    if (_payrollService == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final filePath = await _payrollService.downloadSlip(
        employeeId: employeeId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        savePath: savePath,
        currency: currency,
        timezone: timezone,
      );
      return filePath;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
