import 'package:flutter/material.dart';
import '../services/error_handler_service.dart';

/// Mixin for monitoring performance of screens and widgets
mixin PerformanceMonitoringMixin<T extends StatefulWidget> on State<T> {
  String get screenName => T.toString();
  
  late DateTime _screenLoadStart;
  late DateTime _screenLoadEnd;
  String? _currentTrace;

  @override
  void initState() {
    super.initState();
    _screenLoadStart = DateTime.now();
    _startPerformanceTrace();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onScreenReady();
  }

  @override
  void dispose() {
    _stopPerformanceTrace();
    super.dispose();
  }

  /// Start performance trace for this screen
  void _startPerformanceTrace() {
    _currentTrace = '${screenName}_load';
    ErrorHandlerService().startTrace(_currentTrace!);
    
    // Track screen view
    ErrorHandlerService().trackScreenView(screenName);
    
    ErrorHandlerService().log(
      'Screen load started: $screenName',
      LogLevel.debug,
      context: {'screen': screenName, 'start_time': _screenLoadStart.toIso8601String()},
    );
  }

  /// Called when screen is ready (after dependencies are resolved)
  void _onScreenReady() {
    _screenLoadEnd = DateTime.now();
    final loadTime = _screenLoadEnd.difference(_screenLoadStart).inMilliseconds;
    
    if (_currentTrace != null) {
      ErrorHandlerService().putTraceMetric(_currentTrace!, 'load_time_ms', loadTime);
    }
    
    // Track performance metrics
    ErrorHandlerService().trackEvent('screen_performance', parameters: {
      'screen_name': screenName,
      'load_time_ms': loadTime,
      'is_slow': loadTime > 3000, // Flag if load time > 3 seconds
    });
    
    ErrorHandlerService().log(
      'Screen loaded: $screenName (${loadTime}ms)',
      loadTime > 3000 ? LogLevel.warning : LogLevel.debug,
      context: {
        'screen': screenName,
        'load_time_ms': loadTime,
        'performance_category': _getPerformanceCategory(loadTime),
      },
    );
  }

  /// Stop performance trace
  void _stopPerformanceTrace() {
    if (_currentTrace != null) {
      final sessionTime = DateTime.now().difference(_screenLoadStart).inMilliseconds;
      ErrorHandlerService().putTraceMetric(_currentTrace!, 'session_time_ms', sessionTime);
      ErrorHandlerService().stopTrace(_currentTrace!);
      
      ErrorHandlerService().log(
        'Screen session ended: $screenName (${sessionTime}ms)',
        LogLevel.debug,
        context: {'screen': screenName, 'session_time_ms': sessionTime},
      );
    }
  }

  /// Track custom performance event
  void trackPerformanceEvent(String eventName, {
    Map<String, dynamic> parameters = const {},
    int? duration,
  }) {
    final eventParameters = {
      'screen_name': screenName,
      ...parameters,
      if (duration != null) 'duration_ms': duration,
    };

    ErrorHandlerService().trackEvent(eventName, parameters: eventParameters);
    
    ErrorHandlerService().log(
      'Performance event: $eventName on $screenName',
      LogLevel.debug,
      context: eventParameters,
    );
  }

  /// Track async operation performance
  Future<T> trackAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final startTime = DateTime.now();
    final traceName = '${screenName}_$operationName';
    
    await ErrorHandlerService().startTrace(traceName);
    
    try {
      final result = await operation();
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      await ErrorHandlerService().putTraceMetric(traceName, 'duration_ms', duration);
      
      trackPerformanceEvent('async_operation_success', parameters: {
        'operation': operationName,
        'duration_ms': duration,
      });
      
      return result;
    } catch (error, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      ErrorHandlerService().recordError(
        error,
        stackTrace,
        severity: ErrorSeverity.medium,
        context: {
          'screen': screenName,
          'operation': operationName,
          'duration_ms': duration,
        },
      );
      
      trackPerformanceEvent('async_operation_error', parameters: {
        'operation': operationName,
        'duration_ms': duration,
        'error': error.toString(),
      });
      
      rethrow;
    } finally {
      await ErrorHandlerService().stopTrace(traceName);
    }
  }

  /// Track widget build performance
  Widget trackWidgetBuild(String widgetName, Widget Function() builder) {
    final startTime = DateTime.now();
    
    try {
      final widget = builder();
      
      final buildTime = DateTime.now().difference(startTime).inMilliseconds;
      
      if (buildTime > 100) { // Log slow builds
        ErrorHandlerService().log(
          'Slow widget build: $widgetName on $screenName (${buildTime}ms)',
          LogLevel.warning,
          context: {
            'widget_name': widgetName,
            'screen_name': screenName,
            'build_time_ms': buildTime,
          },
        );
      }
      
      return widget;
    } catch (error, stackTrace) {
      ErrorHandlerService().recordError(
        error,
        stackTrace,
        severity: ErrorSeverity.high,
        context: {
          'widget_name': widgetName,
          'screen_name': screenName,
          'build_error': true,
        },
      );
      
      // Return error widget
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.red.withOpacity(0.1),
        child: Text(
          'Error building $widgetName',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  /// Get performance category based on load time
  String _getPerformanceCategory(int loadTimeMs) {
    if (loadTimeMs < 1000) return 'excellent';
    if (loadTimeMs < 2000) return 'good';
    if (loadTimeMs < 3000) return 'fair';
    return 'poor';
  }

  /// Track user interaction performance
  void trackUserInteraction(String interaction, {
    Map<String, dynamic> context = const {},
  }) {
    trackPerformanceEvent('user_interaction', parameters: {
      'interaction_type': interaction,
      'timestamp': DateTime.now().toIso8601String(),
      ...context,
    });
  }

  /// Track memory usage (approximation)
  void trackMemoryUsage() {
    // This is an approximation - actual memory tracking would need platform channels
    trackPerformanceEvent('memory_check', parameters: {
      'timestamp': DateTime.now().toIso8601String(),
      'screen_widgets': 'tracked', // Could count widgets if needed
    });
  }
}

/// Performance wrapper widget
class PerformanceTracker extends StatefulWidget {
  final Widget child;
  final String name;
  final bool trackBuildTime;
  final Function(int buildTimeMs)? onSlowBuild;

  const PerformanceTracker({
    super.key,
    required this.child,
    required this.name,
    this.trackBuildTime = true,
    this.onSlowBuild,
  });

  @override
  State<PerformanceTracker> createState() => _PerformanceTrackerState();
}

class _PerformanceTrackerState extends State<PerformanceTracker> {
  DateTime? _buildStart;

  @override
  Widget build(BuildContext context) {
    if (widget.trackBuildTime) {
      _buildStart = DateTime.now();
    }

    return widget.child;
  }

  @override
  void didUpdateWidget(PerformanceTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.trackBuildTime && _buildStart != null) {
      final buildTime = DateTime.now().difference(_buildStart!).inMilliseconds;
      
      if (buildTime > 100) { // Slow build threshold
        ErrorHandlerService().log(
          'Slow widget rebuild: ${widget.name} (${buildTime}ms)',
          LogLevel.warning,
          context: {'widget_name': widget.name, 'build_time_ms': buildTime},
        );
        
        widget.onSlowBuild?.call(buildTime);
      }
    }
  }
}