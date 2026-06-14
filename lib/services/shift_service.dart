import 'package:dio/dio.dart';

import '../models/shift.dart';
import 'api_client.dart';
import 'employee_service.dart';

/// ShiftService handles API calls for the Shift module.
class ShiftService {
  final ApiClient _apiClient;

  ShiftService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /shifts → returns list of all shifts.
  Future<List<Shift>> getAll() async {
    final response = await _apiClient.get('/shifts');
    // The API returns the array directly (not wrapped in a 'data' key)
    final list = response.data as List<dynamic>;
    return list
        .map((json) => Shift.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// POST /shifts → creates a new shift.
  /// Throws [ConflictException] on HTTP 409 (duplicate shift for same employee+date).
  Future<Shift> create({
    required int employeeId,
    required DateTime shiftDate,
    double wagePerShift = 50000,
  }) async {
    try {
      final dateStr =
          '${shiftDate.year.toString().padLeft(4, '0')}-${shiftDate.month.toString().padLeft(2, '0')}-${shiftDate.day.toString().padLeft(2, '0')}';
      final response = await _apiClient.post(
        '/shifts',
        data: {
          'employee_id': employeeId,
          'shift_date': dateStr,
          'wage_per_shift': wagePerShift,
        },
      );
      // The API returns the shift object directly
      return Shift.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw ConflictException(
          message: body?['message'] as String? ??
              'Shift pada tanggal tersebut sudah terdaftar untuk karyawan ini.',
        );
      }
      rethrow;
    }
  }

  /// DELETE /shifts/{id} → deletes a shift.
  Future<void> delete(int id) async {
    await _apiClient.delete('/shifts/$id');
  }
}
