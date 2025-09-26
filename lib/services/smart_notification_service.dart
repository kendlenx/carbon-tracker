import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';

class SmartNotificationService {
  static SmartNotificationService? _instance;
  static SmartNotificationService get instance {
    _instance ??= SmartNotificationService._();
    return _instance!;
  }

  SmartNotificationService._();

  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  final LanguageService _languageService = LanguageService.instance;
  
  SharedPreferences? _prefs;
  Timer? _reminderTimer;

  // Preference keys
  static const String _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const String _reminderTimeKey = 'reminder_time';
  static const String _weeklyGoalReminderKey = 'weekly_goal_reminder';
  static const String _achievementNotificationsKey = 'achievement_notifications';
  static const String _insightNotificationsKey = 'insight_notifications';
  static const String _lastActivityDateKey = 'last_activity_date';
  static const String _notificationFrequencyKey = 'notification_frequency';

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _notificationService.initialize();
    _startReminderSchedule();
  }

  // Notification Settings
  Future<bool> isDailyReminderEnabled() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getBool(_dailyReminderEnabledKey) ?? true;
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_dailyReminderEnabledKey, enabled);
    _startReminderSchedule();
  }

  Future<TimeOfDay> getReminderTime() async {
    _prefs ??= await SharedPreferences.getInstance();
    final timeString = _prefs!.getString(_reminderTimeKey) ?? '20:00';
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]), 
      minute: int.parse(parts[1]),
    );
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    _prefs ??= await SharedPreferences.getInstance();
    final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await _prefs!.setString(_reminderTimeKey, timeString);
    _startReminderSchedule();
  }

  Future<bool> areAchievementNotificationsEnabled() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getBool(_achievementNotificationsKey) ?? true;
  }

  Future<void> setAchievementNotificationsEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_achievementNotificationsKey, enabled);
  }

  Future<bool> areInsightNotificationsEnabled() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getBool(_insightNotificationsKey) ?? true;
  }

  Future<void> setInsightNotificationsEnabled(bool enabled) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_insightNotificationsKey, enabled);
  }

  // Smart Notifications
  void _startReminderSchedule() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(
      const Duration(hours: 1), 
      (timer) => _checkAndSendReminders(),
    );
    
    // Also check immediately
    Future.delayed(const Duration(seconds: 5), _checkAndSendReminders);
  }

  Future<void> _checkAndSendReminders() async {
    if (!(await isDailyReminderEnabled())) return;

    final now = DateTime.now();
    final reminderTime = await getReminderTime();
    
    // Check if it's reminder time (within 1 hour window)
    if (now.hour == reminderTime.hour && now.minute >= reminderTime.minute && now.minute < reminderTime.minute + 60) {
      await _sendDailyReminder();
    }
    
    // Check for inactivity reminders
    await _checkInactivityReminders();
    
    // Check for achievement opportunities
    await _checkAchievementOpportunities();
    
    // Send weekly insights
    if (now.weekday == DateTime.sunday && now.hour == 10) {
      await _sendWeeklyInsights();
    }
  }

  Future<void> _sendDailyReminder() async {
    final lastActivityDate = await _getLastActivityDate();
    final today = DateTime.now();
    final daysSinceLastActivity = today.difference(lastActivityDate).inDays;
    
    String title, message;
    if (_languageService.isEnglish) {
      if (daysSinceLastActivity == 0) {
        title = '🌱 Great job today!';
        message = 'You\'ve been tracking your carbon footprint. Keep it up!';
      } else if (daysSinceLastActivity == 1) {
        title = '🚗 Track your transport today';
        message = 'Don\'t forget to log your daily activities for a greener tomorrow.';
      } else {
        title = '🌍 Your planet needs you';
        message = 'It\'s been $daysSinceLastActivity days. Let\'s get back to carbon tracking!';
      }
    } else {
      if (daysSinceLastActivity == 0) {
        title = '🌱 Bugün harika gidiyorsun!';
        message = 'Karbon ayak izini takip etmeye devam ediyorsun. Böyle devam et!';
      } else if (daysSinceLastActivity == 1) {
        title = '🚗 Bugünkü ulaşımını kaydet';
        message = 'Daha yeşil bir yarın için günlük aktivitelerini kaydetmeyi unutma.';
      } else {
        title = '🌍 Gezegenin sana ihtiyacı var';
        message = '$daysSinceLastActivity gün geçti. Karbon takibine geri dönelim!';
      }
    }
    
    await _notificationService.showNotification(
      id: 1001,
      title: title,
      body: message,
    );
  }

  Future<void> _checkInactivityReminders() async {
    final lastActivityDate = await _getLastActivityDate();
    final daysSinceLastActivity = DateTime.now().difference(lastActivityDate).inDays;
    
    // Send reminders after 3, 7, and 14 days of inactivity
    if ([3, 7, 14].contains(daysSinceLastActivity)) {
      String title, message;
      if (_languageService.isEnglish) {
        title = '🌿 Come back to Carbon Tracker';
        message = 'Your environmental impact matters. Let\'s continue your journey!';
      } else {
        title = '🌿 Carbon Tracker\'a geri dön';
        message = 'Çevresel etkileriniz önemli. Yolculuğumuza devam edelim!';
      }
      
      await _notificationService.showNotification(
        id: 1002,
        title: title,
        body: message,
      );
    }
  }

  Future<void> _checkAchievementOpportunities() async {
    final stats = await _databaseService.getDashboardStats();
    final todayTotal = stats['todayTotal'] as double;
    final weeklyAverage = stats['weeklyAverage'] as double;
    
    // Encourage low-carbon day achievements
    if (todayTotal < weeklyAverage * 0.5 && todayTotal > 0) {
      if (await areAchievementNotificationsEnabled()) {
        String title, message;
        if (_languageService.isEnglish) {
          title = '🏆 Achievement Unlocked!';
          message = 'Low Carbon Day - You\'re 50% below your average!';
        } else {
          title = '🏆 Başarı Açıldı!';
          message = 'Düşük Karbon Günü - Ortalamanın %50 altındasın!';
        }
        
        await _notificationService.showNotification(
          id: 1003,
          title: title,
          body: message,
        );
      }
    }
  }

  Future<void> _sendWeeklyInsights() async {
    if (!(await areInsightNotificationsEnabled())) return;
    
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklyStats = await _databaseService.getTotalCO2ForDateRange(weekAgo, now);
    
    String title, message;
    if (_languageService.isEnglish) {
      title = '📊 Your Weekly Impact';
      message = 'This week: ${weeklyStats.toStringAsFixed(1)} kg CO₂. Check your progress!';
    } else {
      title = '📊 Haftalık Etkiniz';
      message = 'Bu hafta: ${weeklyStats.toStringAsFixed(1)} kg CO₂. İlerlemenizi kontrol edin!';
    }
    
    await _notificationService.showNotification(
      id: 1004,
      title: title,
      body: message,
    );
  }

  // Achievement notifications
  Future<void> showAchievementNotification(String achievementTitle, String description) async {
    if (!(await areAchievementNotificationsEnabled())) return;
    
    String title, message;
    if (_languageService.isEnglish) {
      title = '🎉 New Achievement!';
      message = '$achievementTitle - $description';
    } else {
      title = '🎉 Yeni Başarı!';
      message = '$achievementTitle - $description';
    }
    
    await _notificationService.showNotification(
      id: 1005,
      title: title,
      body: message,
    );
  }

  // Goal-based notifications
  Future<void> showGoalProgressNotification(double progress, double target) async {
    final percentage = (progress / target * 100).round();
    
    String title, message;
    if (_languageService.isEnglish) {
      if (percentage >= 100) {
        title = '🎯 Goal Exceeded!';
        message = 'You\'ve reached $percentage% of your carbon reduction goal!';
      } else if (percentage >= 80) {
        title = '🔥 Almost there!';
        message = 'You\'re at $percentage% of your goal. Keep pushing!';
      } else {
        title = '💪 Keep going!';
        message = 'You\'re at $percentage% of your carbon reduction goal.';
      }
    } else {
      if (percentage >= 100) {
        title = '🎯 Hedef Aşıldı!';
        message = 'Karbon azaltma hedefinin %$percentage\'ine ulaştın!';
      } else if (percentage >= 80) {
        title = '🔥 Neredeyse tamam!';
        message = 'Hedefinin %$percentage\'indesin. Devam et!';
      } else {
        title = '💪 Devam et!';
        message = 'Karbon azaltma hedefinin %$percentage\'indesin.';
      }
    }
    
    await _notificationService.showNotification(
      id: 1006,
      title: title,
      body: message,
    );
  }

  // Contextual notifications
  Future<void> showContextualReminder(String activityType) async {
    final messages = _getContextualMessages(activityType);
    if (messages.isEmpty) return;
    
    final random = Random();
    final message = messages[random.nextInt(messages.length)];
    
    await _notificationService.showNotification(
      id: 1007,
      title: message['title']!,
      body: message['body']!,
    );
  }

  List<Map<String, String>> _getContextualMessages(String activityType) {
    if (_languageService.isEnglish) {
      switch (activityType.toLowerCase()) {
        case 'transport':
          return [
            {
              'title': '🚴 Try cycling today',
              'body': 'Short trips by bike can significantly reduce your carbon footprint!'
            },
            {
              'title': '🚌 Consider public transport',
              'body': 'Public transportation can cut your travel emissions by up to 85%!'
            },
          ];
        case 'energy':
          return [
            {
              'title': '💡 Energy saving tip',
              'body': 'Turn off lights and electronics when not in use to reduce CO₂!'
            },
          ];
        default:
          return [];
      }
    } else {
      switch (activityType.toLowerCase()) {
        case 'transport':
          return [
            {
              'title': '🚴 Bugün bisiklet dene',
              'body': 'Kısa mesafeler bisikletle karbon ayak izini önemli ölçüde azaltır!'
            },
            {
              'title': '🚌 Toplu taşımayı düşün',
              'body': 'Toplu taşıma seyahat emisyonlarını %85\'e kadar azaltabilir!'
            },
          ];
        case 'energy':
          return [
            {
              'title': '💡 Enerji tasarrufu ipucu',
              'body': 'Kullanmadığın ışıkları ve elektronik cihazları kapat, CO₂ azalt!'
            },
          ];
        default:
          return [];
      }
    }
  }

  // Helper methods
  Future<DateTime> _getLastActivityDate() async {
    _prefs ??= await SharedPreferences.getInstance();
    final timestamp = _prefs!.getInt(_lastActivityDateKey) ?? 0;
    return timestamp > 0 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now().subtract(const Duration(days: 30));
  }

  Future<void> updateLastActivityDate() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_lastActivityDateKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Cleanup
  void dispose() {
    _reminderTimer?.cancel();
  }
}