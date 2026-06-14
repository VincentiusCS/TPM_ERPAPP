import 'api_client.dart';

/// Service for retrieving employee performance analytics from backend.
class AnalyticsService {
  final ApiClient apiClient;

  AnalyticsService({required this.apiClient});

  /// Fetches the company-wide performance analytics.
  /// Returns a map with keys: average_rate, distribution, employees, algorithm, centroids.
  Future<Map<String, dynamic>> getPerformanceAnalytics() async {
    final response = await apiClient.get('/analytics/performance');
    return response.data as Map<String, dynamic>;
  }
}
