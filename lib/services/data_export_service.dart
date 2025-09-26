import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';
import 'achievement_service.dart';
import 'language_service.dart';

enum ExportFormat {
  json,
  csv,
}

class DataExportService extends ChangeNotifier {
  static DataExportService? _instance;
  static DataExportService get instance => _instance ??= DataExportService._();
  
  DataExportService._();

  final LanguageService _languageService = LanguageService.instance;
  
  bool _isExporting = false;
  bool _isImporting = false;
  
  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;

  /// Export all user data to JSON format
  Future<Map<String, dynamic>> exportAllDataToJson() async {
    try {
      _isExporting = true;
      notifyListeners();

      // Get all data from database
      final allActivities = await DatabaseService.instance.getAllActivities();
      final transportActivities = await DatabaseService.instance.getAllTransportActivities();
      final dashboardStats = await DatabaseService.instance.getDashboardStats();
      
      // Get achievements data
      final achievements = AchievementService.instance.achievements;
      final achievementData = achievements.map((a) => a.toJson()).toList();
      
      // Create export data structure
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'appName': 'Carbon Tracker',
        'data': {
          'activities': allActivities,
          'transportActivities': transportActivities.map((activity) => activity.toJson()).toList(),
          'achievements': achievementData,
          'stats': dashboardStats,
        },
        'metadata': {
          'totalActivities': allActivities.length,
          'totalTransportActivities': transportActivities.length,
          'totalAchievements': achievements.where((a) => a.isUnlocked).length,
        }
      };

      return exportData;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Export activities to CSV format
  Future<String> exportActivitesToCSV() async {
    try {
      _isExporting = true;
      notifyListeners();

      final allActivities = await DatabaseService.instance.getAllActivities();
      final transportActivities = await DatabaseService.instance.getAllTransportActivities();
      
      final csvData = StringBuffer();
      
      // CSV Headers
      csvData.writeln('Date,Category,Subcategory,Description,CO2_Amount_kg,Notes');
      
      // Add general activities
      for (final activity in allActivities) {
        final date = DateTime.parse(activity['created_at']);
        final dateStr = '${date.day}/${date.month}/${date.year}';
        final category = activity['category'] ?? '';
        final subcategory = activity['subcategory'] ?? '';
        final description = _escapeCSV(activity['description'] ?? '');
        final co2Amount = activity['co2_amount'] ?? 0.0;
        final notes = _escapeCSV(activity['notes'] ?? '');
        
        csvData.writeln('$dateStr,$category,$subcategory,$description,$co2Amount,$notes');
      }
      
      // Add transport activities
      for (final activity in transportActivities) {
        final dateStr = '${activity.timestamp.day}/${activity.timestamp.month}/${activity.timestamp.year}';
        final description = _escapeCSV('${activity.typeDisplayName} - ${activity.distanceKm} km');
        final notes = _escapeCSV(activity.notes ?? '');
        
        csvData.writeln('$dateStr,transport,${activity.type.name},$description,${activity.co2EmissionKg},$notes');
      }
      
      return csvData.toString();
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Helper to escape CSV values
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Save data to file and share
  Future<void> exportAndShare(ExportFormat format) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception(_languageService.isEnglish 
              ? 'Storage permission required for export' 
              : 'Dışa aktarma için depolama izni gerekli');
        }
      }

      String content;
      String fileName;
      String mimeType;

      if (format == ExportFormat.json) {
        final jsonData = await exportAllDataToJson();
        content = const JsonEncoder.withIndent('  ').convert(jsonData);
        fileName = 'carbon_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        mimeType = 'application/json';
      } else {
        content = await exportActivitesToCSV();
        fileName = 'carbon_tracker_activities_${DateTime.now().millisecondsSinceEpoch}.csv';
        mimeType = 'text/csv';
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      
      // Write content to file
      await file.writeAsString(content, encoding: utf8);
      
      // Share the file
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: _languageService.isEnglish 
            ? 'Carbon Tracker Data Export' 
            : 'Carbon Tracker Veri Dışa Aktarımı',
      );
      
      if (result.status == ShareResultStatus.success) {
        debugPrint('Export shared successfully');
      }
      
    } catch (e) {
      debugPrint('Error in exportAndShare: $e');
      rethrow;
    }
  }

  /// Import data from JSON file
  Future<void> importFromJson(String jsonContent) async {
    try {
      _isImporting = true;
      notifyListeners();

      final Map<String, dynamic> importData = json.decode(jsonContent);
      
      // Validate data structure
      if (!importData.containsKey('data') || !importData.containsKey('version')) {
        throw Exception(_languageService.isEnglish 
            ? 'Invalid backup file format' 
            : 'Geçersiz yedek dosya formatı');
      }

      final data = importData['data'] as Map<String, dynamic>;
      
      // Import activities
      if (data.containsKey('activities')) {
        final activities = data['activities'] as List;
        for (final activity in activities) {
          try {
            await DatabaseService.instance.insertActivity(activity as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error importing activity: $e');
            // Continue with next activity
          }
        }
      }

      // Import achievements (restore progress)
      if (data.containsKey('achievements')) {
        final achievements = data['achievements'] as List;
        // This would require extending AchievementService with import functionality
        debugPrint('Achievement import not fully implemented yet');
      }

      debugPrint('Data import completed successfully');
      
    } catch (e) {
      debugPrint('Error importing data: $e');
      rethrow;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Pick and import backup file
  Future<void> pickAndImportBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path != null) {
          final fileContent = await File(file.path!).readAsString();
          await importFromJson(fileContent);
        } else if (file.bytes != null) {
          // For web platform
          final fileContent = utf8.decode(file.bytes!);
          await importFromJson(fileContent);
        }
      }
    } catch (e) {
      debugPrint('Error picking/importing file: $e');
      rethrow;
    }
  }

  /// Get export statistics
  Future<Map<String, dynamic>> getExportStatistics() async {
    try {
      final allActivities = await DatabaseService.instance.getAllActivities();
      final transportActivities = await DatabaseService.instance.getAllTransportActivities();
      final achievements = AchievementService.instance.achievements;
      
      final totalCO2 = allActivities.fold(0.0, (sum, activity) {
        return sum + (activity['co2_amount'] as double? ?? 0.0);
      });
      
      final transportCO2 = transportActivities.fold(0.0, (sum, activity) {
        return sum + activity.co2EmissionKg;
      });

      return {
        'totalActivities': allActivities.length,
        'totalTransportActivities': transportActivities.length,
        'unlockedAchievements': achievements.where((a) => a.isUnlocked).length,
        'totalAchievements': achievements.length,
        'totalCO2Recorded': totalCO2 + transportCO2,
        'oldestActivity': allActivities.isNotEmpty ? allActivities.last['created_at'] : null,
        'newestActivity': allActivities.isNotEmpty ? allActivities.first['created_at'] : null,
      };
    } catch (e) {
      debugPrint('Error getting export statistics: $e');
      return {};
    }
  }

  /// Clear all data (for testing or reset purposes)
  Future<void> clearAllData() async {
    try {
      await DatabaseService.instance.clearAllData();
      // Reset achievements would need to be implemented in AchievementService
      debugPrint('All data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }
}