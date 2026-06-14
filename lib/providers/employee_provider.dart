import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../services/employee_service.dart';

/// EmployeeProvider manages the state for the employee list,
/// loading status, and error messages (including field-level validation).
class EmployeeProvider extends ChangeNotifier {
  final EmployeeService _employeeService;

  EmployeeProvider({required EmployeeService employeeService})
      : _employeeService = employeeService;

  List<Employee> _employees = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, List<String>> _fieldErrors = {};

  List<Employee> get employees => _employees;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  /// Backward-compatible alias for [errorMessage].
  String? get error => _errorMessage;

  /// Clears any existing error state.
  void clearErrors() {
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();
  }

  /// Fetches all employees from the API.
  Future<void> fetchAll() async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      _employees = await _employeeService.getAll();
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible alias for [fetchAll].
  Future<void> loadEmployees() => fetchAll();

  /// Creates a new employee. Returns true on success, false on failure.
  /// On HTTP 422, populates [fieldErrors] with per-field messages.
  Future<bool> create({
    required String employeeName,
    required String phone,
    required String address,
    required String status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final newEmployee = await _employeeService.create(
        employeeName: employeeName,
        phone: phone,
        address: address,
        status: status,
      );
      _employees.add(newEmployee);
      return true;
    } on ValidationException catch (e) {
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

  /// Backward-compatible method that accepts an [Employee] object.
  Future<bool> addEmployee(Employee employee) {
    return create(
      employeeName: employee.employeeName,
      phone: employee.phone,
      address: employee.address,
      status: employee.status,
    );
  }

  /// Updates an existing employee. Returns true on success, false on failure.
  /// On HTTP 422, populates [fieldErrors] with per-field messages.
  Future<bool> update({
    required int id,
    required String employeeName,
    required String phone,
    required String address,
    required String status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final updated = await _employeeService.update(
        id: id,
        employeeName: employeeName,
        phone: phone,
        address: address,
        status: status,
      );
      final index = _employees.indexWhere((e) => e.id == updated.id);
      if (index >= 0) {
        _employees[index] = updated;
      }
      return true;
    } on ValidationException catch (e) {
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

  /// Backward-compatible method that accepts an [Employee] object.
  Future<bool> updateEmployee(Employee employee) {
    return update(
      id: employee.id,
      employeeName: employee.employeeName,
      phone: employee.phone,
      address: employee.address,
      status: employee.status,
    );
  }

  /// Deletes an employee by ID. Returns true on success, false on failure.
  /// On HTTP 409 (conflict), populates [errorMessage] with the conflict reason.
  Future<bool> delete(int id) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      await _employeeService.delete(id);
      _employees.removeWhere((e) => e.id == id);
      return true;
    } on ConflictException catch (e) {
      _errorMessage = e.message;
      return false;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible alias for [delete].
  Future<bool> deleteEmployee(int id) => delete(id);
}
