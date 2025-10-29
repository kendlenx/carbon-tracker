import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../services/database_service.dart';

class WeeklyChallenge {
  final String id;
  final String title;
  final String description;
  final int target;
  final int progress;
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    required this.weekStart,
    required this.weekEnd,
  });

  double get completion => target == 0 ? 0 : (progress / target).clamp(0, 1);
}

/// Simple gamification service for streaks, weekly challenges, and leaderboard stubs
class GamificationService extends ChangeNotifier {
  GamificationService._();
  static GamificationService? _instance;
  static GamificationService get instance => _instance ??= GamificationService._();

  static const _streakKey = 'streak_count';
  static const _lastActivityKey = 'streak_last_activity';

  int _streak = 0;
  int get streak => _streak;

  Future<void> initialize() async {
    await _loadStreak();
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt(_streakKey) ?? 0;
  }

  /// Call this when a user logs any activity
  Future<void> onActivityLogged() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastStr = prefs.getString(_lastActivityKey);
    DateTime? last = lastStr != null ? DateTime.tryParse(lastStr) : null;

    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

    if (last == null) {
      _streak = 1;
    } else if (sameDay(now, last)) {
      // same day, do nothing
    } else if (sameDay(now.subtract(const Duration(days: 1)), last)) {
      _streak += 1;
    } else {
      _streak = 1; // reset
    }

    await prefs.setInt(_streakKey, _streak);
    await prefs.setString(_lastActivityKey, now.toIso8601String());
    notifyListeners();
  }

  /// Very lightweight weekly challenge based on number of activities logged this week
  Future<WeeklyChallenge> getWeeklyChallenge() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    final activities = await DatabaseService.instance.getTransportActivities(
      startDate: DateTime(weekStart.year, weekStart.month, weekStart.day),
      endDate: DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
    );

    final progress = activities.length;
    final target = 7; // 7 logs / week target

    return WeeklyChallenge(
      id: 'weekly_logs',
      title: 'Haftalık Meydan Okuma',
      description: 'Bu hafta 7 aktivite kaydet',
      target: target,
      progress: progress,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }

  /// Local mock leaderboard (can be backed by Firestore in future)
  Future<List<Map<String, dynamic>>> getLocalLeaderboard() async {
    // Mock top 5 using streak as score
    return List.generate(5, (i) => {
      'name': 'User ${i + 1}',
      'score': math.max(1, _streak - i),
    });
  }
}
