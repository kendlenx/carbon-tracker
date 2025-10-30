import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'database_service.dart';
import 'goal_service.dart';
import 'achievement_service.dart';

enum WidgetType {
  carbonToday,
  weeklyProgress,
  goalProgress,
  achievements,
  quickStats,
  levelProgress,
}

class WidgetData {
  final String id;
  final String title;
  final String description;
  final WidgetType type;
  final Map<String, dynamic> data;
  final DateTime lastUpdated;
  final bool isEnabled;

  WidgetData({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.data,
    required this.lastUpdated,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'data': data,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isEnabled': isEnabled,
    };
  }

  factory WidgetData.fromJson(Map<String, dynamic> json) {
    return WidgetData(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: WidgetType.values.firstWhere((e) => e.name == json['type']),
      data: json['data'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  WidgetData copyWith({
    String? id,
    String? title,
    String? description,
    WidgetType? type,
    Map<String, dynamic>? data,
    DateTime? lastUpdated,
    bool? isEnabled,
  }) {
    return WidgetData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      data: data ?? this.data,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class WidgetService extends ChangeNotifier {
  static WidgetService? _instance;
  static WidgetService get instance => _instance ??= WidgetService._();
  
  WidgetService._();

  // Services
  final DatabaseService _databaseService = DatabaseService.instance;
  final GoalService _goalService = GoalService.instance;
  final AchievementService _achievementService = AchievementService.instance;

  // Widget data
  List<WidgetData> _widgets = [];
  bool _isInitialized = false;
  
  // Settings
  bool _autoUpdateEnabled = true;
  int _updateIntervalMinutes = 30;

  // Getters
  List<WidgetData> get widgets => _widgets;
  List<WidgetData> get enabledWidgets => _widgets.where((w) => w.isEnabled).toList();
  bool get isInitialized => _isInitialized;
  bool get autoUpdateEnabled => _autoUpdateEnabled;
  int get updateIntervalMinutes => _updateIntervalMinutes;

  /// Initialize widget service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadSettings();
    await _loadWidgets();
    await _setupWidgets();
    await _updateAllWidgets();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Setup home screen widgets
  Future<void> _setupWidgets() async {
    try {
      // Setup different widget types
      await _setupCarbonTodayWidget();
      await _setupWeeklyProgressWidget();
      await _setupGoalProgressWidget();
      await _setupAchievementsWidget();
      await _setupQuickStatsWidget();
      await _setupLevelProgressWidget();
      
      debugPrint('Home screen widgets configured successfully');
    } catch (e) {
      debugPrint('Error setting up widgets: $e');
    }
  }

  /// Setup Carbon Today widget
  Future<void> _setupCarbonTodayWidget() async {
    final stats = await _databaseService.getDashboardStats();
    final todayCarbon = stats['todayTotal'] ?? 0.0;
    
    final widgetData = WidgetData(
      id: 'carbon_today',
      title: 'Bugünkü Karbon',
      description: 'Günlük CO₂ ayak izi',
      type: WidgetType.carbonToday,
      data: {
        'carbonToday': todayCarbon,
        'unit': 'kg CO₂',
        'status': _getCarbonStatus(todayCarbon),
        'color': _getCarbonStatusColor(todayCarbon),
      },
      lastUpdated: DateTime.now(),
    );

    _updateWidget(widgetData);

    // Update home widget (Android only; iOS handled via WidgetDataProvider)
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<double>('carbon_today', todayCarbon);
      await HomeWidget.saveWidgetData<String>('carbon_today_text', '${todayCarbon.toStringAsFixed(1)} kg CO₂');
      await HomeWidget.saveWidgetData<String>('carbon_status', _getCarbonStatus(todayCarbon));
      await HomeWidget.updateWidget(name: 'widgets.CarbonTodayWidget');
    }
  }

  /// Setup Weekly Progress widget
  Future<void> _setupWeeklyProgressWidget() async {
    final stats = await _databaseService.getDashboardStats();
    final weeklyAverage = stats['weeklyAverage'] ?? 0.0;
    final weeklyGoal = 100.0; // Default weekly goal
    final progress = (weeklyAverage / weeklyGoal).clamp(0.0, 1.0);
    
    final widgetData = WidgetData(
      id: 'weekly_progress',
      title: 'Haftalık İlerleme',
      description: 'Haftalık karbon hedef ilerlemesi',
      type: WidgetType.weeklyProgress,
      data: {
        'weeklyCarbon': weeklyAverage,
        'weeklyGoal': weeklyGoal,
        'progress': progress,
        'progressPercentage': (progress * 100).round(),
      },
      lastUpdated: DateTime.now(),
    );

    _updateWidget(widgetData);

    // Update home widget (Android only; iOS handled via WidgetDataProvider)
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<double>('weekly_progress', progress);
      await HomeWidget.saveWidgetData<String>('weekly_text', '${(progress * 100).round()}% tamamlandı');
      await HomeWidget.saveWidgetData<double>('weekly_carbon', weeklyAverage);
      await HomeWidget.updateWidget(name: 'widgets.WeeklyProgressWidget');
    }
  }

  /// Setup Goal Progress widget
  Future<void> _setupGoalProgressWidget() async {
    final activeGoals = _goalService.activeGoals;
    
    if (activeGoals.isNotEmpty) {
      final primaryGoal = activeGoals.first;
      
      final widgetData = WidgetData(
        id: 'goal_progress',
        title: 'Hedef İlerlemesi',
        description: primaryGoal.title,
        type: WidgetType.goalProgress,
        data: {
          'goalTitle': primaryGoal.title,
          'progress': primaryGoal.progressPercentage,
          'progressText': primaryGoal.progressText,
          'daysRemaining': primaryGoal.daysRemaining,
        },
        lastUpdated: DateTime.now(),
      );

      _updateWidget(widgetData);

      // Update home widget (Android only; iOS handled via WidgetDataProvider)
      if (Platform.isAndroid) {
        await HomeWidget.saveWidgetData<String>('goal_title', primaryGoal.title);
        await HomeWidget.saveWidgetData<double>('goal_progress', primaryGoal.progressPercentage / 100);
        await HomeWidget.saveWidgetData<String>('goal_text', primaryGoal.progressText);
        await HomeWidget.saveWidgetData<int>('goal_days', primaryGoal.daysRemaining);
        await HomeWidget.updateWidget(name: 'widgets.GoalProgressWidget');
      }
    }
  }

  /// Setup Achievements widget
  Future<void> _setupAchievementsWidget() async {
    final recentAchievements = _achievementService.getRecentAchievements();
    final totalPoints = _achievementService.totalPoints;
    final level = _achievementService.getUserLevel();
    
    final widgetData = WidgetData(
      id: 'achievements',
      title: 'Başarılar',
      description: 'Son rozetler ve seviye',
      type: WidgetType.achievements,
      data: {
        'totalPoints': totalPoints,
        'level': level,
        'levelName': _achievementService.getUserRank(),
        'recentAchievements': recentAchievements.take(3).map((a) => {
          'title': a.title,
          'icon': a.icon,
          'points': a.points,
        }).toList(),
      },
      lastUpdated: DateTime.now(),
    );

    _updateWidget(widgetData);

    // Update home widget (Android only; iOS handled via WidgetDataProvider)
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<int>('total_points', totalPoints);
      await HomeWidget.saveWidgetData<int>('user_level', level);
      await HomeWidget.saveWidgetData<String>('level_name', _achievementService.getUserRank());
      await HomeWidget.saveWidgetData<int>('recent_count', recentAchievements.length);
      await HomeWidget.updateWidget(name: 'widgets.AchievementsWidget');
    }
  }

  /// Setup Quick Stats widget
  Future<void> _setupQuickStatsWidget() async {
    final stats = await _databaseService.getDashboardStats();
    final todayCarbon = stats['todayTotal'] ?? 0.0;
    final weeklyAverage = stats['weeklyAverage'] ?? 0.0;
    final monthlyTotal = stats['monthlyTotal'] ?? 0.0;
    
    final widgetData = WidgetData(
      id: 'quick_stats',
      title: 'Hızlı İstatistikler',
      description: 'Günlük, haftalık ve aylık özet',
      type: WidgetType.quickStats,
      data: {
        'todayCarbon': todayCarbon,
        'weeklyAverage': weeklyAverage,
        'monthlyTotal': monthlyTotal,
        'todayStatus': _getCarbonStatus(todayCarbon),
      },
      lastUpdated: DateTime.now(),
    );

    _updateWidget(widgetData);

    // Update home widget (Android only; iOS handled via WidgetDataProvider)
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<double>('stats_today', todayCarbon);
      await HomeWidget.saveWidgetData<double>('stats_weekly', weeklyAverage);
      await HomeWidget.saveWidgetData<double>('stats_monthly', monthlyTotal);
      await HomeWidget.saveWidgetData<String>('stats_status', _getCarbonStatus(todayCarbon));
      await HomeWidget.updateWidget(name: 'widgets.QuickStatsWidget');
    }
  }

  /// Setup Level Progress widget
  Future<void> _setupLevelProgressWidget() async {
    final levelProgress = _achievementService.getLevelProgress();
    
    final widgetData = WidgetData(
      id: 'level_progress',
      title: 'Seviye İlerlemesi',
      description: 'Bir sonraki seviyeye ilerleme',
      type: WidgetType.levelProgress,
      data: levelProgress,
      lastUpdated: DateTime.now(),
    );

    _updateWidget(widgetData);

    // Update home widget (Android only; iOS handled via WidgetDataProvider)
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<int>('current_level', levelProgress['currentLevel']);
      await HomeWidget.saveWidgetData<double>('level_progress', levelProgress['progress']);
      await HomeWidget.saveWidgetData<int>('points_to_next', levelProgress['pointsToNext']);
      await HomeWidget.saveWidgetData<String>('current_rank', _achievementService.getUserRank());
      await HomeWidget.updateWidget(name: 'widgets.LevelProgressWidget');
    }
  }

  /// Update all widgets
  Future<void> _updateAllWidgets() async {
    if (!_autoUpdateEnabled) return;
    
    try {
      await _setupCarbonTodayWidget();
      await _setupWeeklyProgressWidget();
      await _setupGoalProgressWidget();
      await _setupAchievementsWidget();
      await _setupQuickStatsWidget();
      await _setupLevelProgressWidget();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }

  /// Update specific widget
  void _updateWidget(WidgetData newWidget) {
    final index = _widgets.indexWhere((w) => w.id == newWidget.id);
    if (index != -1) {
      _widgets[index] = newWidget;
    } else {
      _widgets.add(newWidget);
    }
  }

  /// Get carbon status text
  String _getCarbonStatus(double carbon) {
    if (carbon < 5) return 'Mükemmel';
    if (carbon < 10) return 'Çok İyi';
    if (carbon < 15) return 'İyi';
    if (carbon < 20) return 'Orta';
    return 'Geliştirilmeli';
  }

  /// Get carbon status color
  String _getCarbonStatusColor(double carbon) {
    if (carbon < 5) return '#4CAF50';   // Green
    if (carbon < 10) return '#8BC34A';  // Light Green
    if (carbon < 15) return '#FFC107';  // Amber
    if (carbon < 20) return '#FF9800';  // Orange
    return '#F44336';                   // Red
  }

  /// Schedule automatic widget updates
  void scheduleWidgetUpdates() {
    // This would typically use a background service or work manager
    // For now, it's a placeholder for the scheduling logic
    debugPrint('Widget updates scheduled every $_updateIntervalMinutes minutes');
  }

  /// Get widget configuration options
  List<Map<String, dynamic>> getWidgetConfigurations() {
    return [
      {
        'id': 'carbon_today',
        'name': 'Bugünkü Karbon',
        'description': 'Günlük CO₂ ayak izi gösterir',
        'icon': Icons.today,
        'enabled': _widgets.any((w) => w.id == 'carbon_today' && w.isEnabled),
      },
      {
        'id': 'weekly_progress',
        'name': 'Haftalık İlerleme',
        'description': 'Haftalık hedef ilerlemesi',
        'icon': Icons.trending_up,
        'enabled': _widgets.any((w) => w.id == 'weekly_progress' && w.isEnabled),
      },
      {
        'id': 'goal_progress',
        'name': 'Hedef İlerlemesi',
        'description': 'Aktif hedef durumu',
        'icon': Icons.flag,
        'enabled': _widgets.any((w) => w.id == 'goal_progress' && w.isEnabled),
      },
      {
        'id': 'achievements',
        'name': 'Başarılar',
        'description': 'Son rozetler ve seviye',
        'icon': Icons.emoji_events,
        'enabled': _widgets.any((w) => w.id == 'achievements' && w.isEnabled),
      },
      {
        'id': 'quick_stats',
        'name': 'Hızlı İstatistikler',
        'description': 'Genel özet bilgiler',
        'icon': Icons.dashboard,
        'enabled': _widgets.any((w) => w.id == 'quick_stats' && w.isEnabled),
      },
      {
        'id': 'level_progress',
        'name': 'Seviye İlerlemesi',
        'description': 'Sonraki seviyeye ilerleme',
        'icon': Icons.grade,
        'enabled': _widgets.any((w) => w.id == 'level_progress' && w.isEnabled),
      },
    ];
  }

  /// Toggle widget enabled state
  Future<void> toggleWidget(String widgetId, bool enabled) async {
    final index = _widgets.indexWhere((w) => w.id == widgetId);
    if (index != -1) {
      _widgets[index] = _widgets[index].copyWith(isEnabled: enabled);
      await _saveWidgets();
      
      if (enabled) {
        // Update the specific widget
        switch (widgetId) {
          case 'carbon_today':
            await _setupCarbonTodayWidget();
            break;
          case 'weekly_progress':
            await _setupWeeklyProgressWidget();
            break;
          case 'goal_progress':
            await _setupGoalProgressWidget();
            break;
          case 'achievements':
            await _setupAchievementsWidget();
            break;
          case 'quick_stats':
            await _setupQuickStatsWidget();
            break;
          case 'level_progress':
            await _setupLevelProgressWidget();
            break;
        }
      }
      
      notifyListeners();
    }
  }

  /// Update settings
  Future<void> updateSettings({
    bool? autoUpdateEnabled,
    int? updateIntervalMinutes,
  }) async {
    if (autoUpdateEnabled != null) {
      _autoUpdateEnabled = autoUpdateEnabled;
    }
    if (updateIntervalMinutes != null) {
      _updateIntervalMinutes = updateIntervalMinutes;
    }
    
    await _saveSettings();
    notifyListeners();
    
    if (_autoUpdateEnabled) {
      scheduleWidgetUpdates();
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoUpdateEnabled = prefs.getBool('widget_auto_update') ?? true;
      _updateIntervalMinutes = prefs.getInt('widget_update_interval') ?? 30;
    } catch (e) {
      debugPrint('Error loading widget settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('widget_auto_update', _autoUpdateEnabled);
      await prefs.setInt('widget_update_interval', _updateIntervalMinutes);
    } catch (e) {
      debugPrint('Error saving widget settings: $e');
    }
  }

  /// Load widgets from SharedPreferences
  Future<void> _loadWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widgetsJson = prefs.getString('widgets_data');
      
      if (widgetsJson != null) {
        final widgetsList = jsonDecode(widgetsJson) as List;
        _widgets = widgetsList.map((json) => WidgetData.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading widgets: $e');
    }
  }

  /// Save widgets to SharedPreferences
  Future<void> _saveWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widgetsJson = jsonEncode(_widgets.map((w) => w.toJson()).toList());
      await prefs.setString('widgets_data', widgetsJson);
    } catch (e) {
      debugPrint('Error saving widgets: $e');
    }
  }

  /// Force refresh all widgets
  Future<void> refreshAllWidgets() async {
    await _updateAllWidgets();
    await _saveWidgets();
  }

  /// Get widget data by ID
  WidgetData? getWidgetData(String widgetId) {
    try {
      return _widgets.firstWhere((w) => w.id == widgetId);
    } catch (e) {
      return null;
    }
  }

  /// Get widget statistics
  Map<String, dynamic> getWidgetStatistics() {
    return {
      'totalWidgets': _widgets.length,
      'enabledWidgets': enabledWidgets.length,
      'lastUpdated': _widgets.isNotEmpty 
          ? _widgets.map((w) => w.lastUpdated).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now(),
      'autoUpdateEnabled': _autoUpdateEnabled,
      'updateInterval': _updateIntervalMinutes,
    };
  }
}