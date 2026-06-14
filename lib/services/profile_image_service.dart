import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  static const _key = 'profile_image_path';

  static Future<String?> getImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  static Future<void> clearImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
