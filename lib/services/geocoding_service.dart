import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for reverse geocoding using OpenStreetMap Nominatim API.
/// Converts GPS coordinates to a human-readable address.
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Reverse geocode coordinates to an address string.
  /// Returns the display name (address) or null on failure.
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'ERP-Presensi-App/1.0',
        'Accept-Language': 'id',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
    } catch (_) {
      // Silently fail — address is optional
    }
    return null;
  }

  /// Get a shorter address (road + suburb/village + city).
  static Future<String?> getShortAddress(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'ERP-Presensi-App/1.0',
        'Accept-Language': 'id',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parts = <String>[];
          final road = address['road'] ?? address['pedestrian'] ?? address['path'];
          final village = address['village'] ?? address['suburb'] ?? address['neighbourhood'];
          final city = address['city'] ?? address['town'] ?? address['county'];

          if (road != null) parts.add(road as String);
          if (village != null) parts.add(village as String);
          if (city != null) parts.add(city as String);

          if (parts.isNotEmpty) return parts.join(', ');
        }

        // Fallback to display_name
        return data['display_name'] as String?;
      }
    } catch (_) {
      // Silently fail
    }
    return null;
  }
}
