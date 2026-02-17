import 'package:shared_preferences/shared_preferences.dart';

class ActiveMeetingStorage {
  static const _key = 'active_meeting_id';

  static Future<void> set(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, meetingId);
  }

  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
