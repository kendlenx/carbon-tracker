import 'dart:async';
import 'package:flutter/widgets.dart';
import 'notification_service.dart';
import 'widget_data_provider.dart';
import 'widget_service.dart';

/// Observes app lifecycle to trigger contextual notifications
class LifecycleService with WidgetsBindingObserver {
  LifecycleService._();
  static LifecycleService? _instance;
  static LifecycleService get instance => _instance ??= LifecycleService._();

  DateTime? _backgroundAt;
  DateTime? _sessionStart;
  Timer? _usageTimer;
  bool _longUsageSentThisSession = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _sessionStart = DateTime.now();
    _startUsageTimer();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Consider this akin to an unlock/resume
        final now = DateTime.now();
        if (_backgroundAt != null) {
          final away = now.difference(_backgroundAt!);
          if (away.inMinutes >= 10) {
            // Trigger unlock hook after being away for a bit
            unawaited(NotificationService.instance.onScreenUnlock());
          }
        }
        // Refresh widgets on resume
        unawaited(WidgetDataProvider.instance.onAppResumed());
        unawaited(WidgetService.instance.refreshAllWidgets());
        _sessionStart = now;
        _longUsageSentThisSession = false;
        _startUsageTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundAt = DateTime.now();
        _usageTimer?.cancel();
        // Update widgets when going to background
        unawaited(WidgetDataProvider.instance.onAppPaused());
        break;
      case AppLifecycleState.detached:
        _usageTimer?.cancel();
        break;
    }
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(minutes: 5), (t) {
      if (_sessionStart == null || _longUsageSentThisSession) return;
      final activeFor = DateTime.now().difference(_sessionStart!);
      if (activeFor.inMinutes >= 30) {
        _longUsageSentThisSession = true;
        unawaited(NotificationService.instance.onLongUsage());
      }
    });
  }
}
