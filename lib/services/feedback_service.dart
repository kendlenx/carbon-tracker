import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'error_handler_service.dart';

enum FeedbackType {
  bug,
  feature,
  general,
  performance,
}

class FeedbackData {
  final FeedbackType type;
  final String message;
  final String? email;
  final int? rating;
  final bool includeScreenshot;
  final bool includeErrorLogs;
  final String? screenshotPath;
  final String? systemInfo;
  final String? crashContext;
  final String? errorMessage;
  final DateTime timestamp;

  FeedbackData({
    required this.type,
    required this.message,
    this.email,
    this.rating,
    this.includeScreenshot = false,
    this.includeErrorLogs = false,
    this.screenshotPath,
    this.systemInfo,
    this.crashContext,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'message': message,
      'email': email,
      'rating': rating,
      'includeScreenshot': includeScreenshot,
      'includeErrorLogs': includeErrorLogs,
      'systemInfo': systemInfo,
      'crashContext': crashContext,
      'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
      'status': 'submitted',
    };
  }
}

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  /// Initialize the feedback service
  Future<void> initialize() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      ErrorHandlerService().log('Feedback service initialized', LogLevel.info);
    } catch (e) {
      ErrorHandlerService().log(
        'Failed to initialize feedback service: $e',
        LogLevel.warning,
      );
    }
  }

  /// Submit feedback to Firebase
  Future<void> submitFeedback(FeedbackData feedback) async {
    try {
      String? screenshotUrl;
      
      // Upload screenshot if included
      if (feedback.includeScreenshot && feedback.screenshotPath != null) {
        screenshotUrl = await _uploadScreenshot(feedback.screenshotPath!);
      }
      
      // Get error logs if requested
      String? errorLogs;
      if (feedback.includeErrorLogs) {
        errorLogs = await _getErrorLogs();
      }
      
      // Create feedback document
      final feedbackDoc = {
        ...feedback.toMap(),
        'screenshotUrl': screenshotUrl,
        'errorLogs': errorLogs,
        'deviceId': await _getDeviceId(),
        'userId': await _getUserId(),
      };
      
      // Submit to Firestore
      await _firestore?.collection('feedback').add(feedbackDoc);
      
      // Track feedback submission
      ErrorHandlerService().trackEvent('feedback_submitted', parameters: {
        'feedback_type': feedback.type.toString(),
        'has_screenshot': feedback.includeScreenshot,
        'has_error_logs': feedback.includeErrorLogs,
        'has_rating': feedback.rating != null,
        'message_length': feedback.message.length,
      });
      
      // Save locally for offline submission if needed
      await _saveFeedbackLocally(feedbackDoc);
      
      ErrorHandlerService().log(
        'Feedback submitted successfully: ${feedback.type}',
        LogLevel.info,
        context: {
          'feedback_id': 'firestore_generated',
          'type': feedback.type.toString(),
        },
      );
      
    } catch (e) {
      // Save for later submission if network fails
      await _saveFeedbackLocally(feedback.toMap());
      
      ErrorHandlerService().recordError(
        e,
        StackTrace.current,
        severity: ErrorSeverity.medium,
        context: {
          'feedback_type': feedback.type.toString(),
          'operation': 'submit_feedback',
        },
      );
      
      throw Exception('Failed to submit feedback: $e');
    }
  }

  /// Upload screenshot to Firebase Storage
  Future<String> _uploadScreenshot(String screenshotPath) async {
    try {
      final file = File(screenshotPath);
      if (!await file.exists()) {
        throw Exception('Screenshot file not found');
      }
      
      final fileName = 'feedback_screenshots/${DateTime.now().millisecondsSinceEpoch}.png';
      final reference = _storage?.ref().child(fileName);
      
      final uploadTask = reference?.putFile(file);
      final snapshot = await uploadTask?.whenComplete(() {});
      
      final downloadUrl = await snapshot?.ref.getDownloadURL();
      
      if (downloadUrl != null) {
        ErrorHandlerService().log(
          'Screenshot uploaded successfully',
          LogLevel.debug,
          context: {'screenshot_url': downloadUrl},
        );
        return downloadUrl;
      } else {
        throw Exception('Failed to get download URL');
      }
    } catch (e) {
      ErrorHandlerService().log(
        'Failed to upload screenshot: $e',
        LogLevel.warning,
      );
      rethrow;
    }
  }

  /// Get error logs for feedback
  Future<String> _getErrorLogs() async {
    try {
      final errorHistory = ErrorHandlerService().getErrorHistory();
      final recentErrors = errorHistory.take(10).toList();
      
      if (recentErrors.isEmpty) {
        return 'No recent errors found.';
      }
      
      final logsBuffer = StringBuffer();
      logsBuffer.writeln('Recent Error Logs:');
      logsBuffer.writeln('==================');
      
      for (final error in recentErrors) {
        logsBuffer.writeln('Timestamp: ${error.timestamp}');
        logsBuffer.writeln('Severity: ${error.severity}');
        logsBuffer.writeln('Message: ${error.message}');
        if (error.stackTrace != null) {
          logsBuffer.writeln('Stack Trace:');
          logsBuffer.writeln(error.stackTrace);
        }
        logsBuffer.writeln('Context: ${error.context}');
        logsBuffer.writeln('---');
      }
      
      return logsBuffer.toString();
    } catch (e) {
      return 'Failed to retrieve error logs: $e';
    }
  }

  /// Get device ID for feedback tracking
  Future<String> _getDeviceId() async {
    try {
      String? deviceId = await _secureStorage.read(key: 'device_id');
      if (deviceId == null) {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        await _secureStorage.write(key: 'device_id', value: deviceId);
      }
      return deviceId;
    } catch (e) {
      return 'unknown_device';
    }
  }

  /// Get user ID if available
  Future<String?> _getUserId() async {
    try {
      return await _secureStorage.read(key: 'user_id');
    } catch (e) {
      return null;
    }
  }

  /// Save feedback locally for offline submission
  Future<void> _saveFeedbackLocally(Map<String, dynamic> feedbackData) async {
    try {
      final existingFeedback = await _secureStorage.read(key: 'pending_feedback');
      List<Map<String, dynamic>> feedbackList = [];
      
      if (existingFeedback != null) {
        final decoded = jsonDecode(existingFeedback) as List;
        feedbackList = decoded.cast<Map<String, dynamic>>();
      }
      
      feedbackList.add({
        ...feedbackData,
        'submitted_locally': true,
        'local_timestamp': DateTime.now().toIso8601String(),
      });
      
      // Keep only last 10 feedback items
      if (feedbackList.length > 10) {
        feedbackList = feedbackList.sublist(feedbackList.length - 10);
      }
      
      await _secureStorage.write(
        key: 'pending_feedback',
        value: jsonEncode(feedbackList),
      );
      
      ErrorHandlerService().log(
        'Feedback saved locally for later submission',
        LogLevel.info,
      );
    } catch (e) {
      ErrorHandlerService().log(
        'Failed to save feedback locally: $e',
        LogLevel.warning,
      );
    }
  }

  /// Submit pending feedback when connection is restored
  Future<void> submitPendingFeedback() async {
    try {
      final pendingFeedback = await _secureStorage.read(key: 'pending_feedback');
      if (pendingFeedback == null) return;
      
      final feedbackList = jsonDecode(pendingFeedback) as List;
      final List<Map<String, dynamic>> remainingFeedback = [];
      
      for (final feedbackData in feedbackList) {
        try {
          await _firestore?.collection('feedback').add(feedbackData);
          ErrorHandlerService().log(
            'Pending feedback submitted successfully',
            LogLevel.info,
          );
        } catch (e) {
          // Keep failed submissions for later
          remainingFeedback.add(feedbackData);
          ErrorHandlerService().log(
            'Failed to submit pending feedback: $e',
            LogLevel.warning,
          );
        }
      }
      
      // Update stored pending feedback
      if (remainingFeedback.isEmpty) {
        await _secureStorage.delete(key: 'pending_feedback');
      } else {
        await _secureStorage.write(
          key: 'pending_feedback',
          value: jsonEncode(remainingFeedback),
        );
      }
    } catch (e) {
      ErrorHandlerService().log(
        'Error processing pending feedback: $e',
        LogLevel.warning,
      );
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final pendingFeedback = await _secureStorage.read(key: 'pending_feedback');
      int pendingCount = 0;
      
      if (pendingFeedback != null) {
        final feedbackList = jsonDecode(pendingFeedback) as List;
        pendingCount = feedbackList.length;
      }
      
      return {
        'pending_feedback_count': pendingCount,
        'last_feedback_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'pending_feedback_count': 0,
        'error': e.toString(),
      };
    }
  }

  /// Clear all local feedback data
  Future<void> clearLocalFeedback() async {
    try {
      await _secureStorage.delete(key: 'pending_feedback');
      ErrorHandlerService().log('Local feedback data cleared', LogLevel.info);
    } catch (e) {
      ErrorHandlerService().log(
        'Failed to clear local feedback data: $e',
        LogLevel.warning,
      );
    }
  }
}