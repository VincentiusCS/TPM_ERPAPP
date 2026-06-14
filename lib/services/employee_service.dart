import 'package:dio/dio.dart';

import '../models/employee.dart';
import 'api_client.dart';

/// EmployeeService handles CRUD API calls for the Employee module.
class EmployeeService {
  final ApiClient _apiClient;

  EmployeeService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /employees → returns list of all employees.
  Future<List<Employee>> getAll() async {
    final response = await _apiClient.get('/employees');
    // The API returns the array directly (not wrapped in a 'data' key)
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Employee.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /employees → creates a new employee.
  /// Throws [ValidationException] on HTTP 422 with field-level errors.
  Future<Employee> create({
    required String employeeName,
    required String phone,
    required String address,
    required String status,
  }) async {
    try {
      final response = await _apiClient.post(
        '/employees',
        data: {
          'employee_name': employeeName,
          'phone': phone,
          'address': address,
          'status': status,
        },
      );
      // The API returns the employee object directly
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw ValidationException(
          message: body?['message'] as String? ?? 'Validasi gagal',
          fieldErrors: _parseFieldErrors(body?['errors']),
        );
      }
      rethrow;
    }
  }

  /// PUT /employees/{id} → updates an existing employee.
  /// Throws [ValidationException] on HTTP 422 with field-level errors.
  Future<Employee> update({
    required int id,
    required String employeeName,
    required String phone,
    required String address,
    required String status,
  }) async {
    try {
      final response = await _apiClient.put(
        '/employees/$id',
        data: {
          'employee_name': employeeName,
          'phone': phone,
          'address': address,
          'status': status,
        },
      );
      // The API returns the employee object directly
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw ValidationException(
          message: body?['message'] as String? ?? 'Validasi gagal',
          fieldErrors: _parseFieldErrors(body?['errors']),
        );
      }
      rethrow;
    }
  }

  /// DELETE /employees/{id} → deletes an employee.
  /// Throws [ConflictException] on HTTP 409 when employee has related data.
  Future<void> delete(int id) async {
    try {
      await _apiClient.delete('/employees/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw ConflictException(
          message: body?['message'] as String? ??
              'Karyawan memiliki data terkait dan tidak dapat dihapus.',
        );
      }
      rethrow;
    }
  }

  /// Parses the `errors` field from a 422 response into a map of field → messages.
  Map<String, List<String>> _parseFieldErrors(dynamic errors) {
    if (errors == null || errors is! Map<String, dynamic>) {
      return {};
    }
    return errors.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((e) => e.toString()).toList(),
      ),
    );
  }
}

/// Thrown when the API returns HTTP 422 with field-level validation errors.
class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>> fieldErrors;

  ValidationException({required this.message, this.fieldErrors = const {}});

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when the API returns HTTP 409 (conflict, e.g. related data exists).
class ConflictException implements Exception {
  final String message;

  ConflictException({required this.message});

  @override
  String toString() => 'ConflictException: $message';
}
