import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum AchievementType {
  daily,
  weekly,
  monthly,
  streak,
  milestone,
  special,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color color;
  final AchievementType type;
  final double targetValue;
  final String unit;
  final DateTime? unlockedAt;
  final bool isUnlocked;
  final double currentProgress;
  final int points;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
    required this.targetValue,
    required this.unit,
    this.unlockedAt,
    this.isUnlocked = false,
    this.currentProgress = 0.0,
    this.points = 10,
  });

  double get progressPercentage => 
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    Color? color,
    AchievementType? type,
    double? targetValue,
    String? unit,
    DateTime? unlockedAt,
    bool? isUnlocked,
    double? currentProgress,
    int? points,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      currentProgress: currentProgress ?? this.currentProgress,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'isUnlocked': isUnlocked,
      'currentProgress': currentProgress,
    };
  }

  static Achievement fromJson(Map<String, dynamic> json, Achievement template) {
    return template.copyWith(
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt'])
          : null,
      isUnlocked: json['isUnlocked'] ?? false,
      currentProgress: json['currentProgress'] ?? 0.0,
    );
  }
}

class AchievementService extends ChangeNotifier {
  static AchievementService? _instance;
  static AchievementService get instance => _instance ??= AchievementService._();
  
  AchievementService._();

  static const String _achievementsKey = 'user_achievements';
  List<Achievement> _achievements = [];
  int _totalPoints = 0;

  List<Achievement> get achievements => _achievements;
  List<Achievement> get unlockedAchievements => 
      _achievements.where((a) => a.isUnlocked).toList();
  int get totalPoints => _totalPoints;
  int get totalAchievements => _achievements.length;
  int get unlockedCount => unlockedAchievements.length;

  // Predefined achievements
  static final List<Achievement> _defaultAchievements = [
    // Daily Achievements
    Achievement(
      id: 'first_day',
      title: 'İlk Adım',
      description: 'İlk karbon ayak izi kaydını yaptın!',
      icon: '🌱',
      color: Colors.green,
      type: AchievementType.daily,
      targetValue: 1,
      unit: 'aktivite',
      points: 10,
    ),
    Achievement(
      id: 'eco_warrior',
      title: 'Çevre Savaşçısı',
      description: 'Günlük hedefin altında kaldın!',
      icon: '⚡',
      color: Colors.blue,
      type: AchievementType.daily,
      targetValue: 20,
      unit: 'kg CO₂',
      points: 15,
    ),
    Achievement(
      id: 'green_day',
      title: 'Yeşil Gün',
      description: '10 kg CO₂\'nin altında bir gün geçirdin!',
      icon: '💚',
      color: Colors.green,
      type: AchievementType.daily,
      targetValue: 10,
      unit: 'kg CO₂',
      points: 25,
    ),
    
    // Weekly Achievements
    Achievement(
      id: 'week_warrior',
      title: 'Hafta Şampiyonu',
      description: '7 gün üst üste veri girişi yaptın!',
      icon: '🏆',
      color: Colors.orange,
      type: AchievementType.weekly,
      targetValue: 7,
      unit: 'gün',
      points: 50,
    ),
    Achievement(
      id: 'transport_master',
      title: 'Ulaşım Ustası',
      description: 'Bir haftada 5 farklı ulaşım türü kullandın!',
      icon: '🚲',
      color: Colors.purple,
      type: AchievementType.weekly,
      targetValue: 5,
      unit: 'tür',
      points: 30,
    ),
    
    // Streak Achievements
    Achievement(
      id: 'streak_7',
      title: '1 Haftalık Seri',
      description: '7 gün üst üste düşük karbon!',
      icon: '🔥',
      color: Colors.red,
      type: AchievementType.streak,
      targetValue: 7,
      unit: 'gün',
      points: 40,
    ),
    Achievement(
      id: 'streak_30',
      title: '1 Aylık Efsane',
      description: '30 gün boyunca tutarlı takip!',
      icon: '💎',
      color: Colors.cyan,
      type: AchievementType.streak,
      targetValue: 30,
      unit: 'gün',
      points: 100,
    ),
    
    // Milestone Achievements
    Achievement(
      id: 'saver_100',
      title: 'CO₂ Tasarrufçusu',
      description: 'Toplam 100 kg CO₂ tasarrufu yaptın!',
      icon: '🌍',
      color: Colors.teal,
      type: AchievementType.milestone,
      targetValue: 100,
      unit: 'kg CO₂',
      points: 75,
    ),
    Achievement(
      id: 'activities_100',
      title: 'Süper Aktif',
      description: '100 aktivite kaydı tamamladın!',
      icon: '⭐',
      color: Colors.amber,
      type: AchievementType.milestone,
      targetValue: 100,
      unit: 'aktivite',
      points: 60,
    ),
    
    // Special Achievements
    Achievement(
      id: 'early_bird',
      title: 'Erken Kalkan',
      description: 'Uygulamayı ilk 100 kullanıcıdan biri oldun!',
      icon: '🐦',
      color: Colors.indigo,
      type: AchievementType.special,
      targetValue: 1,
      unit: 'özel',
      points: 200,
    ),
  ];

  Future<void> initialize() async {
    await _loadAchievements();
    _calculateTotalPoints();
  }

  Future<void> _loadAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = prefs.getString(_achievementsKey);
      
      if (achievementsJson != null) {
        final List<dynamic> savedData = json.decode(achievementsJson);
        final Map<String, Map<String, dynamic>> savedAchievements = 
            Map.fromIterable(savedData, 
                key: (item) => item['id'], 
                value: (item) => item);

        _achievements = _defaultAchievements.map((template) {
          if (savedAchievements.containsKey(template.id)) {
            return Achievement.fromJson(savedAchievements[template.id]!, template);
          }
          return template;
        }).toList();
      } else {
        _achievements = List.from(_defaultAchievements);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading achievements: $e');
      _achievements = List.from(_defaultAchievements);
    }
  }

  Future<void> _saveAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = json.encode(
        _achievements.map((a) => a.toJson()).toList(),
      );
      await prefs.setString(_achievementsKey, achievementsJson);
    } catch (e) {
      print('Error saving achievements: $e');
    }
  }

  void _calculateTotalPoints() {
    _totalPoints = unlockedAchievements.fold(0, (sum, achievement) => sum + achievement.points);
  }

  // Achievement checking methods
  Future<List<Achievement>> checkDailyAchievements(double todaysCO2) async {
    final newlyUnlocked = <Achievement>[];

    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      
      if (achievement.isUnlocked || achievement.type != AchievementType.daily) continue;

      bool shouldUnlock = false;

      switch (achievement.id) {
        case 'first_day':
          shouldUnlock = todaysCO2 > 0;
          break;
        case 'eco_warrior':
          shouldUnlock = todaysCO2 < 20.0;
          break;
        case 'green_day':
          shouldUnlock = todaysCO2 < 10.0;
          break;
      }

      if (shouldUnlock) {
        _achievements[i] = achievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
          currentProgress: achievement.targetValue,
        );
        newlyUnlocked.add(_achievements[i]);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _calculateTotalPoints();
      await _saveAchievements();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  Future<List<Achievement>> checkWeeklyAchievements({
    required int consecutiveDays,
    required int differentTransportTypes,
  }) async {
    final newlyUnlocked = <Achievement>[];

    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      
      if (achievement.isUnlocked || achievement.type != AchievementType.weekly) continue;

      bool shouldUnlock = false;

      switch (achievement.id) {
        case 'week_warrior':
          shouldUnlock = consecutiveDays >= 7;
          break;
        case 'transport_master':
          shouldUnlock = differentTransportTypes >= 5;
          break;
      }

      if (shouldUnlock) {
        _achievements[i] = achievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
          currentProgress: achievement.targetValue,
        );
        newlyUnlocked.add(_achievements[i]);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _calculateTotalPoints();
      await _saveAchievements();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  Future<List<Achievement>> checkMilestoneAchievements({
    required double totalCO2Saved,
    required int totalActivities,
  }) async {
    final newlyUnlocked = <Achievement>[];

    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      
      if (achievement.isUnlocked || achievement.type != AchievementType.milestone) continue;

      bool shouldUnlock = false;
      double progress = 0.0;

      switch (achievement.id) {
        case 'saver_100':
          progress = totalCO2Saved;
          shouldUnlock = totalCO2Saved >= 100.0;
          break;
        case 'activities_100':
          progress = totalActivities.toDouble();
          shouldUnlock = totalActivities >= 100;
          break;
      }

      if (shouldUnlock) {
        _achievements[i] = achievement.copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
          currentProgress: achievement.targetValue,
        );
        newlyUnlocked.add(_achievements[i]);
      } else {
        // Update progress
        _achievements[i] = achievement.copyWith(
          currentProgress: progress,
        );
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _calculateTotalPoints();
      await _saveAchievements();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  // Get achievements by type
  List<Achievement> getAchievementsByType(AchievementType type) {
    return _achievements.where((a) => a.type == type).toList();
  }

  // Get recent achievements (last 7 days)
  List<Achievement> getRecentAchievements() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return unlockedAchievements
        .where((a) => a.unlockedAt != null && a.unlockedAt!.isAfter(sevenDaysAgo))
        .toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
  }

  // Calculate level based on total points
  int get userLevel => (totalPoints / 100).floor() + 1;
  int get pointsForNextLevel => (userLevel * 100) - totalPoints;
  double get levelProgress => (totalPoints % 100) / 100.0;
}