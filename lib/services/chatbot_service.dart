import 'api_client.dart';

/// Service for interacting with the Chatbot AI (Gemini) backend endpoints.
class ChatbotService {
  final ApiClient apiClient;

  ChatbotService({required this.apiClient});

  /// Fetches the list of available chatbot scenarios.
  /// Returns a list of scenario maps with keys: id, name, description.
  Future<List<Map<String, dynamic>>> getScenarios() async {
    final response = await apiClient.get('/chatbot/scenarios');
    final data = response.data as Map<String, dynamic>;
    final scenarios = data['scenarios'] as List<dynamic>;
    return scenarios.cast<Map<String, dynamic>>();
  }

  /// Sends a message within a chatbot session.
  /// Returns a map with keys: reply, session_id.
  Future<Map<String, dynamic>> sendMessage({
    required String scenarioId,
    required String sessionId,
    required String message,
  }) async {
    final response = await apiClient.post(
      '/chatbot/message',
      data: {
        'scenario_id': scenarioId,
        'session_id': sessionId,
        'message': message,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Requests feedback/evaluation for a completed chatbot session.
  /// Returns a map with keys: feedback, session_id.
  Future<Map<String, dynamic>> getFeedback({
    required String sessionId,
  }) async {
    final response = await apiClient.post(
      '/chatbot/feedback',
      data: {
        'session_id': sessionId,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
