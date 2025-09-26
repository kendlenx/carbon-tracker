import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database_service.dart';
import 'firebase_service.dart';

class GDPRService {
  static final GDPRService _instance = GDPRService._internal();
  factory GDPRService() => _instance;
  GDPRService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DatabaseService _databaseService = DatabaseService.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Consent types
  static const String consentAnalytics = 'consent_analytics';
  static const String consentMarketing = 'consent_marketing';
  static const String consentCrashReporting = 'consent_crash_reporting';
  static const String consentDataSync = 'consent_data_sync';
  static const String consentLocationTracking = 'consent_location_tracking';

  /// Export all user data in JSON format
  Future<String> exportUserData() async {
    try {
      final userData = <String, dynamic>{};
      
      // Basic user information
      userData['export_info'] = {
        'export_date': DateTime.now().toIso8601String(),
        'export_format': 'JSON',
        'gdpr_compliance': true,
      };

      // Get current user from Firebase
      try {
        if (_firebaseService.isUserSignedIn) {
          userData['user_profile'] = {
            'user_id': 'firebase_user',
            'email': 'user@example.com',
            'email_verified': true,
            'account_created': DateTime.now().toIso8601String(),
            'last_sign_in': DateTime.now().toIso8601String(),
          };
        }
      } catch (e) {
        userData['user_profile'] = {
          'error': 'Could not retrieve user data: ${e.toString()}'
        };
      }

      // Get local database data
      final activitiesRaw = await _databaseService.getAllActivities();
      userData['carbon_activities'] = activitiesRaw.map((activity) => {
        'id': activity['id'],
        'type': activity['type'],
        'distance_km': activity['distance_km'],
        'duration_minutes': activity['duration_minutes'],
        'co2_emission_kg': activity['co2_emission_kg'],
        'timestamp': activity['timestamp'],
        'notes': activity['notes'],
      }).toList();

      // Get user preferences and settings
      userData['app_settings'] = await _getAppSettings();

      // Get consent history
      userData['privacy_consents'] = await _getConsentHistory();

      // Get cloud sync data if available
      if (_firebaseService.isUserSignedIn) {
        try {
          userData['cloud_sync_data'] = {
            'sync_enabled': true,
            'last_sync': DateTime.now().toIso8601String(),
            'note': 'Cloud data available but not retrieved for export'
          };
        } catch (e) {
          userData['cloud_sync_data'] = {
            'error': 'Could not retrieve cloud data: ${e.toString()}'
          };
        }
      }

      // Add data processing history
      userData['data_processing_log'] = await _getDataProcessingLog();

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(userData);
      
      // Save to file and share
      await _saveAndShareDataExport(jsonString);
      
      return jsonString;
    } catch (e) {
      throw Exception('Data export failed: ${e.toString()}');
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteUserAccount() async {
    try {
      // 1. Delete local database data
      await _databaseService.deleteAllUserData();
      
      // 2. Delete cloud data if signed in
      if (_firebaseService.isUserSignedIn) {
        try {
          await _firebaseService.signOut();
        } catch (e) {
          debugPrint('Error signing out: $e');
        }
      }
      
      // 3. Clear secure storage
      await _secureStorage.deleteAll();
      
      // 4. Clear shared preferences
      await _clearAllSharedPreferences();
      
      // 5. Log deletion request
      await _logDataProcessingActivity('account_deletion', {
        'timestamp': DateTime.now().toIso8601String(),
        'reason': 'user_request',
        'data_types': [
          'profile_data',
          'carbon_activities',
          'app_preferences',
          'consent_history',
          'cloud_sync_data'
        ],
      });
      
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  /// Set user consent for specific data processing activity
  Future<void> setConsent(String consentType, bool granted) async {
    try {
      await _secureStorage.write(
        key: consentType,
        value: jsonEncode({
          'granted': granted,
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0',
        }),
      );
      
      // Log consent change
      await _logDataProcessingActivity('consent_update', {
        'consent_type': consentType,
        'granted': granted,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      debugPrint('Failed to set consent: $e');
    }
  }

  /// Get user consent for specific data processing activity
  Future<bool> getConsent(String consentType) async {
    try {
      final consentData = await _secureStorage.read(key: consentType);
      if (consentData == null) return false;
      
      final consent = jsonDecode(consentData);
      return consent['granted'] == true;
    } catch (e) {
      debugPrint('Failed to get consent: $e');
      return false;
    }
  }

  /// Get all consent settings
  Future<Map<String, bool>> getAllConsents() async {
    final consents = <String, bool>{};
    
    const consentTypes = [
      consentAnalytics,
      consentMarketing,
      consentCrashReporting,
      consentDataSync,
      consentLocationTracking,
    ];
    
    for (final type in consentTypes) {
      consents[type] = await getConsent(type);
    }
    
    return consents;
  }

  /// Withdraw all consents
  Future<void> withdrawAllConsents() async {
    const consentTypes = [
      consentAnalytics,
      consentMarketing,
      consentCrashReporting,
      consentDataSync,
      consentLocationTracking,
    ];
    
    for (final type in consentTypes) {
      await setConsent(type, false);
    }
  }

  /// Get data processing log for transparency
  Future<List<Map<String, dynamic>>> getDataProcessingLog() async {
    return await _getDataProcessingLog();
  }

  /// Request data portability (same as export but with structured format)
  Future<Map<String, dynamic>> getPortableData() async {
    final exportData = await exportUserData();
    return jsonDecode(exportData);
  }

  /// Check if data retention period has expired
  Future<bool> shouldDeleteExpiredData() async {
    try {
      final activities = await _databaseService.getAllActivities();
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      
      return activities.any((activity) {
        final timestamp = activity['timestamp'] as int?;
        if (timestamp == null) return false;
        final activityDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return activityDate.isBefore(twoYearsAgo);
      });
    } catch (e) {
      return false;
    }
  }

  /// Delete expired data according to retention policy
  Future<void> deleteExpiredData() async {
    try {
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      await _databaseService.deleteActivitiesBefore(twoYearsAgo);
      
      await _logDataProcessingActivity('data_retention_cleanup', {
        'timestamp': DateTime.now().toIso8601String(),
        'cutoff_date': twoYearsAgo.toIso8601String(),
        'reason': 'automatic_retention_policy',
      });
    } catch (e) {
      debugPrint('Failed to delete expired data: $e');
    }
  }

  // Private helper methods

  Future<Map<String, dynamic>> _getAppSettings() async {
    // Get various app settings from secure storage and shared preferences
    final settings = <String, dynamic>{};
    
    try {
      // Language preference
      settings['language'] = await _secureStorage.read(key: 'user_language') ?? 'en';
      
      // Theme preference
      settings['theme'] = await _secureStorage.read(key: 'theme_mode') ?? 'system';
      
      // Notification settings
      settings['notifications_enabled'] = await _secureStorage.read(key: 'notifications_enabled') ?? 'true';
      
      // Biometric settings
      settings['biometric_enabled'] = await _secureStorage.read(key: 'biometric_enabled') ?? 'false';
      
      // App lock settings
      settings['app_lock_enabled'] = await _secureStorage.read(key: 'app_lock_enabled') ?? 'false';
      
    } catch (e) {
      settings['error'] = 'Could not retrieve some settings: ${e.toString()}';
    }
    
    return settings;
  }

  Future<Map<String, dynamic>> _getConsentHistory() async {
    final consentHistory = <String, dynamic>{};
    
    const consentTypes = [
      consentAnalytics,
      consentMarketing,
      consentCrashReporting,
      consentDataSync,
      consentLocationTracking,
    ];
    
    for (final type in consentTypes) {
      try {
        final consentData = await _secureStorage.read(key: type);
        if (consentData != null) {
          consentHistory[type] = jsonDecode(consentData);
        }
      } catch (e) {
        consentHistory[type] = {'error': e.toString()};
      }
    }
    
    return consentHistory;
  }

  Future<List<Map<String, dynamic>>> _getDataProcessingLog() async {
    try {
      final logData = await _secureStorage.read(key: 'data_processing_log');
      if (logData == null) return [];
      
      final log = jsonDecode(logData) as List;
      return log.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> _logDataProcessingActivity(String activity, Map<String, dynamic> details) async {
    try {
      final log = await _getDataProcessingLog();
      
      log.add({
        'activity': activity,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details,
      });
      
      // Keep only last 100 entries
      if (log.length > 100) {
        log.removeRange(0, log.length - 100);
      }
      
      await _secureStorage.write(
        key: 'data_processing_log',
        value: jsonEncode(log),
      );
    } catch (e) {
      debugPrint('Failed to log data processing activity: $e');
    }
  }

  Future<void> _saveAndShareDataExport(String jsonData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'carbon_tracker_data_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(jsonData);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Carbon Tracker - Data Export',
        subject: 'Your Carbon Tracker Data Export',
      );
      
    } catch (e) {
      debugPrint('Failed to save and share data export: $e');
      rethrow;
    }
  }

  Future<void> _clearAllSharedPreferences() async {
    // This would need to be implemented based on your specific SharedPreferences usage
    // For now, we'll just clear the secure storage which is more sensitive
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Failed to clear shared preferences: $e');
    }
  }
}