import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'firebase_service.dart';
import 'security_service.dart';
import 'admob_service.dart';
import 'performance_service.dart';

/// Runs heavy initializations in the background without blocking first frame
class BackgroundInitService {
  BackgroundInitService._();

  static void start({
    required SecurityService securityService,
    required FirebaseService firebaseService,
  }) {
    // Defer to after first frame to avoid jank during initial build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Security can be independent
      unawaited(_initSecurity(securityService));
      // Chain Performance after Firebase to avoid [core/no-app]
      unawaited(_initFirebaseThenPerformance(firebaseService));
      // Stagger AdMob a bit to reduce network contention on cold start
      unawaited(_initAdMobDelayed());
    });
  }

  static Future<void> _initSecurity(SecurityService securityService) async {
    try {
      await securityService.initializeSecurity();
    } catch (e) {
      debugPrint('Background security init failed: $e');
    }
  }

  static Future<void> _initFirebaseThenPerformance(FirebaseService firebaseService) async {
    try {
      await firebaseService.initialize();
      try {
        await PerformanceService.instance.initialize();
      } catch (e) {
        debugPrint('Background Performance init failed: $e');
      }
    } catch (e) {
      debugPrint('Background Firebase init failed: $e');
    }
  }

  static Future<void> _initAdMobDelayed() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      await AdMobService.instance.initialize();
    } catch (e) {
      debugPrint('Background AdMob init failed: $e');
    }
  }
}
