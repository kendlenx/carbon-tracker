import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';

enum NotificationType {
  dailyReminder,
  goalAchievement,
  weeklyReport,
  streakReminder,
  smartSuggestion,
  levelUp,
  badgeEarned,
}

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _notificationsEnabled = true;
  bool _dailyRemindersEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _weeklyReportsEnabled = true;
  bool _smartSuggestionsEnabled = true;
  
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);
  
  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get dailyRemindersEnabled => _dailyRemindersEnabled;
  bool get achievementNotificationsEnabled => _achievementNotificationsEnabled;
  bool get weeklyReportsEnabled => _weeklyReportsEnabled;
  bool get smartSuggestionsEnabled => _smartSuggestionsEnabled;
  TimeOfDay get dailyReminderTime => _dailyReminderTime;

  /// Initialize notifications
  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      
      // Android initialization settings
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      
      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      await _requestPermissions();
      await _loadSettings();
      await _scheduleDefaultNotifications();
    } catch (e) {
      print('Error initializing notifications: $e');
      // Don't throw - continue app startup even if notifications fail
      _notificationsEnabled = false;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      _notificationsEnabled = status.isGranted;
    } else if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _notificationsEnabled = granted ?? false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle different notification types
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Load notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _dailyRemindersEnabled = prefs.getBool('daily_reminders_enabled') ?? true;
      _achievementNotificationsEnabled = prefs.getBool('achievement_notifications_enabled') ?? true;
      _weeklyReportsEnabled = prefs.getBool('weekly_reports_enabled') ?? true;
      _smartSuggestionsEnabled = prefs.getBool('smart_suggestions_enabled') ?? true;
      
      // Load daily reminder time
      final hour = prefs.getInt('daily_reminder_hour') ?? 20;
      final minute = prefs.getInt('daily_reminder_minute') ?? 0;
      _dailyReminderTime = TimeOfDay(hour: hour, minute: minute);
      
      notifyListeners();
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  /// Save notification settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('daily_reminders_enabled', _dailyRemindersEnabled);
      await prefs.setBool('achievement_notifications_enabled', _achievementNotificationsEnabled);
      await prefs.setBool('weekly_reports_enabled', _weeklyReportsEnabled);
      await prefs.setBool('smart_suggestions_enabled', _smartSuggestionsEnabled);
      
      await prefs.setInt('daily_reminder_hour', _dailyReminderTime.hour);
      await prefs.setInt('daily_reminder_minute', _dailyReminderTime.minute);
    } catch (e) {
      print('Error saving notification settings: $e');
    }
  }

  /// Schedule default notifications
  Future<void> _scheduleDefaultNotifications() async {
    if (_dailyRemindersEnabled && _notificationsEnabled) {
      await _scheduleDailyReminder();
    }
    
    if (_weeklyReportsEnabled && _notificationsEnabled) {
      await _scheduleWeeklyReport();
    }
  }

  /// Schedule daily carbon goal reminder
  Future<void> _scheduleDailyReminder() async {
    await _notifications.cancel(1); // Cancel existing
    
    if (!_dailyRemindersEnabled || !_notificationsEnabled) return;
    
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year, 
      now.month, 
      now.day,
      _dailyReminderTime.hour,
      _dailyReminderTime.minute,
    );
    
    // If the time has passed today, schedule for tomorrow
    final scheduleTime = scheduledDate.isBefore(now) 
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;
    
    await _notifications.zonedSchedule(
      1,
      '🌱 Karbon Takibi Hatırlatıcısı',
      'Bugün karbon ayak izinizi kaydetmeyi unutmayın!',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Günlük Hatırlatıcılar',
          channelDescription: 'Günlük karbon takibi hatırlatıcıları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'daily_reminder',
        ),
      ),
      payload: 'daily_reminder',
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Send achievement notification
  Future<void> showAchievementNotification(String title, String description, int points) async {
    if (!_achievementNotificationsEnabled || !_notificationsEnabled) return;
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      '🏆 Başarı Kazandın!',
      '$title - +$points XP',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Başarılar',
          channelDescription: 'Başarı bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: Colors.amber,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'achievement',
          presentSound: true,
        ),
      ),
      payload: 'achievement|$title',
    );
  }
  
  /// Send smart suggestion notification
  Future<void> showSmartSuggestionNotification(String title, String description, double potentialSaving) async {
    if (!_smartSuggestionsEnabled || !_notificationsEnabled) return;
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      '💡 Akıllı Öneri',
      '$description\n🌱 -${potentialSaving.toStringAsFixed(1)} kg CO₂',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_suggestions',
          'Akıllı Öneriler',
          channelDescription: 'Yapay zeka destekli öneriler',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'smart_suggestion',
        ),
      ),
      payload: 'smart_suggestion|$title',
    );
  }
  
  /// Send goal milestone notification
  Future<void> showGoalMilestoneNotification(String milestone, double currentValue, double goalValue) async {
    if (!_achievementNotificationsEnabled || !_notificationsEnabled) return;
    
    final progress = (currentValue / goalValue * 100).round();
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🎆 Hedefe Ulaştın!',
      '$milestone\n📊 $progress% tamamlandı!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_milestones',
          'Hedef Kilometre Taşları',
          channelDescription: 'Hedef ilerlemesi bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: Colors.green,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'goal_milestone',
          presentSound: true,
        ),
      ),
      payload: 'goal_milestone|$milestone',
    );
  }
  
  /// Schedule smart reminders based on user patterns
  Future<void> scheduleSmartReminders(Map<String, dynamic> userPatterns) async {
    if (!_notificationsEnabled) return;
    
    // Cancel existing smart reminders
    for (int i = 100; i <= 110; i++) {
      await _notifications.cancel(i);
    }
    
    final now = DateTime.now();
    
    // Morning transport reminder (if user often forgets)
    if (userPatterns['forgetsTransport'] == true) {
      final morningTime = DateTime(
        now.year, now.month, now.day + 1, 8, 30
      );
      
      await _notifications.zonedSchedule(
        100,
        '🚌 Ulaşım Planını Yaptın mı?',
        'Bugün hangi ulaşım türlerini kullanacağını planla ve kaydet!',
        tz.TZDateTime.from(morningTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'smart_reminders',
            'Akıllı Hatırlatmalar',
            channelDescription: 'Kişiselleştirilmiş hatırlatmalar',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/launcher_icon',
          ),
        ),
        payload: 'smart_reminder|transport_morning',
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    
    // Evening energy reminder (if user uses a lot of energy)
    if (userPatterns['highEnergyUser'] == true) {
      final eveningTime = DateTime(
        now.year, now.month, now.day + 1, 19, 0
      );
      
      await _notifications.zonedSchedule(
        101,
        '⚡ Enerji Tasarrufu Zamanı',
        'Bugün enerji tüketimini azaltmak için neler yaptın? Kayıtlarını güncelle!',
        tz.TZDateTime.from(eveningTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'smart_reminders',
            'Akıllı Hatırlatmalar',
            channelDescription: 'Kişiselleştirilmiş hatırlatmalar',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/launcher_icon',
          ),
        ),
        payload: 'smart_reminder|energy_evening',
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
  
  /// Send weekly summary notification
  Future<void> sendWeeklySummary(Map<String, dynamic> weeklyStats) async {
    if (!_weeklyReportsEnabled || !_notificationsEnabled) return;
    
    final totalCO2 = weeklyStats['totalCO2'] ?? 0.0;
    final improvement = weeklyStats['improvement'] ?? 0.0;
    final bestDay = weeklyStats['bestDay'] ?? 'Pazartesi';
    
    String message;
    if (improvement > 0) {
      message = 'Bu hafta geçen haftaya göre ${improvement.toStringAsFixed(1)} kg daha az CO₂ üretti!';
    } else if (improvement < 0) {
      message = 'Bu hafta ${improvement.abs().toStringAsFixed(1)} kg daha fazla CO₂ ürettin. Gelecek hafta daha iyi olacak!';
    } else {
      message = 'Bu hafta sabit bir performans gösterdin!';
    }
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📈 Haftalık Karbon Raporu',
      'Toplam: ${totalCO2.toStringAsFixed(1)} kg CO₂\n$message\n🌟 En iyi gün: $bestDay',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reports',
          'Haftalık Raporlar',
          channelDescription: 'Haftalık karbon raporu bildirimleri',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
          color: Colors.purple,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'weekly_report',
        ),
      ),
      payload: 'weekly_report',
    );
  }

  /// Schedule weekly carbon report
  Future<void> _scheduleWeeklyReport() async {
    await _notifications.cancel(2); // Cancel existing
    
    if (!_weeklyReportsEnabled || !_notificationsEnabled) return;
    
    final now = DateTime.now();
    final daysUntilSunday = (7 - now.weekday) % 7;
    final nextSunday = now.add(Duration(days: daysUntilSunday));
    final scheduledDate = DateTime(
      nextSunday.year,
      nextSunday.month,
      nextSunday.day,
      19, // 7 PM
      0,
    );
    
    await _notifications.zonedSchedule(
      2,
      '📊 Haftalık Karbon Raporu',
      'Bu haftaki performansınızı görüntüleyin ve hedeflerinizi kontrol edin!',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report',
          'Haftalık Raporlar',
          channelDescription: 'Haftalık karbon performans raporları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'weekly_report',
        ),
      ),
      payload: 'weekly_report',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }


  /// Show smart suggestion notification
  Future<void> showSmartSuggestion(String suggestion, {String? payload}) async {
    if (!_smartSuggestionsEnabled || !_notificationsEnabled) return;
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '💡 Akıllı Öneri',
      suggestion,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_suggestions',
          'Akıllı Öneriler',
          channelDescription: 'Karbon azaltma önerileri',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'suggestion',
        ),
      ),
      payload: payload ?? 'smart_suggestion',
    );
  }

  /// Show goal completion notification
  Future<void> showGoalCompletionNotification(String goalType, double percentage) async {
    if (!_achievementNotificationsEnabled || !_notificationsEnabled) return;
    
    String emoji;
    String message;
    
    if (percentage >= 100) {
      emoji = '🎉';
      message = '$goalType hedefinizi tamamladınız! Harika iş!';
    } else if (percentage >= 80) {
      emoji = '🔥';
      message = '$goalType hedefinizin ${percentage.toInt()}%\'ine ulaştınız!';
    } else if (percentage >= 50) {
      emoji = '⚡';
      message = '$goalType hedefinizin yarısını tamamladınız!';
    } else {
      return; // Don't send notification for low progress
    }
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '$emoji Hedef İlerlemesi',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_progress',
          'Hedef İlerlemesi',
          channelDescription: 'Hedef ilerleme bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: Colors.orange,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'goal_progress',
          sound: 'default',
        ),
      ),
      payload: 'goal_progress',
    );
  }

  /// Update notification settings
  Future<void> updateSettings({
    bool? notificationsEnabled,
    bool? dailyRemindersEnabled,
    bool? achievementNotificationsEnabled,
    bool? weeklyReportsEnabled,
    bool? smartSuggestionsEnabled,
    TimeOfDay? dailyReminderTime,
  }) async {
    if (notificationsEnabled != null) {
      _notificationsEnabled = notificationsEnabled;
    }
    if (dailyRemindersEnabled != null) {
      _dailyRemindersEnabled = dailyRemindersEnabled;
    }
    if (achievementNotificationsEnabled != null) {
      _achievementNotificationsEnabled = achievementNotificationsEnabled;
    }
    if (weeklyReportsEnabled != null) {
      _weeklyReportsEnabled = weeklyReportsEnabled;
    }
    if (smartSuggestionsEnabled != null) {
      _smartSuggestionsEnabled = smartSuggestionsEnabled;
    }
    if (dailyReminderTime != null) {
      _dailyReminderTime = dailyReminderTime;
    }
    
    await _saveSettings();
    await _scheduleDefaultNotifications();
    notifyListeners();
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Generate random smart suggestions
  List<String> getSmartSuggestions() {
    return [
      'Bugün bisiklet kullanarak 2.5kg CO₂ tasarruf edebilirsiniz!',
      'Kısa mesafeler için yürümeyi tercih edin.',
      'Toplu taşıma kullanarak günlük karbon ayak izinizi %40 azaltabilirsiniz.',
      'LED ampul kullanımı ile yıllık enerji tüketiminizi %80 azaltın.',
      'Evinizin sıcaklığını 1°C düşürerek %7 enerji tasarrufu sağlayın.',
      'Kısa duşlar almanız su ve enerji tasarrufu sağlar.',
      'Elektronik cihazları tamamen kapatmayı unutmayın.',
      'Güneşli havalarda çamaşırları makine yerine dışarıda kurutun.',
    ];
  }

  /// Schedule random smart suggestion
  Future<void> scheduleRandomSmartSuggestion() async {
    if (!_smartSuggestionsEnabled || !_notificationsEnabled) return;
    
    final suggestions = getSmartSuggestions();
    final randomSuggestion = suggestions[DateTime.now().millisecond % suggestions.length];
    
    final now = DateTime.now();
    final scheduledTime = now.add(const Duration(hours: 2)); // 2 hours from now
    
    await _notifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '💡 Akıllı Öneri',
      randomSuggestion,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_suggestions',
          'Akıllı Öneriler',
          channelDescription: 'Karbon azaltma önerileri',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'suggestion',
        ),
      ),
      payload: 'smart_suggestion',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}