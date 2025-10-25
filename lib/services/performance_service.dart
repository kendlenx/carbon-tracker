import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// 🚀 Performance Service - App Performance Optimization
/// 
/// Features: Crash monitoring, performance metrics, memory optimization
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  static PerformanceService get instance => _instance;

  late FirebasePerformance _performance;
  late FirebaseCrashlytics _crashlytics;

  // Performance tracking
  final Map<String, Trace> _activeTraces = {};
  final List<String> _performanceLogs = [];

  /// Initialize performance monitoring
  Future<void> initialize() async {
    try {
      _performance = FirebasePerformance.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Enable crashlytics collection
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
      
      // Set up automatic crash reporting
      if (!kDebugMode) {
        FlutterError.onError = (errorDetails) {
          _crashlytics.recordFlutterFatalError(errorDetails);
        };
        
        PlatformDispatcher.instance.onError = (error, stack) {
          _crashlytics.recordError(error, stack, fatal: true);
          return true;
        };
      }

      // Track app start performance
      await _trackAppStartup();
      
      debugPrint('🚀 Performance Service initialized');
    } catch (e) {
      debugPrint('❌ Performance Service initialization failed: $e');
    }
  }

  /// Track app startup performance
  Future<void> _trackAppStartup() async {
    final trace = _performance.newTrace('app_startup');
    await trace.start();
    
    // This will be stopped when app is fully loaded
    _activeTraces['app_startup'] = trace;
  }

  /// Stop app startup tracking
  Future<void> stopAppStartupTracking() async {
    final trace = _activeTraces.remove('app_startup');
    if (trace != null) {
      await trace.stop();
      debugPrint('📊 App startup performance tracked');
    }
  }

  /// Start custom performance trace
  Future<void> startTrace(String name) async {
    try {
      final trace = _performance.newTrace(name);
      await trace.start();
      _activeTraces[name] = trace;
      debugPrint('📈 Started trace: $name');
    } catch (e) {
      debugPrint('❌ Failed to start trace $name: $e');
    }
  }

  /// Stop custom performance trace
  Future<void> stopTrace(String name, {Map<String, String>? attributes}) async {
    try {
      final trace = _activeTraces.remove(name);
      if (trace != null) {
        // Add custom attributes
        attributes?.forEach((key, value) {
          trace.putAttribute(key, value);
        });
        
        await trace.stop();
        debugPrint('📊 Stopped trace: $name');
      }
    } catch (e) {
      debugPrint('❌ Failed to stop trace $name: $e');
    }
  }

  /// Track network requests performance
  HttpMetric trackNetworkRequest({
    required String url,
    required HttpMethod httpMethod,
  }) {
    return _performance.newHttpMetric(url, httpMethod);
  }

  /// Log custom performance event
  void logPerformanceEvent(String event, {Map<String, dynamic>? parameters}) {
    final logEntry = 'Performance: $event - ${DateTime.now()}';
    _performanceLogs.add(logEntry);
    
    // Keep only last 100 logs to prevent memory issues
    if (_performanceLogs.length > 100) {
      _performanceLogs.removeAt(0);
    }
    
    debugPrint('📊 $logEntry');
  }

  /// Monitor memory usage
  void monitorMemoryUsage() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      // This is a simplified memory monitoring
      // In a real app, you'd use more sophisticated memory profiling
      logPerformanceEvent('Memory check', parameters: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// Record non-fatal error
  Future<void> recordNonFatalError(
    dynamic error, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? customData,
  }) async {
    try {
      // Set custom context
      if (context != null) {
        await _crashlytics.setCustomKey('error_context', context);
      }
      
      // Set custom data
      if (customData != null) {
        for (final entry in customData.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }
      
      await _crashlytics.recordError(error, stackTrace, fatal: false);
      debugPrint('🐛 Non-fatal error recorded: $error');
    } catch (e) {
      debugPrint('❌ Failed to record error: $e');
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('❌ Failed to set user ID: $e');
    }
  }

  /// Set custom user data for crash reports
  Future<void> setUserData({
    String? email,
    String? name,
    Map<String, dynamic>? customAttributes,
  }) async {
    try {
      if (email != null) {
        await _crashlytics.setCustomKey('user_email', email);
      }
      if (name != null) {
        await _crashlytics.setCustomKey('user_name', name);
      }
      if (customAttributes != null) {
        for (final entry in customAttributes.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to set user data: $e');
    }
  }

  /// Force a crash (for testing purposes only)
  void testCrash() {
    if (kDebugMode) {
      _crashlytics.crash();
    }
  }

  /// Get performance logs
  List<String> get performanceLogs => List.unmodifiable(_performanceLogs);

  /// Clear performance logs
  void clearPerformanceLogs() {
    _performanceLogs.clear();
  }
}

/// 🔧 Performance Helper - Utility functions for performance monitoring
class PerformanceHelper {
  /// Execute a function with performance tracking
  static Future<T> trackPerformance<T>({
    required String traceName,
    required Future<T> Function() function,
    Map<String, String>? attributes,
  }) async {
    final service = PerformanceService.instance;
    
    await service.startTrace(traceName);
    try {
      final result = await function();
      await service.stopTrace(traceName, attributes: attributes);
      return result;
    } catch (e) {
      await service.recordNonFatalError(e, StackTrace.current, 
        context: 'Performance tracking: $traceName');
      await service.stopTrace(traceName, attributes: {
        ...?attributes,
        'error': 'true',
      });
      rethrow;
    }
  }

  /// Track widget build performance
  static void trackWidgetBuild(String widgetName, Duration buildTime) {
    PerformanceService.instance.logPerformanceEvent(
      'Widget Build: $widgetName',
      parameters: {
        'build_time_ms': buildTime.inMilliseconds,
        'widget': widgetName,
      },
    );
  }

  /// Track database operation performance  
  static Future<T> trackDatabaseOperation<T>({
    required String operation,
    required Future<T> Function() function,
  }) async {
    return trackPerformance<T>(
      traceName: 'db_$operation',
      function: function,
      attributes: {'operation_type': 'database'},
    );
  }

  /// Track API call performance
  static Future<T> trackApiCall<T>({
    required String endpoint,
    required Future<T> Function() function,
  }) async {
    return trackPerformance<T>(
      traceName: 'api_call',
      function: function,
      attributes: {
        'endpoint': endpoint,
        'operation_type': 'network',
      },
    );
  }
}