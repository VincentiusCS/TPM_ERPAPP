import 'package:dio/dio.dart';

import 'api_client.dart';

/// CurrencyService handles API calls for the Currency Conversion module.
class CurrencyService {
  final ApiClient _apiClient;

  CurrencyService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// POST /currency/convert → converts IDR amount to target currency.
  ///
  /// Parameters:
  /// - `payrollId`: the payroll ID to associate with this conversion log
  /// - `amountIdr`: the amount in IDR to convert
  /// - `targetCurrency`: target currency code (USD, EUR, GBP)
  ///
  /// Returns a [CurrencyConversionResult] on success.
  /// Throws [CurrencyConversionException] on failure.
  Future<CurrencyConversionResult> convert({
    int? payrollId,
    required double amountIdr,
    required String targetCurrency,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'amount_idr': amountIdr,
        'target_currency': targetCurrency,
      };
      if (payrollId != null) {
        requestData['payroll_id'] = payrollId;
      }

      final response = await _apiClient.post(
        '/currency/convert',
        data: requestData,
      );

      final data = response.data as Map<String, dynamic>;
      return CurrencyConversionResult.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        throw CurrencyConversionException(
          'Data kurs tidak dapat diambil saat ini. Silakan coba lagi nanti.',
        );
      } else if (e.response?.statusCode == 422) {
        final message =
            e.response?.data?['message'] as String? ?? 'Mata uang tidak didukung.';
        throw CurrencyConversionException(message);
      }
      throw CurrencyConversionException(
        'Terjadi kesalahan saat melakukan konversi.',
      );
    }
  }
}

/// Holds the result of a currency conversion request.
class CurrencyConversionResult {
  final String sourceCurrency;
  final String targetCurrency;
  final double exchangeRate;
  final double convertedAmount;
  final int logId;

  CurrencyConversionResult({
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.exchangeRate,
    required this.convertedAmount,
    required this.logId,
  });

  factory CurrencyConversionResult.fromJson(Map<String, dynamic> json) {
    return CurrencyConversionResult(
      sourceCurrency: json['source_currency'] as String,
      targetCurrency: json['target_currency'] as String,
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      convertedAmount: (json['converted_amount'] as num).toDouble(),
      logId: json['log_id'] as int,
    );
  }
}

/// Exception thrown when currency conversion fails.
class CurrencyConversionException implements Exception {
  final String message;

  CurrencyConversionException(this.message);

  @override
  String toString() => message;
}
