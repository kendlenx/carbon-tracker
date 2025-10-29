import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io';
import 'dart:math' as math;

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
  String Function(String key) _t = (k) => k;
  void setTranslator(String Function(String key) t) { _t = t; }
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _notificationsEnabled = true;
  bool _dailyRemindersEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _weeklyReportsEnabled = true;
  bool _smartSuggestionsEnabled = true;
  
  // Legacy single time (kept for backward compatibility)
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Smart window scheduling (randomization within window)
  TimeOfDay _windowStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _windowEnd = const TimeOfDay(hour: 21, minute: 0);

  // Quiet hours (no notifications)
  TimeOfDay _quietStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  // Frequency caps
  int _dailyCap = 3;
  int _weeklyCap = 15;

  // Runtime counters and last sent tracking
  final Map<String, DateTime> _lastSentByChannel = {};
  DateTime _lastDailyReset = DateTime.now();
  int _sentToday = 0;
  int _sentThisWeek = 0;
  final Duration _minInterval = const Duration(minutes: 20);
  
  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get dailyRemindersEnabled => _dailyRemindersEnabled;
  bool get achievementNotificationsEnabled => _achievementNotificationsEnabled;
  bool get weeklyReportsEnabled => _weeklyReportsEnabled;
  bool get smartSuggestionsEnabled => _smartSuggestionsEnabled;
  TimeOfDay get dailyReminderTime => _dailyReminderTime;
  TimeOfDay get windowStart => _windowStart;
  TimeOfDay get windowEnd => _windowEnd;
  TimeOfDay get quietStart => _quietStart;
  TimeOfDay get quietEnd => _quietEnd;
  int get dailyCap => _dailyCap;
  int get weeklyCap => _weeklyCap;

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
      _resetCountersIfNeeded(force: true);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      // Don't throw - continue app startup even if notifications fail
      _notificationsEnabled = false;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ için POST_NOTIFICATIONS permission gerekli
      final notificationStatus = await Permission.notification.request();
      
      // Android 12+ için SCHEDULE_EXACT_ALARM permission kontrol et
      bool exactAlarmGranted = true;
      if (Platform.isAndroid) {
        try {
          final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
          if (!exactAlarmStatus.isGranted) {
            // Exact alarm permission yoksa kullanıcıyı uyar ama uygulamayı durdurma
            debugPrint('⚠️ Exact alarm permission not granted - using fallback notifications');
            exactAlarmGranted = false;
          }
        } catch (e) {
          debugPrint('⚠️ Exact alarm permission check failed: $e');
          exactAlarmGranted = false;
        }
      }
      
      _notificationsEnabled = notificationStatus.isGranted;
      
      // Eğer exact alarm izni yoksa, scheduled notification'ları devre dışı bırak
      if (!exactAlarmGranted) {
        _dailyRemindersEnabled = false;
        _weeklyReportsEnabled = false;
        await _saveSettings();
      }
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
    debugPrint('Notification tapped: ${response.payload}');
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
      
      // Load daily reminder time (legacy)
      final hour = prefs.getInt('daily_reminder_hour') ?? 20;
      final minute = prefs.getInt('daily_reminder_minute') ?? 0;
      _dailyReminderTime = TimeOfDay(hour: hour, minute: minute);

      // Load smart window and quiet hours
      _windowStart = TimeOfDay(
        hour: prefs.getInt('notify_window_start_h') ?? 18,
        minute: prefs.getInt('notify_window_start_m') ?? 0,
      );
      _windowEnd = TimeOfDay(
        hour: prefs.getInt('notify_window_end_h') ?? 21,
        minute: prefs.getInt('notify_window_end_m') ?? 0,
      );
      _quietStart = TimeOfDay(
        hour: prefs.getInt('quiet_start_h') ?? 23,
        minute: prefs.getInt('quiet_start_m') ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour: prefs.getInt('quiet_end_h') ?? 7,
        minute: prefs.getInt('quiet_end_m') ?? 0,
      );

      _dailyCap = prefs.getInt('notify_daily_cap') ?? 3;
      _weeklyCap = prefs.getInt('notify_weekly_cap') ?? 15;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
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

      // Save smart window & quiet hours + caps
      await prefs.setInt('notify_window_start_h', _windowStart.hour);
      await prefs.setInt('notify_window_start_m', _windowStart.minute);
      await prefs.setInt('notify_window_end_h', _windowEnd.hour);
      await prefs.setInt('notify_window_end_m', _windowEnd.minute);
      await prefs.setInt('quiet_start_h', _quietStart.hour);
      await prefs.setInt('quiet_start_m', _quietStart.minute);
      await prefs.setInt('quiet_end_h', _quietEnd.hour);
      await prefs.setInt('quiet_end_m', _quietEnd.minute);
      await prefs.setInt('notify_daily_cap', _dailyCap);
      await prefs.setInt('notify_weekly_cap', _weeklyCap);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
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

  DateTime _combine(DateTime day, TimeOfDay t) => DateTime(day.year, day.month, day.day, t.hour, t.minute);

  bool _isWithinQuietHours(DateTime dt) {
    final start = _combine(dt, _quietStart);
    final end = _combine(dt, _quietEnd);
    if (_quietStart.hour <= _quietEnd.hour) {
      // Same-day window
      return dt.isAfter(start) && dt.isBefore(end);
    } else {
      // Overnight window
      return dt.isAfter(start) || dt.isBefore(end);
    }
  }

  void _resetCountersIfNeeded({bool force = false}) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    if (force || _lastDailyReset.isBefore(startOfDay)) {
      _sentToday = 0;
      _lastDailyReset = startOfDay;
    }
    if (_lastDailyReset.isBefore(startOfWeek)) {
      _sentThisWeek = 0;
    }
  }

  bool _canSend(String channelKey) {
    _resetCountersIfNeeded();
    final now = DateTime.now();
    if (_isWithinQuietHours(now)) return false;
    if (_sentToday >= _dailyCap) return false;
    if (_sentThisWeek >= _weeklyCap) return false;
    final last = _lastSentByChannel[channelKey];
    if (last != null && now.difference(last) < _minInterval) return false;
    return true;
  }

  void _recordSend(String channelKey) {
    _lastSentByChannel[channelKey] = DateTime.now();
    _sentToday += 1;
    _sentThisWeek += 1;
  }

  DateTime _randomInWindow(DateTime baseDay) {
    final start = _combine(baseDay, _windowStart);
    final end = _combine(baseDay, _windowEnd);
    final span = end.difference(start).inMinutes;
    final rnd = math.Random().nextInt(math.max(1, span));
    return start.add(Duration(minutes: rnd));
  }

  /// Schedule daily carbon goal reminders (3 random times in window)
  Future<void> _scheduleDailyReminder() async {
    try {
      // Cancel previous daily reminders (IDs 1..3)
      for (int id = 1; id <= 3; id++) {
        await _notifications.cancel(id);
      }
      
      if (!_dailyRemindersEnabled || !_notificationsEnabled) return;
      
      final now = DateTime.now();
      // Determine target day (today if window not passed, otherwise tomorrow)
      final windowEndToday = _combine(now, _windowEnd);
      final baseDay = now.isAfter(windowEndToday) ? now.add(const Duration(days: 1)) : now;
      final start = _combine(baseDay, _windowStart);
      final end = _combine(baseDay, _windowEnd);
      final span = end.difference(start).inMinutes;
      if (span <= 0) return;
      
      // Pick 3 dispersed times within the window
      final rnd = math.Random();
      List<int> offsets = [
        (span * 0.2).round() + rnd.nextInt(20),
        (span * 0.5).round() + rnd.nextInt(20),
        (span * 0.8).round() + rnd.nextInt(20),
      ];
      offsets.sort();
      
      for (int i = 0; i < offsets.length; i++) {
        final candidate = start.add(Duration(minutes: offsets[i]));
        await _notifications.zonedSchedule(
          1 + i,
          _t('notifications.dailyReminderTitle'),
          _t('notifications.dailyReminderBody'),
          tz.TZDateTime.from(candidate, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder',
              _t('notifications.channels.dailyReminder.name'),
              channelDescription: _t('notifications.channels.dailyReminder.desc'),
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'daily_reminder',
            ),
          ),
          payload: 'daily_reminder',
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
      // Disable scheduled notifications if exact alarms are not permitted
      if (e.toString().contains('exact_alarms_not_permitted')) {
        debugPrint('Exact alarms not permitted - using regular notifications');
        _dailyRemindersEnabled = false;
        await _saveSettings();
      }
    }
  }

  /// Show a generic notification (respects quiet hours and caps)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_notificationsEnabled) return;
    
    try {
      if (!_canSend('general')) return;
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'general',
            'General Notifications',
            channelDescription: 'General app notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
      _recordSend('general');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Send achievement notification
  Future<void> showAchievementNotification(String title, String description, int points) async {
    if (!_achievementNotificationsEnabled || !_notificationsEnabled) return;
    
    if (!_canSend('achievements')) return;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      _t('notifications.achievementTitle'),
      '$title - +$points XP',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          _t('notifications.channels.achievements.name'),
          channelDescription: _t('notifications.channels.achievements.desc'),
          importance: Importance.high,
          priority: Priority.high,
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
    _recordSend('achievements');
  }
  
  /// Send smart suggestion notification
  Future<void> showSmartSuggestionNotification(String title, String description, double potentialSaving) async {
    if (!_smartSuggestionsEnabled || !_notificationsEnabled) return;
    
    if (!_canSend('smart_suggestions')) return;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      _t('notifications.smartTipTitle'),
      '$description\n🌱 -${potentialSaving.toStringAsFixed(1)} kg CO₂',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_suggestions',
          _t('notifications.channels.smartSuggestions.name'),
          channelDescription: _t('notifications.channels.smartSuggestions.desc'),
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'smart_suggestion',
        ),
      ),
      payload: 'smart_suggestion|$title',
    );
    _recordSend('smart_suggestions');
  }
  
  /// Send goal milestone notification
  Future<void> showGoalMilestoneNotification(String milestone, double currentValue, double goalValue) async {
    if (!_achievementNotificationsEnabled || !_notificationsEnabled) return;
    
    final progress = (currentValue / goalValue * 100).round();
    
    if (!_canSend('goal_milestones')) return;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      _t('notifications.goalReachedTitle'),
      '$milestone\n📊 $progress% ${_t('notifications.completedShort')}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_milestones',
          _t('notifications.channels.goalMilestones.name'),
          channelDescription: _t('notifications.channels.goalMilestones.desc'),
          importance: Importance.high,
          priority: Priority.high,
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
    _recordSend('goal_milestones');
  }
  
  /// Triggers & smart reminders
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
        _t('notifications.transportPlanTitle'),
        _t('notifications.transportPlanBody'),
        tz.TZDateTime.from(morningTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'smart_reminders',
            _t('notifications.channels.smartReminders.name'),
            channelDescription: _t('notifications.channels.smartReminders.desc'),
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
        _t('notifications.energyReminderTitle'),
        _t('notifications.energyReminderBody'),
        tz.TZDateTime.from(eveningTime, tz.local),
        NotificationDetails(
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

  // Platform/event hooks (to be wired from native/usage listeners)
  Future<void> onScreenUnlock() async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: _t('notifications.quickLogTitle'),
      body: _t('notifications.quickLogBody'),
      payload: 'trigger|unlock',
    );
  }

  Future<void> onLongUsage() async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: _t('notifications.takeABreakTitle'),
      body: _t('notifications.takeABreakBody'),
      payload: 'trigger|usage',
    );
  }

  Future<void> onNetworkBackOnline() async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: _t('notifications.syncDoneTitle'),
      body: _t('notifications.syncDoneBody'),
      payload: 'trigger|sync',
    );
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
      _t('notifications.weeklyReportTitle'),
      '${_t('notifications.total')}: ${totalCO2.toStringAsFixed(1)} kg CO₂\n$message\n🌟 ${_t('notifications.bestDay')}: $bestDay',
      NotificationDetails(
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
      _t('notifications.weeklyReportTitle'),
      _t('notifications.weeklyReportBody'),
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report',
          'Haftalık Raporlar',
          channelDescription: 'Haftalık karbon performans raporları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
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
      _t('notifications.smartTipTitle'),
      suggestion,
      NotificationDetails(
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