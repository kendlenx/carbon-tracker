import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';

enum GoalType {
  daily,
  weekly,
  monthly,
  yearly,
}

enum GoalCategory {
  total,
  transport,
  energy,
  food,
  waste,
}

class CarbonGoal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final GoalCategory category;
  final double targetValue; // kg CO2
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool isCompleted;
  final double currentProgress; // kg CO2
  final DateTime createdAt;
  final bool isAdaptive; // Otomatik ayarlanan hedef mi?

  CarbonGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.isCompleted = false,
    this.currentProgress = 0.0,
    required this.createdAt,
    this.isAdaptive = false,
  });

  double get progressPercentage {
    if (targetValue <= 0) return 0.0;
    return (currentProgress / targetValue * 100).clamp(0.0, 100.0);
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  String get progressText {
    return '${currentProgress.toStringAsFixed(1)}/${targetValue.toStringAsFixed(1)} kg CO₂';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'category': category.name,
      'targetValue': targetValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'isCompleted': isCompleted,
      'currentProgress': currentProgress,
      'createdAt': createdAt.toIso8601String(),
      'isAdaptive': isAdaptive,
    };
  }

  factory CarbonGoal.fromJson(Map<String, dynamic> json) {
    return CarbonGoal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: GoalType.values.firstWhere((e) => e.name == json['type']),
      category: GoalCategory.values.firstWhere((e) => e.name == json['category']),
      targetValue: json['targetValue'].toDouble(),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      isCompleted: json['isCompleted'] ?? false,
      currentProgress: json['currentProgress']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt']),
      isAdaptive: json['isAdaptive'] ?? false,
    );
  }

  CarbonGoal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    GoalCategory? category,
    double? targetValue,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? isCompleted,
    double? currentProgress,
    DateTime? createdAt,
    bool? isAdaptive,
  }) {
    return CarbonGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      currentProgress: currentProgress ?? this.currentProgress,
      createdAt: createdAt ?? this.createdAt,
      isAdaptive: isAdaptive ?? this.isAdaptive,
    );
  }
}

class GoalService extends ChangeNotifier {
  static GoalService? _instance;
  static GoalService get instance => _instance ??= GoalService._();
  
  GoalService._();

  List<CarbonGoal> _goals = [];
  final NotificationService _notificationService = NotificationService.instance;

  List<CarbonGoal> get goals => _goals;
  List<CarbonGoal> get activeGoals => _goals.where((goal) => goal.isActive && !goal.isExpired).toList();
  List<CarbonGoal> get completedGoals => _goals.where((goal) => goal.isCompleted).toList();
  List<CarbonGoal> get expiredGoals => _goals.where((goal) => goal.isExpired && !goal.isCompleted).toList();

  /// Initialize goal service
  Future<void> initialize() async {
    await _loadGoals();
    await _createDefaultGoals();
  }

  /// Load goals from SharedPreferences
  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString('carbon_goals');
      
      if (goalsJson != null) {
        final goalsList = jsonDecode(goalsJson) as List;
        _goals = goalsList.map((json) => CarbonGoal.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
  }

  /// Save goals to SharedPreferences
  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = jsonEncode(_goals.map((goal) => goal.toJson()).toList());
      await prefs.setString('carbon_goals', goalsJson);
    } catch (e) {
      debugPrint('Error saving goals: $e');
    }
  }

  /// Create default goals for new users
  Future<void> _createDefaultGoals() async {
    if (_goals.isNotEmpty) return;

    final now = DateTime.now();
    
    // Default daily goal
    await createGoal(
      title: 'Günlük Karbon Hedefi',
      description: 'Günde maksimum 15 kg CO₂ ayak izi',
      type: GoalType.daily,
      category: GoalCategory.total,
      targetValue: 15.0,
      duration: const Duration(days: 1),
    );

    // Default weekly goal
    await createGoal(
      title: 'Haftalık Karbon Hedefi',
      description: 'Haftada maksimum 100 kg CO₂ ayak izi',
      type: GoalType.weekly,
      category: GoalCategory.total,
      targetValue: 100.0,
      duration: const Duration(days: 7),
    );

    // Transport goal
    await createGoal(
      title: 'Ulaşım Karbon Hedefi',
      description: 'Günlük ulaşım için maksimum 8 kg CO₂',
      type: GoalType.daily,
      category: GoalCategory.transport,
      targetValue: 8.0,
      duration: const Duration(days: 1),
    );
  }

  /// Create new carbon goal
  Future<CarbonGoal> createGoal({
    required String title,
    required String description,
    required GoalType type,
    required GoalCategory category,
    required double targetValue,
    required Duration duration,
    bool isAdaptive = false,
  }) async {
    final now = DateTime.now();
    final goal = CarbonGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      type: type,
      category: category,
      targetValue: targetValue,
      startDate: now,
      endDate: now.add(duration),
      createdAt: now,
      isAdaptive: isAdaptive,
    );

    _goals.add(goal);
    await _saveGoals();
    notifyListeners();

    return goal;
  }

  /// Update goal progress
  Future<void> updateGoalProgress(String goalId, double newProgress) async {
    final goalIndex = _goals.indexWhere((goal) => goal.id == goalId);
    if (goalIndex == -1) return;

    final goal = _goals[goalIndex];
    final previousPercentage = goal.progressPercentage;
    
    _goals[goalIndex] = goal.copyWith(
      currentProgress: newProgress,
      isCompleted: newProgress >= goal.targetValue,
    );

    await _saveGoals();
    notifyListeners();

    // Check if goal completed or significant progress made
    final newPercentage = _goals[goalIndex].progressPercentage;
    
    if (_goals[goalIndex].isCompleted && !goal.isCompleted) {
      // Goal completed notification
      await _notificationService.showGoalCompletionNotification(goal.title, 100);
    } else if (newPercentage >= 50 && previousPercentage < 50) {
      // 50% milestone notification
      await _notificationService.showGoalCompletionNotification(goal.title, newPercentage);
    } else if (newPercentage >= 80 && previousPercentage < 80) {
      // 80% milestone notification
      await _notificationService.showGoalCompletionNotification(goal.title, newPercentage);
    }
  }

  /// Update all goals based on carbon activity
  Future<void> updateAllGoalsProgress(double carbonAmount, GoalCategory category) async {
    final now = DateTime.now();
    bool hasUpdates = false;

    for (int i = 0; i < _goals.length; i++) {
      final goal = _goals[i];
      
      // Skip completed, inactive, or expired goals
      if (goal.isCompleted || !goal.isActive || goal.isExpired) continue;
      
      // Check if this activity applies to the goal
      bool shouldUpdate = false;
      
      switch (goal.type) {
        case GoalType.daily:
          shouldUpdate = _isSameDay(now, goal.startDate) || 
                        (now.isAfter(goal.startDate) && now.isBefore(goal.endDate));
          break;
        case GoalType.weekly:
          shouldUpdate = now.isAfter(goal.startDate) && now.isBefore(goal.endDate);
          break;
        case GoalType.monthly:
          shouldUpdate = now.isAfter(goal.startDate) && now.isBefore(goal.endDate);
          break;
        case GoalType.yearly:
          shouldUpdate = now.isAfter(goal.startDate) && now.isBefore(goal.endDate);
          break;
      }
      
      // Check category match
      if (shouldUpdate && (goal.category == GoalCategory.total || goal.category == category)) {
        final previousPercentage = goal.progressPercentage;
        _goals[i] = goal.copyWith(
          currentProgress: goal.currentProgress + carbonAmount,
          isCompleted: (goal.currentProgress + carbonAmount) >= goal.targetValue,
        );
        hasUpdates = true;

        // Check for notifications
        final newPercentage = _goals[i].progressPercentage;
        await _checkGoalNotifications(goal, previousPercentage, newPercentage);
      }
    }

    if (hasUpdates) {
      await _saveGoals();
      notifyListeners();
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Check and send goal-related notifications
  Future<void> _checkGoalNotifications(CarbonGoal goal, double previousPercentage, double newPercentage) async {
    if (goal.isCompleted && previousPercentage < 100) {
      // Goal completed
      await _notificationService.showGoalCompletionNotification(goal.title, 100);
    } else if (newPercentage >= 80 && previousPercentage < 80) {
      // 80% milestone
      await _notificationService.showGoalCompletionNotification(goal.title, newPercentage);
    } else if (newPercentage >= 50 && previousPercentage < 50) {
      // 50% milestone
      await _notificationService.showGoalCompletionNotification(goal.title, newPercentage);
    }
  }

  /// Delete goal
  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((goal) => goal.id == goalId);
    await _saveGoals();
    notifyListeners();
  }

  /// Edit goal
  Future<void> editGoal(String goalId, {
    String? title,
    String? description,
    double? targetValue,
    DateTime? endDate,
  }) async {
    final goalIndex = _goals.indexWhere((goal) => goal.id == goalId);
    if (goalIndex == -1) return;

    _goals[goalIndex] = _goals[goalIndex].copyWith(
      title: title,
      description: description,
      targetValue: targetValue,
      endDate: endDate,
    );

    await _saveGoals();
    notifyListeners();
  }

  /// Archive expired goals
  Future<void> archiveExpiredGoals() async {
    bool hasChanges = false;
    
    for (int i = 0; i < _goals.length; i++) {
      if (_goals[i].isExpired && _goals[i].isActive && !_goals[i].isCompleted) {
        _goals[i] = _goals[i].copyWith(isActive: false);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await _saveGoals();
      notifyListeners();
    }
  }

  /// Get goals by type
  List<CarbonGoal> getGoalsByType(GoalType type) {
    return _goals.where((goal) => goal.type == type && goal.isActive).toList();
  }

  /// Get goals by category
  List<CarbonGoal> getGoalsByCategory(GoalCategory category) {
    return _goals.where((goal) => goal.category == category && goal.isActive).toList();
  }

  /// Get all goals (including inactive)
  List<CarbonGoal> getAllGoals() {
    return _goals;
  }

  /// Create adaptive goals based on user's performance
  Future<void> createAdaptiveGoals() async {
    // Get user's average performance from the last 30 days
    // This is a simplified version - in real implementation, you'd analyze actual data
    
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    // Get historical data (simplified)
    final avgDailyCarbon = prefs.getDouble('avg_daily_carbon') ?? 12.0;
    final avgWeeklyCarbon = prefs.getDouble('avg_weekly_carbon') ?? 84.0;
    
    // Create adaptive goals with 10% improvement target
    final improvementFactor = 0.9; // 10% reduction target
    
    // Create adaptive daily goal
    await createGoal(
      title: 'Akıllı Günlük Hedef',
      description: 'Geçmiş performansınıza göre önerilen günlük hedef',
      type: GoalType.daily,
      category: GoalCategory.total,
      targetValue: avgDailyCarbon * improvementFactor,
      duration: const Duration(days: 1),
      isAdaptive: true,
    );

    // Create adaptive weekly goal
    await createGoal(
      title: 'Akıllı Haftalık Hedef',
      description: 'Geçmiş performansınıza göre önerilen haftalık hedef',
      type: GoalType.weekly,
      category: GoalCategory.total,
      targetValue: avgWeeklyCarbon * improvementFactor,
      duration: const Duration(days: 7),
      isAdaptive: true,
    );
  }

  /// Get goal statistics
  Map<String, dynamic> getGoalStatistics() {
    final activeCount = activeGoals.length;
    final completedCount = completedGoals.length;
    final totalCount = _goals.length;
    final completionRate = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;
    
    return {
      'totalGoals': totalCount,
      'activeGoals': activeCount,
      'completedGoals': completedCount,
      'completionRate': completionRate,
      'expiredGoals': expiredGoals.length,
    };
  }

  /// Get suggested goal templates
  List<Map<String, dynamic>> getGoalTemplates() {
    return [
      {
        'title': 'Eco Warrior',
        'description': 'Günde maksimum 10 kg CO₂',
        'type': GoalType.daily,
        'category': GoalCategory.total,
        'targetValue': 10.0,
        'icon': Icons.eco,
        'difficulty': 'Zor',
        'color': Colors.green,
      },
      {
        'title': 'Bisiklet Dostu',
        'description': 'Ulaşım için günde maksimum 5 kg CO₂',
        'type': GoalType.daily,
        'category': GoalCategory.transport,
        'targetValue': 5.0,
        'icon': Icons.pedal_bike,
        'difficulty': 'Orta',
        'color': Colors.blue,
      },
      {
        'title': 'Enerji Tasarrufçusu',
        'description': 'Enerji tüketimi için günde maksimum 3 kg CO₂',
        'type': GoalType.daily,
        'category': GoalCategory.energy,
        'targetValue': 3.0,
        'icon': Icons.flash_on,
        'difficulty': 'Kolay',
        'color': Colors.orange,
      },
      {
        'title': 'Haftalık Mücadeleci',
        'description': 'Haftada maksimum 70 kg CO₂',
        'type': GoalType.weekly,
        'category': GoalCategory.total,
        'targetValue': 70.0,
        'icon': Icons.trending_down,
        'difficulty': 'Zor',
        'color': Colors.purple,
      },
      {
        'title': 'Aylık Hedef',
        'description': 'Ayda maksimum 300 kg CO₂',
        'type': GoalType.monthly,
        'category': GoalCategory.total,
        'targetValue': 300.0,
        'icon': Icons.calendar_month,
        'difficulty': 'Orta',
        'color': Colors.teal,
      },
    ];
  }

  /// Restart daily/weekly goals
  Future<void> restartRecurringGoals() async {
    final now = DateTime.now();
    bool hasChanges = false;

    for (int i = 0; i < _goals.length; i++) {
      final goal = _goals[i];
      
      if (goal.isExpired && (goal.type == GoalType.daily || goal.type == GoalType.weekly)) {
        // Restart the goal with new dates
        Duration duration;
        switch (goal.type) {
          case GoalType.daily:
            duration = const Duration(days: 1);
            break;
          case GoalType.weekly:
            duration = const Duration(days: 7);
            break;
          default:
            continue;
        }

        _goals[i] = goal.copyWith(
          startDate: now,
          endDate: now.add(duration),
          currentProgress: 0.0,
          isCompleted: false,
          isActive: true,
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await _saveGoals();
      notifyListeners();
    }
  }
}