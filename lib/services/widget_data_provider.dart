import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'achievement_service.dart';
import 'language_service.dart';
import 'dart:io' show Platform;

/// Service for providing data to iOS widgets and Live Activities
class WidgetDataProvider extends ChangeNotifier {
  static WidgetDataProvider? _instance;
  static WidgetDataProvider get instance => _instance ??= WidgetDataProvider._();
  
  WidgetDataProvider._();

  static const String _appGroupId = 'group.carbon-tracker.shared';
  static const MethodChannel _platformChannel = MethodChannel('carbon_tracker/widgets');
  
  final LanguageService _languageService = LanguageService.instance;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the widget data provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set up platform method channel
      _platformChannel.setMethodCallHandler(_handleMethodCall);
      
      // Initial widget data update
      await updateWidgetData();
      
      _isInitialized = true;
      debugPrint('WidgetDataProvider initialized successfully');
    } catch (e) {
      debugPrint('Error initializing WidgetDataProvider: $e');
    }
  }

  /// Handle method calls from native iOS code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestWidgetUpdate':
        await updateWidgetData();
        return true;
        
      case 'startLiveActivity':
        final arguments = call.arguments as Map<String, dynamic>;
        return await startLiveActivity(
          sessionName: arguments['sessionName'] ?? 'Carbon Tracking',
          goalType: arguments['goalType'] ?? 'Daily Goal',
          targetCO2: (arguments['targetCO2'] as num?)?.toDouble() ?? 15.0,
          currentActivity: arguments['currentActivity'] ?? 'Tracking Started',
          category: arguments['category'] ?? 'Transport',
        );
        
      case 'updateLiveActivity':
        final arguments = call.arguments as Map<String, dynamic>;
        return await updateLiveActivity(
          currentCO2: (arguments['currentCO2'] as num?)?.toDouble() ?? 0.0,
          currentActivity: arguments['currentActivity'] ?? '',
          category: arguments['category'] ?? '',
          achievements: List<String>.from(arguments['achievements'] ?? []),
        );
        
      case 'stopLiveActivity':
        return await stopLiveActivity();
        
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Update widget data using UserDefaults (App Groups)
  Future<void> updateWidgetData() async {
    try {
      // Get dashboard stats
      final stats = await DatabaseService.instance.getDashboardStats();
      final achievements = AchievementService.instance.achievements;
      final recentAchievements = achievements
          .where((a) => a.isUnlocked)
          .take(3)
          .map((a) => a.title)
          .toList();

      // Calculate yesterday's CO2 for comparison
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayCO2 = await DatabaseService.instance.getTotalCO2ForDate(yesterday);

      // Determine top category
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final co2ByCategory = await DatabaseService.instance.getCO2ByTransportType(
        startDate: today,
        endDate: now,
      );
      
      String topCategory = 'Transport';
      if (co2ByCategory.isNotEmpty) {
        topCategory = co2ByCategory.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      // Prepare widget data
      final widgetData = {
        'todayCO2': stats['todayTotal'] ?? 0.0,
        'weeklyAverage': stats['weeklyAverage'] ?? 0.0,
        'monthlyGoal': 400.0, // Default monthly goal
        'yesterdayCO2': yesterdayCO2,
        'topCategory': _getCategoryDisplayName(topCategory),
        'recentAchievements': recentAchievements,
        'lastUpdate': DateTime.now().toIso8601String(),
      };

      // Update widgets via platform channel
      if (Platform.isIOS) {
        await _platformChannel.invokeMethod('updateWidgetData', widgetData);
      }

      debugPrint('Widget data updated: ${widgetData['todayCO2']} kg CO₂');
    } catch (e) {
      debugPrint('Error updating widget data: $e');
    }
  }

  /// Update widget data when new activity is added
  Future<void> onActivityAdded({
    required String category,
    required double co2Amount,
    String? description,
  }) async {
    await updateWidgetData();
    
    // If Live Activity is running, update it
    if (await isLiveActivityActive()) {
      await updateLiveActivity(
        currentCO2: await _getCurrentDailyCO2(),
        currentActivity: description ?? 'New ${_getCategoryDisplayName(category)} Activity',
        category: category,
      );
    }
    
    notifyListeners();
  }

  /// Start Live Activity for carbon tracking session
  Future<bool> startLiveActivity({
    required String sessionName,
    required String goalType,
    required double targetCO2,
    required String currentActivity,
    required String category,
  }) async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _platformChannel.invokeMethod('startLiveActivity', {
        'sessionName': sessionName,
        'goalType': goalType,
        'targetCO2': targetCO2,
        'currentActivity': currentActivity,
        'category': _getCategoryDisplayName(category),
      });
      
      debugPrint('Live Activity started: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error starting Live Activity: $e');
      return false;
    }
  }

  /// Update Live Activity with new data
  Future<bool> updateLiveActivity({
    required double currentCO2,
    required String currentActivity,
    required String category,
    List<String> achievements = const [],
  }) async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _platformChannel.invokeMethod('updateLiveActivity', {
        'currentCO2': currentCO2,
        'currentActivity': currentActivity,
        'category': _getCategoryDisplayName(category),
        'achievements': achievements,
      });
      
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error updating Live Activity: $e');
      return false;
    }
  }

  /// Stop Live Activity
  Future<bool> stopLiveActivity() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _platformChannel.invokeMethod('stopLiveActivity');
      debugPrint('Live Activity stopped: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error stopping Live Activity: $e');
      return false;
    }
  }

  /// Check if Live Activity is currently active
  Future<bool> isLiveActivityActive() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _platformChannel.invokeMethod('isLiveActivityActive');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking Live Activity status: $e');
      return false;
    }
  }

  /// Start daily carbon tracking Live Activity
  Future<bool> startDailyTracking({double? customGoal}) async {
    final dailyGoal = customGoal ?? 13.3; // ~400kg monthly goal / 30 days
    
    return await startLiveActivity(
      sessionName: _languageService.isEnglish ? 'Daily Carbon Tracking' : 'Günlük Karbon Takibi',
      goalType: _languageService.isEnglish ? 'Daily Goal' : 'Günlük Hedef',
      targetCO2: dailyGoal,
      currentActivity: _languageService.isEnglish ? 'Tracking Started' : 'Takip Başlatıldı',
      category: 'Transport',
    );
  }

  /// Start activity-specific Live Activity
  Future<bool> startActivityTracking({
    required String activityName,
    required String category,
    double? estimatedCO2,
  }) async {
    final estimated = estimatedCO2 ?? 5.0;
    
    return await startLiveActivity(
      sessionName: _languageService.isEnglish ? '$activityName Session' : '$activityName Oturumu',
      goalType: _languageService.isEnglish ? 'Activity Goal' : 'Aktivite Hedefi',
      targetCO2: estimated,
      currentActivity: activityName,
      category: category,
    );
  }

  /// Get current daily CO2 total
  Future<double> _getCurrentDailyCO2() async {
    final stats = await DatabaseService.instance.getDashboardStats();
    return stats['todayTotal'] ?? 0.0;
  }

  /// Get category display name in current language
  String _getCategoryDisplayName(String category) {
    if (!_languageService.isEnglish) {
      switch (category.toLowerCase()) {
        case 'transport':
          return 'Ulaşım';
        case 'energy':
          return 'Enerji';
        case 'food':
          return 'Yemek';
        case 'shopping':
          return 'Alışveriş';
        default:
          return category;
      }
    }
    return category;
  }

  /// Schedule periodic widget updates
  void schedulePeriodicUpdates() {
    // Update widgets every 15 minutes
    Stream.periodic(const Duration(minutes: 15)).listen((_) {
      updateWidgetData();
    });
  }

  /// Update widgets when app becomes active
  Future<void> onAppResumed() async {
    await updateWidgetData();
  }

  /// Update widgets when app goes to background
  Future<void> onAppPaused() async {
    await updateWidgetData();
  }

  /// Get widget configuration for user preferences
  Future<Map<String, dynamic>> getWidgetConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'showAchievements': prefs.getBool('widget_show_achievements') ?? true,
      'showComparison': prefs.getBool('widget_show_comparison') ?? true,
      'showProgress': prefs.getBool('widget_show_progress') ?? true,
      'updateFrequency': prefs.getInt('widget_update_frequency') ?? 15, // minutes
      'preferredSize': prefs.getString('widget_preferred_size') ?? 'medium',
    };
  }

  /// Set widget configuration
  Future<void> setWidgetConfiguration({
    bool? showAchievements,
    bool? showComparison,
    bool? showProgress,
    int? updateFrequency,
    String? preferredSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (showAchievements != null) {
      await prefs.setBool('widget_show_achievements', showAchievements);
    }
    if (showComparison != null) {
      await prefs.setBool('widget_show_comparison', showComparison);
    }
    if (showProgress != null) {
      await prefs.setBool('widget_show_progress', showProgress);
    }
    if (updateFrequency != null) {
      await prefs.setInt('widget_update_frequency', updateFrequency);
    }
    if (preferredSize != null) {
      await prefs.setString('widget_preferred_size', preferredSize);
    }
    
    // Update widgets with new configuration
    await updateWidgetData();
    notifyListeners();
  }

  /// Get widget preview data for settings screen
  Map<String, dynamic> getPreviewData() {
    return {
      'todayCO2': 8.7,
      'weeklyAverage': 12.3,
      'monthlyGoal': 400.0,
      'topCategory': _languageService.isEnglish ? 'Transport' : 'Ulaşım',
      'progress': 0.65,
      'trend': 'improving',
      'achievements': [
        _languageService.isEnglish ? '🌱 Green Week' : '🌱 Yeşil Hafta',
        _languageService.isEnglish ? '🚶 Walker' : '🚶 Yürüyüşçü',
      ],
    };
  }

  /// Check if widgets are supported on this platform
  bool get isWidgetSupported => Platform.isIOS;

  /// Check if Live Activities are supported
  bool get isLiveActivitySupported => Platform.isIOS;

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}

/// Widget data update event
class WidgetDataUpdateEvent {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String source;

  WidgetDataUpdateEvent({
    required this.data,
    required this.timestamp,
    required this.source,
  });
}

/// Live Activity state
enum LiveActivityState {
  inactive,
  starting,
  active,
  updating,
  stopping,
  error,
}

/// Live Activity session data
class LiveActivitySession {
  final String sessionName;
  final String goalType;
  final double targetCO2;
  final DateTime startTime;
  final String category;
  LiveActivityState state;
  double currentCO2;
  String currentActivity;
  List<String> achievements;

  LiveActivitySession({
    required this.sessionName,
    required this.goalType,
    required this.targetCO2,
    required this.startTime,
    required this.category,
    this.state = LiveActivityState.inactive,
    this.currentCO2 = 0.0,
    this.currentActivity = '',
    this.achievements = const [],
  });

  double get progress => targetCO2 > 0 ? (currentCO2 / targetCO2).clamp(0.0, 1.0) : 0.0;
  
  Duration get duration => DateTime.now().difference(startTime);

  Map<String, dynamic> toJson() {
    return {
      'sessionName': sessionName,
      'goalType': goalType,
      'targetCO2': targetCO2,
      'startTime': startTime.toIso8601String(),
      'category': category,
      'state': state.toString(),
      'currentCO2': currentCO2,
      'currentActivity': currentActivity,
      'achievements': achievements,
      'progress': progress,
      'duration': duration.inSeconds,
    };
  }
}