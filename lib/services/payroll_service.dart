import '../models/payroll.dart';
import 'api_client.dart';

/// PayrollService handles API calls for the Payroll module.
class PayrollService {
  final ApiClient _apiClient;

  PayrollService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /payrolls → calculates and returns payroll data for the given period.
  ///
  /// Parameters:
  /// - `periodStart`: start date of the period (YYYY-MM-DD)
  /// - `periodEnd`: end date of the period (YYYY-MM-DD)
  /// - `search`: optional search keyword to filter by employee name
  ///
  /// Returns a [PayrollResult] containing the list of payrolls, total count,
  /// and an informational message.
  Future<PayrollResult> calculate({
    required String periodStart,
    required String periodEnd,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'period_start': periodStart,
      'period_end': periodEnd,
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      '/payrolls',
      queryParameters: queryParams,
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>;
    final payrolls = list
        .map((json) => Payroll.fromJson(json as Map<String, dynamic>))
        .toList();
    final total = data['total'] as int? ?? payrolls.length;
    final message = data['message'] as String? ?? '';

    return PayrollResult(
      payrolls: payrolls,
      total: total,
      message: message,
    );
  }

  /// GET /payrolls/download/report → downloads the payroll report as a file.
  ///
  /// Parameters:
  /// - `periodStart`: start date of the period (YYYY-MM-DD)
  /// - `periodEnd`: end date of the period (YYYY-MM-DD)
  /// - `savePath`: local file path where the report will be saved
  /// - `currency`: optional currency code for salary display (e.g. USD, EUR)
  /// - `timezone`: optional timezone abbreviation for the printed-at timestamp
  ///
  /// Returns the file path where the report was saved.
  Future<String> downloadReport({
    required String periodStart,
    required String periodEnd,
    required String savePath,
    String? currency,
    String? timezone,
  }) async {
    final queryParams = <String, dynamic>{
      'period_start': periodStart,
      'period_end': periodEnd,
    };
    if (currency != null) queryParams['currency'] = currency;
    if (timezone != null) queryParams['timezone'] = timezone;

    await _apiClient.download(
      '/payrolls/download/report',
      savePath,
      queryParameters: queryParams,
    );
    return savePath;
  }

  /// GET /payrolls/{employee_id}/slip → downloads the salary slip for an employee.
  ///
  /// Parameters:
  /// - `employeeId`: the employee's ID
  /// - `periodStart`: start date of the period (YYYY-MM-DD)
  /// - `periodEnd`: end date of the period (YYYY-MM-DD)
  /// - `savePath`: local file path where the slip will be saved
  /// - `currency`: optional currency code for salary display (e.g. USD, EUR)
  /// - `timezone`: optional timezone abbreviation for the printed-at timestamp
  ///
  /// Returns the file path where the slip was saved.
  Future<String> downloadSlip({
    required int employeeId,
    required String periodStart,
    required String periodEnd,
    required String savePath,
    String? currency,
    String? timezone,
  }) async {
    final queryParams = <String, dynamic>{
      'period_start': periodStart,
      'period_end': periodEnd,
    };
    if (currency != null) queryParams['currency'] = currency;
    if (timezone != null) queryParams['timezone'] = timezone;

    await _apiClient.download(
      '/payrolls/$employeeId/slip',
      savePath,
      queryParameters: queryParams,
    );
    return savePath;
  }
}

/// Holds the result of a payroll calculation request.
class PayrollResult {
  final List<Payroll> payrolls;
  final int total;
  final String message;

  PayrollResult({
    required this.payrolls,
    required this.total,
    required this.message,
  });
}
