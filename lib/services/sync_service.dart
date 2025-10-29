import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'feedback_service.dart';
import 'widget_data_provider.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Offline → Auto sync service
class SyncService {
  SyncService._();
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _initialized = false;

  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        await _attemptSync();
        // Notify NotificationService that network is back
        unawaited(NotificationService.instance.onNetworkBackOnline());
      }
    });
  }

  Future<void> _attemptSync() async {
    try {
      // Submit any pending feedback stored locally
      await FeedbackService().submitPendingFeedback();
      // Refresh widgets after sync
      await WidgetDataProvider.instance.updateWidgetData();
      // Also refresh home widgets
      try {
        await WidgetService.instance.refreshAllWidgets();
      } catch (_) {}
      if (kDebugMode) {
        // ignore: avoid_print
        print('Background sync completed');
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _initialized = false;
  }
}
