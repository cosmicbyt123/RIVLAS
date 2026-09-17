import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const String _keyTotalPushups = 'total_pushups';
  static const String _keyTotalPlankTime = 'total_plank_time';
  static const String _keyFlappyHighScore = 'flappy_high_score';
  static const String _keyWorkoutsCompleted = 'workouts_completed';

  static Future<int> getTotalPushups() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalPushups) ?? 0;
  }

  static Future<void> addPushups(int reps) async {
    if (reps <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalPushups) ?? 0;
    await prefs.setInt(_keyTotalPushups, current + reps);
  }

  static Future<int> getTotalPlankTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalPlankTime) ?? 0;
  }

  static Future<void> addPlankTime(int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyTotalPlankTime) ?? 0;
    await prefs.setInt(_keyTotalPlankTime, current + seconds);
  }

  static Future<int> getFlappyHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFlappyHighScore) ?? 0;
  }

  static Future<void> updateFlappyScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyFlappyHighScore) ?? 0;
    if (score > current) {
      await prefs.setInt(_keyFlappyHighScore, score);
    }
  }

  static Future<int> getWorkoutsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWorkoutsCompleted) ?? 0;
  }

  static Future<void> addWorkoutCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyWorkoutsCompleted) ?? 0;
    await prefs.setInt(_keyWorkoutsCompleted, current + 1);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
