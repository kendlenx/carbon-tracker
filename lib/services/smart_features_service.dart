import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

// Smart recommendation types
enum RecommendationType {
  transport,
  energy,
  food,
  shopping,
  general,
}

class SmartRecommendation {
  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double potentialSaving; // kg CO₂
  final int priority; // 1-10, 10 is highest
  final DateTime createdAt;
  final bool isRead;
  final List<String> actionSteps;

  SmartRecommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.potentialSaving,
    required this.priority,
    required this.createdAt,
    this.isRead = false,
    this.actionSteps = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'description': description,
      'potentialSaving': potentialSaving,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'actionSteps': actionSteps,
    };
  }

  static SmartRecommendation fromJson(Map<String, dynamic> json) {
    return SmartRecommendation(
      id: json['id'],
      type: RecommendationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => RecommendationType.general,
      ),
      title: json['title'],
      description: json['description'],
      icon: Icons.lightbulb_outline, // Default icon
      color: Colors.blue, // Default color
      potentialSaving: json['potentialSaving']?.toDouble() ?? 0.0,
      priority: json['priority'] ?? 5,
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      actionSteps: List<String>.from(json['actionSteps'] ?? []),
    );
  }
}

// Habit tracking
class CarbonHabit {
  final String id;
  final String title;
  final String description;
  final double targetValue;
  final String unit;
  final Color color;
  final IconData icon;
  final List<DateTime> completedDates;
  final int streak;
  final bool isActive;

  CarbonHabit({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.unit,
    required this.color,
    required this.icon,
    this.completedDates = const [],
    this.streak = 0,
    this.isActive = true,
  });

  bool get isCompletedToday {
    final today = DateTime.now();
    return completedDates.any((date) =>
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day);
  }

  double get completionRate {
    if (completedDates.length < 7) return completedDates.length / 7;
    
    final last7Days = completedDates
        .where((date) => DateTime.now().difference(date).inDays <= 7)
        .length;
    return last7Days / 7;
  }
}

// Smart reminder
class SmartReminder {
  final String id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final RecommendationType type;
  final bool isRecurring;
  final Duration? recurringInterval;
  final bool isActive;

  SmartReminder({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledTime,
    required this.type,
    this.isRecurring = false,
    this.recurringInterval,
    this.isActive = true,
  });
}

class SmartFeaturesService extends ChangeNotifier {
  static SmartFeaturesService? _instance;
  static SmartFeaturesService get instance => _instance ??= SmartFeaturesService._();
  
  SmartFeaturesService._();

  static const String _recommendationsKey = 'smart_recommendations';
  static const String _habitsKey = 'carbon_habits';
  static const String _remindersKey = 'smart_reminders';

  List<SmartRecommendation> _recommendations = [];
  List<CarbonHabit> _habits = [];
  List<SmartReminder> _reminders = [];

  List<SmartRecommendation> get recommendations => _recommendations;
  List<SmartRecommendation> get unreadRecommendations => 
      _recommendations.where((r) => !r.isRead).toList();
  List<CarbonHabit> get habits => _habits;
  List<SmartReminder> get reminders => _reminders;

  // Initialize the service
  Future<void> initialize() async {
    await _loadRecommendations();
    await _loadHabits();
    await _loadReminders();
    await _generateDailyRecommendations();
  }

  // Load saved data
  Future<void> _loadRecommendations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recommendationsJson = prefs.getString(_recommendationsKey);
      
      if (recommendationsJson != null) {
        final List<dynamic> data = json.decode(recommendationsJson);
        _recommendations = data.map((item) => SmartRecommendation.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }

  Future<void> _loadHabits() async {
    // Initialize with default habits if none exist
    if (_habits.isEmpty) {
      _habits = [
        CarbonHabit(
          id: 'walk_instead_drive',
          title: 'Yürüyüş Yapma',
          description: 'Kısa mesafeler için yürümeyi tercih et',
          targetValue: 1.0,
          unit: 'gün',
          color: Colors.green,
          icon: Icons.directions_walk,
        ),
        CarbonHabit(
          id: 'public_transport',
          title: 'Toplu Taşıma',
          description: 'Mümkün olduğunda toplu taşıma kullan',
          targetValue: 3.0,
          unit: 'gün/hafta',
          color: Colors.blue,
          icon: Icons.directions_bus,
        ),
        CarbonHabit(
          id: 'energy_saving',
          title: 'Enerji Tasarrufu',
          description: 'Gereksiz cihazları kapatmayı unutma',
          targetValue: 1.0,
          unit: 'gün',
          color: Colors.orange,
          icon: Icons.power_settings_new,
        ),
      ];
    }
  }

  Future<void> _loadReminders() async {
    // Initialize with smart reminders
    final now = DateTime.now();
    _reminders = [
      SmartReminder(
        id: 'morning_transport',
        title: 'Ulaşım Planı',
        message: 'Bugün hangi ulaşım yöntemini kullanacaksın?',
        scheduledTime: DateTime(now.year, now.month, now.day, 8, 0),
        type: RecommendationType.transport,
        isRecurring: true,
        recurringInterval: const Duration(days: 1),
      ),
      SmartReminder(
        id: 'evening_reflection',
        title: 'Günlük Değerlendirme',
        message: 'Bugünkü karbon ayak izini kaydetmeyi unutma!',
        scheduledTime: DateTime(now.year, now.month, now.day, 20, 0),
        type: RecommendationType.general,
        isRecurring: true,
        recurringInterval: const Duration(days: 1),
      ),
    ];
  }

  // Generate daily recommendations based on user data
  Future<void> _generateDailyRecommendations() async {
    final today = DateTime.now();
    final existingToday = _recommendations.any((r) =>
        r.createdAt.year == today.year &&
        r.createdAt.month == today.month &&
        r.createdAt.day == today.day);

    if (existingToday) return; // Already generated for today

    // Generate recommendations based on patterns and AI-like logic
    final newRecommendations = await _generateSmartRecommendations();
    _recommendations.addAll(newRecommendations);
    
    // Keep only last 30 days of recommendations
    final cutoffDate = today.subtract(const Duration(days: 30));
    _recommendations.removeWhere((r) => r.createdAt.isBefore(cutoffDate));
    
    await _saveRecommendations();
    notifyListeners();
  }

  Future<List<SmartRecommendation>> _generateSmartRecommendations() async {
    final recommendations = <SmartRecommendation>[];
    final random = math.Random();

    // Transport recommendations
    final transportTips = [
      {
        'title': 'Bisiklet Kullanımı',
        'description': 'Kısa mesafeler için bisiklet kullanarak günde 2.3 kg CO₂ tasarruf edebilirsin.',
        'saving': 2.3,
        'priority': 8,
        'steps': ['Bisiklet yolu haritasını incele', 'Güvenlik ekipmanlarını kontrol et', 'Kısa rotalar belirle'],
      },
      {
        'title': 'Toplu Taşıma Avantajı',
        'description': 'Özel araç yerine toplu taşıma kullanarak günde ortalama 4.6 kg CO₂ azaltabilirsin.',
        'saving': 4.6,
        'priority': 9,
        'steps': ['Günlük rotanı planla', 'Mobil uygulamaları indir', 'Aylık kart al'],
      },
      {
        'title': 'Yürüyüş Hedefi',
        'description': '1 km altındaki mesafeler için yürüyerek hem sağlığını koru hem de çevreyi koru.',
        'saving': 0.8,
        'priority': 6,
        'steps': ['Yakın destinasyonları belirle', 'Günlük adım hedefi koy', 'Rahat ayakkabı seç'],
      },
    ];

    // Energy recommendations
    final energyTips = [
      {
        'title': 'Akıllı Termostat',
        'description': 'Termostatı 1°C düşürerek yıllık 300 kg CO₂ tasarruf edebilirsin.',
        'saving': 0.8,
        'priority': 7,
        'steps': ['Mevcut sıcaklığı ölç', 'Kademeli olarak düşür', 'Ek kıyafet kullan'],
      },
      {
        'title': 'LED Dönüşümü',
        'description': 'Tüm ampulleri LED ile değiştirerek yıllık 200 kg CO₂ azalt.',
        'saving': 0.5,
        'priority': 5,
        'steps': ['Mevcut ampulleri say', 'LED alternatifleri araştır', 'Aşamalı değiştir'],
      },
      {
        'title': 'Elektronik Cihaz Yönetimi',
        'description': 'Kullanmadığın cihazları kapatarak günde 1.2 kg CO₂ tasarrufu yap.',
        'saving': 1.2,
        'priority': 8,
        'steps': ['Fişleri çek', 'Zamanlayıcı kullan', 'Akıllı priz al'],
      },
    ];

    // Select random recommendations
    final allTips = [...transportTips, ...energyTips];
    final selectedTips = (allTips..shuffle(random)).take(2).toList();

    for (int i = 0; i < selectedTips.length; i++) {
      final tip = selectedTips[i];
      final isTransport = transportTips.contains(tip);
      
      recommendations.add(SmartRecommendation(
        id: 'daily_${DateTime.now().millisecondsSinceEpoch}_$i',
        type: isTransport ? RecommendationType.transport : RecommendationType.energy,
        title: tip['title'] as String,
        description: tip['description'] as String,
        icon: isTransport ? Icons.directions_car : Icons.flash_on,
        color: isTransport ? Colors.blue : Colors.orange,
        potentialSaving: tip['saving'] as double,
        priority: tip['priority'] as int,
        createdAt: DateTime.now(),
        actionSteps: List<String>.from(tip['steps'] as List),
      ));
    }

    return recommendations;
  }

  // Mark recommendation as read
  Future<void> markRecommendationAsRead(String id) async {
    final index = _recommendations.indexWhere((r) => r.id == id);
    if (index != -1) {
      _recommendations[index] = SmartRecommendation(
        id: _recommendations[index].id,
        type: _recommendations[index].type,
        title: _recommendations[index].title,
        description: _recommendations[index].description,
        icon: _recommendations[index].icon,
        color: _recommendations[index].color,
        potentialSaving: _recommendations[index].potentialSaving,
        priority: _recommendations[index].priority,
        createdAt: _recommendations[index].createdAt,
        isRead: true,
        actionSteps: _recommendations[index].actionSteps,
      );
      
      await _saveRecommendations();
      notifyListeners();
    }
  }

  // Complete a habit for today
  Future<void> completeHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index != -1) {
      final habit = _habits[index];
      if (!habit.isCompletedToday) {
        final newCompletedDates = [...habit.completedDates, DateTime.now()];
        
        // Calculate new streak
        int newStreak = 1;
        final sortedDates = newCompletedDates..sort((a, b) => b.compareTo(a));
        
        for (int i = 1; i < sortedDates.length; i++) {
          final diff = sortedDates[i - 1].difference(sortedDates[i]).inDays;
          if (diff <= 1) {
            newStreak++;
          } else {
            break;
          }
        }
        
        _habits[index] = CarbonHabit(
          id: habit.id,
          title: habit.title,
          description: habit.description,
          targetValue: habit.targetValue,
          unit: habit.unit,
          color: habit.color,
          icon: habit.icon,
          completedDates: newCompletedDates,
          streak: newStreak,
          isActive: habit.isActive,
        );
        
        await _saveHabits();
        notifyListeners();
      }
    }
  }

  // Get personalized insights
  Map<String, dynamic> getPersonalizedInsights() {
    final totalPotentialSaving = _recommendations
        .fold(0.0, (sum, rec) => sum + rec.potentialSaving);
    
    final averageHabitCompletion = _habits.isNotEmpty
        ? _habits.map((h) => h.completionRate).reduce((a, b) => a + b) / _habits.length
        : 0.0;
    
    final longestStreak = _habits.isNotEmpty
        ? _habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b)
        : 0;

    String performanceLevel;
    Color performanceColor;
    
    if (averageHabitCompletion >= 0.8) {
      performanceLevel = 'Mükemmel';
      performanceColor = Colors.green;
    } else if (averageHabitCompletion >= 0.6) {
      performanceLevel = 'İyi';
      performanceColor = Colors.blue;
    } else if (averageHabitCompletion >= 0.4) {
      performanceLevel = 'Orta';
      performanceColor = Colors.orange;
    } else {
      performanceLevel = 'Geliştirilmeli';
      performanceColor = Colors.red;
    }

    return {
      'totalPotentialSaving': totalPotentialSaving,
      'averageHabitCompletion': averageHabitCompletion,
      'longestStreak': longestStreak,
      'performanceLevel': performanceLevel,
      'performanceColor': performanceColor,
      'unreadRecommendationsCount': unreadRecommendations.length,
      'activeHabitsCount': _habits.where((h) => h.isActive).length,
    };
  }

  // Goal setting
  Future<void> setWeeklyGoal(double targetReduction) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weekly_co2_goal', targetReduction);
    notifyListeners();
  }

  Future<double> getWeeklyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('weekly_co2_goal') ?? 10.0; // Default 10kg reduction per week
  }

  // Save methods
  Future<void> _saveRecommendations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recommendationsJson = json.encode(
        _recommendations.map((r) => r.toJson()).toList(),
      );
      await prefs.setString(_recommendationsKey, recommendationsJson);
    } catch (e) {
      print('Error saving recommendations: $e');
    }
  }

  Future<void> _saveHabits() async {
    // Simplified save for habits - in a real app, you'd implement proper serialization
    notifyListeners();
  }

  // Get weekly progress towards goal
  Future<Map<String, dynamic>> getWeeklyProgress(double actualEmissions) async {
    final goal = await getWeeklyGoal();
    final progress = 1.0 - (actualEmissions / (goal * 7)); // Convert weekly goal to daily
    
    return {
      'goal': goal,
      'actual': actualEmissions,
      'progress': progress.clamp(0.0, 1.0),
      'isOnTrack': actualEmissions <= goal,
      'difference': (goal - actualEmissions).abs(),
    };
  }

  // Smart notifications (simplified - would integrate with local notifications)
  List<String> getSmartNotifications() {
    final notifications = <String>[];
    final now = DateTime.now();
    
    // Check for habit reminders
    for (final habit in _habits) {
      if (habit.isActive && !habit.isCompletedToday) {
        if (now.hour >= 18) { // Evening reminder
          notifications.add('${habit.title} alışkanlığını bugün tamamlamayı unutma!');
        }
      }
    }
    
    // Check for unread recommendations
    if (unreadRecommendations.isNotEmpty) {
      notifications.add('${unreadRecommendations.length} yeni önerin var!');
    }
    
    return notifications;
  }
}