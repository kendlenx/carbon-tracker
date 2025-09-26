import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

class ErrorInfo {
  final String message;
  final String? stackTrace;
  final ErrorSeverity severity;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final String? userId;

  ErrorInfo({
    required this.message,
    this.stackTrace,
    required this.severity,
    required this.context,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'stackTrace': stackTrace,
      'severity': severity.toString(),
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }
}

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  FirebaseCrashlytics? _crashlytics;
  FirebaseAnalytics? _analytics;
  FirebasePerformance? _performance;
  
  bool _initialized = false;
  String? _userId;
  Map<String, dynamic> _userContext = {};
  List<ErrorInfo> _errorHistory = [];
  
  // Performance traces
  final Map<String, Trace> _traces = {};

  /// Initialize the error handling service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _crashlytics = FirebaseCrashlytics.instance;
      _analytics = FirebaseAnalytics.instance;
      _performance = FirebasePerformance.instance;
      
      // Set up Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        recordError(
          details.exception,
          details.stack,
          fatal: false,
          context: {
            'widget': details.context?.toString(),
            'library': details.library,
          },
        );
      };
      
      // Set up Dart error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        recordError(
          error,
          stack,
          fatal: true,
          context: {'type': 'platform_error'},
        );
        return true;
      };
      
      // Set device and app context
      await _setDeviceContext();
      
      _initialized = true;
      log('Error handler service initialized successfully', LogLevel.info);
    } catch (e) {
      debugPrint('Failed to initialize error handler service: $e');
    }
  }

  /// Set user ID for crash reporting
  Future<void> setUserId(String userId) async {
    _userId = userId;
    await _crashlytics?.setUserIdentifier(userId);
    log('User ID set for crash reporting: $userId', LogLevel.info);
  }

  /// Set custom user context
  Future<void> setUserContext(Map<String, dynamic> context) async {
    _userContext = context;
    
    // Set custom keys in Crashlytics
    for (final entry in context.entries) {
      await _crashlytics?.setCustomKey(entry.key, entry.value);
    }
  }

  /// Record an error with context
  Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    bool fatal = false,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final errorInfo = ErrorInfo(
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
        severity: severity,
        context: {...context, ..._userContext},
        timestamp: DateTime.now(),
        userId: _userId,
      );
      
      _errorHistory.add(errorInfo);
      
      // Keep only last 100 errors in memory
      if (_errorHistory.length > 100) {
        _errorHistory.removeRange(0, _errorHistory.length - 100);
      }
      
      // Log to Crashlytics
      if (_crashlytics != null) {
        if (fatal) {
          await _crashlytics!.recordError(error, stackTrace, fatal: true);
        } else {
          await _crashlytics!.recordError(error, stackTrace);
        }
        
        // Set context for this error
        for (final entry in context.entries) {
          await _crashlytics!.setCustomKey(entry.key, entry.value);
        }
      }
      
      // Log to Analytics as a non-fatal event
      if (_analytics != null && !fatal) {
        await _analytics!.logEvent(
          name: 'app_error',
          parameters: {
            'error_message': error.toString().substring(0, 100), // Limit length
            'severity': severity.toString(),
            'fatal': fatal,
            'has_stack_trace': stackTrace != null,
          },
        );
      }
      
      log(
        'Error recorded: ${error.toString()}',
        fatal ? LogLevel.fatal : LogLevel.error,
        context: context,
      );
    } catch (e) {
      debugPrint('Failed to record error: $e');
    }
  }

  /// Log with different levels
  void log(
    String message,
    LogLevel level, {
    Map<String, dynamic> context = const {},
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context.isNotEmpty ? ' Context: $context' : '';
    
    if (kDebugMode) {
      debugPrint('[$timestamp] [${level.name.toUpperCase()}] $message$contextStr');
    }
    
    // Log to Crashlytics
    _crashlytics?.log('[$timestamp] [${level.name.toUpperCase()}] $message$contextStr');
    
    // Log important events to Analytics
    if (level == LogLevel.error || level == LogLevel.warning) {
      _analytics?.logEvent(
        name: 'app_log',
        parameters: {
          'level': level.name,
          'message': message.substring(0, 100), // Limit length
          'has_context': context.isNotEmpty,
        },
      );
    }
  }

  /// Start performance trace
  Future<void> startTrace(String traceName) async {
    try {
      if (_performance != null && !_traces.containsKey(traceName)) {
        final trace = _performance!.newTrace(traceName);
        await trace.start();
        _traces[traceName] = trace;
        log('Started performance trace: $traceName', LogLevel.debug);
      }
    } catch (e) {
      log('Failed to start trace $traceName: $e', LogLevel.warning);
    }
  }

  /// Stop performance trace
  Future<void> stopTrace(String traceName) async {
    try {
      final trace = _traces[traceName];
      if (trace != null) {
        await trace.stop();
        _traces.remove(traceName);
        log('Stopped performance trace: $traceName', LogLevel.debug);
      }
    } catch (e) {
      log('Failed to stop trace $traceName: $e', LogLevel.warning);
    }
  }

  /// Add metric to performance trace
  Future<void> putTraceMetric(String traceName, String metric, int value) async {
    try {
      final trace = _traces[traceName];
      if (trace != null) {
        trace.setMetric(metric, value);
        log('Added metric to trace $traceName: $metric = $value', LogLevel.debug);
      }
    } catch (e) {
      log('Failed to add metric to trace $traceName: $e', LogLevel.warning);
    }
  }

  /// Track screen view
  Future<void> trackScreenView(String screenName) async {
    try {
      await _analytics?.logScreenView(screenName: screenName);
      log('Screen view tracked: $screenName', LogLevel.debug);
    } catch (e) {
      log('Failed to track screen view $screenName: $e', LogLevel.warning);
    }
  }

  /// Track custom event
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic> parameters = const {},
  }) async {
    try {
      await _analytics?.logEvent(name: eventName, parameters: Map<String, Object>.from(parameters));
      log('Event tracked: $eventName with parameters: $parameters', LogLevel.debug);
    } catch (e) {
      log('Failed to track event $eventName: $e', LogLevel.warning);
    }
  }

  /// Get crash-free users percentage
  Future<void> setCrashFreeMetrics(bool crashFree) async {
    try {
      await _crashlytics?.setCustomKey('crash_free_session', crashFree);
      log('Crash-free metric set: $crashFree', LogLevel.info);
    } catch (e) {
      log('Failed to set crash-free metric: $e', LogLevel.warning);
    }
  }

  /// Get error history for debugging
  List<ErrorInfo> getErrorHistory() {
    return List.from(_errorHistory);
  }

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
    log('Error history cleared', LogLevel.info);
  }

  /// Force a crash for testing (Debug only)
  void forceCrash() {
    if (kDebugMode) {
      _crashlytics?.crash();
    }
  }

  /// Test non-fatal error
  void testNonFatalError() {
    if (kDebugMode) {
      recordError(
        'Test non-fatal error',
        StackTrace.current,
        fatal: false,
        severity: ErrorSeverity.low,
        context: {'test': true, 'timestamp': DateTime.now().toIso8601String()},
      );
    }
  }

  // Private helper methods

  Future<void> _setDeviceContext() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      Map<String, dynamic> context = {
        'app_version': packageInfo.version,
        'app_build': packageInfo.buildNumber,
        'package_name': packageInfo.packageName,
      };

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        context.addAll({
          'platform': 'android',
          'device_model': androidInfo.model,
          'device_brand': androidInfo.brand,
          'android_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        context.addAll({
          'platform': 'ios',
          'device_model': iosInfo.model,
          'device_name': iosInfo.name,
          'ios_version': iosInfo.systemVersion,
        });
      }

      await setUserContext(context);
      log('Device context set successfully', LogLevel.info);
    } catch (e) {
      log('Failed to set device context: $e', LogLevel.warning);
    }
  }

  /// Dispose resources
  void dispose() {
    // Stop all active traces
    for (final trace in _traces.values) {
      trace.stop();
    }
    _traces.clear();
    _initialized = false;
    log('Error handler service disposed', LogLevel.info);
  }
}