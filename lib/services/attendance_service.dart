import 'package:dio/dio.dart';

import '../models/attendance.dart';
import 'api_client.dart';

/// AttendanceService handles API calls for the Attendance module.
class AttendanceService {
  final ApiClient _apiClient;

  AttendanceService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /attendances → returns list of attendances with optional filters.
  ///
  /// Supported filters:
  /// - `employee_id`: filter by employee
  /// - `date_from`: filter from date (inclusive)
  /// - `date_to`: filter to date (inclusive)
  Future<List<Attendance>> getAll({
    int? employeeId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (employeeId != null) {
      queryParams['employee_id'] = employeeId;
    }
    if (dateFrom != null) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null) {
      queryParams['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      '/attendances',
      queryParameters: queryParams,
    );
    // The API returns the array directly (not wrapped in a 'data' key)
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Attendance.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /attendances → creates a new attendance record.
  /// Throws [AttendanceValidationException] on HTTP 422.
  Future<Attendance> create({
    required int employeeId,
    required int shiftId,
    required String attendanceDate,
    required String status,
  }) async {
    try {
      final response = await _apiClient.post(
        '/attendances',
        data: {
          'employee_id': employeeId,
          'shift_id': shiftId,
          'attendance_date': attendanceDate,
          'status': status,
        },
      );
      // The API returns the attendance object directly
      return Attendance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
        throw AttendanceValidationException(
          message: responseData['message']?.toString() ?? 'Validasi gagal',
          fieldErrors: e.response?.statusCode == 422
              ? _parseFieldErrors(responseData['errors'])
              : const {},
        );
      }
      rethrow;
    }
  }

  /// PUT /attendances/{id} → updates the status of an existing attendance.
  /// Throws [AttendanceValidationException] on HTTP 422.
  Future<Attendance> update({
    required int id,
    required String status,
  }) async {
    try {
      final response = await _apiClient.put(
        '/attendances/$id',
        data: {
          'status': status,
        },
      );
      // The API returns the attendance object directly
      return Attendance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
        throw AttendanceValidationException(
          message: responseData['message']?.toString() ?? 'Validasi gagal',
          fieldErrors: e.response?.statusCode == 422
              ? _parseFieldErrors(responseData['errors'])
              : const {},
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
class AttendanceValidationException implements Exception {
  final String message;
  final Map<String, List<String>> fieldErrors;

  AttendanceValidationException({
    required this.message,
    this.fieldErrors = const {},
  });

  @override
  String toString() => 'AttendanceValidationException: $message';
}
