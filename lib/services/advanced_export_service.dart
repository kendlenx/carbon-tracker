import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'error_handler_service.dart';
import '../models/transport_activity.dart';

enum ExportFormat {
  json,
  csv,
  excel,
}

enum ExportScope {
  all,
  dateRange,
  category,
  lastMonth,
  lastWeek,
  thisYear,
}

class ExportFilter {
  final ExportScope scope;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TransportType>? categories;
  final double? minCO2;
  final double? maxCO2;
  final bool includeSystemData;
  final bool includeUserPreferences;

  ExportFilter({
    this.scope = ExportScope.all,
    this.startDate,
    this.endDate,
    this.categories,
    this.minCO2,
    this.maxCO2,
    this.includeSystemData = false,
    this.includeUserPreferences = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'scope': scope.toString(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'categories': categories?.map((c) => c.toString()).toList(),
      'minCO2': minCO2,
      'maxCO2': maxCO2,
      'includeSystemData': includeSystemData,
      'includeUserPreferences': includeUserPreferences,
    };
  }
}

class ExportResult {
  final String filePath;
  final String fileName;
  final ExportFormat format;
  final int totalRecords;
  final double fileSizeBytes;
  final DateTime exportDate;
  final ExportFilter filter;

  ExportResult({
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.totalRecords,
    required this.fileSizeBytes,
    required this.exportDate,
    required this.filter,
  });

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'format': format.toString(),
      'totalRecords': totalRecords,
      'fileSizeBytes': fileSizeBytes,
      'exportDate': exportDate.toIso8601String(),
      'filter': filter.toMap(),
    };
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes.toInt()} B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AdvancedExportService {
  static final AdvancedExportService _instance = AdvancedExportService._internal();
  factory AdvancedExportService() => _instance;
  AdvancedExportService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Export data with advanced filtering and formatting options
  Future<ExportResult> exportData({
    required ExportFormat format,
    required ExportFilter filter,
    String? customFileName,
    Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      
      // Get filtered data
      final activities = await _getFilteredActivities(filter);
      onProgress?.call(0.3);
      
      // Generate export data
      final exportData = await _generateExportData(activities, filter);
      onProgress?.call(0.5);
      
      // Create file
      final file = await _createExportFile(
        data: exportData,
        format: format,
        customFileName: customFileName,
        activities: activities,
      );
      onProgress?.call(0.8);
      
      // Get file stats
      final fileStats = await file.stat();
      onProgress?.call(1.0);
      
      final result = ExportResult(
        filePath: file.path,
        fileName: file.path.split('/').last,
        format: format,
        totalRecords: activities.length,
        fileSizeBytes: fileStats.size.toDouble(),
        exportDate: DateTime.now(),
        filter: filter,
      );
      
      // Log export event
      _errorHandler.trackEvent('data_export_completed', parameters: {
        'format': format.toString(),
        'total_records': activities.length,
        'file_size': result.formattedFileSize,
        'scope': filter.scope.toString(),
      });
      
      _errorHandler.log(
        'Data export completed: ${result.fileName}',
        LogLevel.info,
        context: result.toMap(),
      );
      
      return result;
      
    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.high,
        context: {
          'operation': 'data_export',
          'format': format.toString(),
          'filter': filter.toMap(),
        },
      );
      rethrow;
    }
  }

  /// Get activities based on filter criteria
  Future<List<TransportActivity>> _getFilteredActivities(ExportFilter filter) async {
    List<TransportActivity> activities;
    
    switch (filter.scope) {
      case ExportScope.all:
        activities = await _databaseService.getAllTransportActivities();
        break;
        
      case ExportScope.dateRange:
        if (filter.startDate != null && filter.endDate != null) {
          activities = await _databaseService.getTransportActivities(
            startDate: filter.startDate,
            endDate: filter.endDate,
          );
        } else {
          activities = await _databaseService.getAllTransportActivities();
        }
        break;
        
      case ExportScope.lastWeek:
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        activities = await _databaseService.getTransportActivities(
          startDate: weekAgo,
          endDate: DateTime.now(),
        );
        break;
        
      case ExportScope.lastMonth:
        final monthAgo = DateTime.now().subtract(const Duration(days: 30));
        activities = await _databaseService.getTransportActivities(
          startDate: monthAgo,
          endDate: DateTime.now(),
        );
        break;
        
      case ExportScope.thisYear:
        final yearStart = DateTime(DateTime.now().year, 1, 1);
        activities = await _databaseService.getTransportActivities(
          startDate: yearStart,
          endDate: DateTime.now(),
        );
        break;
        
      case ExportScope.category:
        activities = await _databaseService.getAllTransportActivities();
        if (filter.categories != null && filter.categories!.isNotEmpty) {
          activities = activities.where((activity) => 
            filter.categories!.contains(activity.type)
          ).toList();
        }
        break;
    }
    
    // Apply CO2 filters
    if (filter.minCO2 != null) {
      activities = activities.where((a) => a.co2EmissionKg >= filter.minCO2!).toList();
    }
    if (filter.maxCO2 != null) {
      activities = activities.where((a) => a.co2EmissionKg <= filter.maxCO2!).toList();
    }
    
    return activities;
  }

  /// Generate export data structure
  Future<Map<String, dynamic>> _generateExportData(
    List<TransportActivity> activities,
    ExportFilter filter,
  ) async {
    final exportData = <String, dynamic>{
      'metadata': {
        'exportDate': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'totalRecords': activities.length,
        'exportFilter': filter.toMap(),
        'dataVersion': '1.0',
      },
      'activities': activities.map((activity) => {
        'id': activity.id,
        'type': activity.type.toString(),
        'typeName': _getTransportTypeName(activity.type),
        'distance_km': activity.distanceKm,
        'duration_minutes': activity.durationMinutes,
        'co2_emission_kg': activity.co2EmissionKg,
        'timestamp': activity.timestamp.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(activity.timestamp),
        'time': DateFormat('HH:mm:ss').format(activity.timestamp),
        'notes': activity.notes,
        'weekday': DateFormat('EEEE').format(activity.timestamp),
        'month': DateFormat('MMMM').format(activity.timestamp),
        'year': activity.timestamp.year,
      }).toList(),
    };

    // Add summary statistics
    if (activities.isNotEmpty) {
      final totalDistance = activities.fold<double>(0, (sum, a) => sum + a.distanceKm);
      final totalCO2 = activities.fold<double>(0, (sum, a) => sum + a.co2EmissionKg);
      final totalDuration = activities.fold<int>(0, (sum, a) => sum + a.durationMinutes);
      
      exportData['summary'] = {
        'totalDistance': totalDistance,
        'totalCO2Emissions': totalCO2,
        'totalDurationMinutes': totalDuration,
        'averageDistance': totalDistance / activities.length,
        'averageCO2': totalCO2 / activities.length,
        'averageDuration': totalDuration / activities.length,
        'dateRange': {
          'earliest': activities.map((a) => a.timestamp).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(),
          'latest': activities.map((a) => a.timestamp).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String(),
        },
        'transportTypeBreakdown': _getTransportTypeBreakdown(activities),
      };
    }

    // Add user preferences if requested
    if (filter.includeUserPreferences) {
      exportData['userPreferences'] = await _getUserPreferences();
    }

    // Add system data if requested
    if (filter.includeSystemData) {
      exportData['systemData'] = await _getSystemData();
    }

    return exportData;
  }

  /// Create export file in specified format
  Future<File> _createExportFile({
    required Map<String, dynamic> data,
    required ExportFormat format,
    required List<TransportActivity> activities,
    String? customFileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    
    String fileName = customFileName ?? 'carbon_tracker_export_$timestamp';
    String fileExtension;
    String fileContent;

    switch (format) {
      case ExportFormat.json:
        fileExtension = 'json';
        fileContent = const JsonEncoder.withIndent('  ').convert(data);
        break;
        
      case ExportFormat.csv:
        fileExtension = 'csv';
        fileContent = _generateCsvContent(activities);
        break;
        
      case ExportFormat.excel:
        fileExtension = 'csv'; // For now, use CSV format for Excel compatibility
        fileContent = _generateExcelCsvContent(activities);
        break;
    }

    final file = File('${directory.path}/$fileName.$fileExtension');
    await file.writeAsString(fileContent);
    
    return file;
  }

  /// Generate CSV content
  String _generateCsvContent(List<TransportActivity> activities) {
    final headers = [
      'ID',
      'Date',
      'Time', 
      'Transport Type',
      'Distance (km)',
      'Duration (min)',
      'CO2 Emissions (kg)',
      'Notes',
      'Weekday',
      'Month',
      'Year',
    ];

    final rows = activities.map((activity) => [
      activity.id,
      DateFormat('yyyy-MM-dd').format(activity.timestamp),
      DateFormat('HH:mm:ss').format(activity.timestamp),
      _getTransportTypeName(activity.type),
      activity.distanceKm.toString(),
      activity.durationMinutes.toString(),
      activity.co2EmissionKg.toString(),
      activity.notes ?? '',
      DateFormat('EEEE').format(activity.timestamp),
      DateFormat('MMMM').format(activity.timestamp),
      activity.timestamp.year.toString(),
    ]).toList();

    return const ListToCsvConverter().convert([headers, ...rows]);
  }

  /// Generate Excel-compatible CSV content with additional formatting
  String _generateExcelCsvContent(List<TransportActivity> activities) {
    final headers = [
      'ID',
      'Date',
      'Time',
      'Transport Type',
      'Distance (km)',
      'Duration (min)',
      'CO2 Emissions (kg)',
      'Environmental Impact',
      'Notes',
      'Day of Week',
      'Month',
      'Year',
      'Week Number',
      'Quarter',
    ];

    final rows = activities.map((activity) => [
      activity.id,
      DateFormat('yyyy-MM-dd').format(activity.timestamp),
      DateFormat('HH:mm:ss').format(activity.timestamp),
      _getTransportTypeName(activity.type),
      activity.distanceKm.toStringAsFixed(2),
      activity.durationMinutes.toString(),
      activity.co2EmissionKg.toStringAsFixed(3),
      _getEnvironmentalImpactCategory(activity.co2EmissionKg),
      (activity.notes ?? '').replaceAll(',', ';'), // Escape commas for CSV
      DateFormat('EEEE').format(activity.timestamp),
      DateFormat('MMMM').format(activity.timestamp),
      activity.timestamp.year.toString(),
      DateFormat('w').format(activity.timestamp),
      'Q${((activity.timestamp.month - 1) ~/ 3) + 1}',
    ]).toList();

    return const ListToCsvConverter().convert([headers, ...rows]);
  }

  /// Share exported file
  Future<void> shareExportFile(ExportResult result) async {
    try {
      await Share.shareXFiles(
        [XFile(result.filePath)],
        text: 'Carbon Tracker Data Export - ${result.totalRecords} records',
        subject: 'Carbon Tracker Export: ${result.fileName}',
      );
      
      _errorHandler.trackEvent('export_file_shared', parameters: {
        'format': result.format.toString(),
        'total_records': result.totalRecords,
        'file_size': result.formattedFileSize,
      });
      
    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.medium,
        context: {'operation': 'share_export_file', 'file_path': result.filePath},
      );
      rethrow;
    }
  }

  /// Get available export formats
  List<ExportFormat> getAvailableFormats() {
    return ExportFormat.values;
  }

  /// Get available export scopes
  List<ExportScope> getAvailableScopes() {
    return ExportScope.values;
  }

  // Helper methods

  String _getTransportTypeName(TransportType type) {
    switch (type) {
      case TransportType.walking:
        return 'Walking';
      case TransportType.bicycle:
        return 'Bicycle';
      case TransportType.car:
        return 'Car';
      case TransportType.bus:
        return 'Bus';
      case TransportType.train:
        return 'Train';
      case TransportType.metro:
        return 'Metro';
      case TransportType.plane:
        return 'Plane';
      case TransportType.boat:
        return 'Boat';
      case TransportType.motorbike:
        return 'Motorbike';
      case TransportType.scooter:
        return 'Scooter';
      case TransportType.rideshare:
        return 'Rideshare';
      case TransportType.taxi:
        return 'Taxi';
      case TransportType.other:
        return 'Other';
    }
  }

  String _getEnvironmentalImpactCategory(double co2Kg) {
    if (co2Kg == 0) return 'Zero Emission';
    if (co2Kg < 0.5) return 'Very Low';
    if (co2Kg < 2.0) return 'Low';
    if (co2Kg < 5.0) return 'Medium';
    if (co2Kg < 10.0) return 'High';
    return 'Very High';
  }

  Map<String, dynamic> _getTransportTypeBreakdown(List<TransportActivity> activities) {
    final breakdown = <String, Map<String, dynamic>>{};
    
    for (final activity in activities) {
      final typeName = _getTransportTypeName(activity.type);
      if (!breakdown.containsKey(typeName)) {
        breakdown[typeName] = {
          'count': 0,
          'totalDistance': 0.0,
          'totalCO2': 0.0,
          'totalDuration': 0,
        };
      }
      
      breakdown[typeName]!['count'] = (breakdown[typeName]!['count'] as int) + 1;
      breakdown[typeName]!['totalDistance'] = (breakdown[typeName]!['totalDistance'] as double) + activity.distanceKm;
      breakdown[typeName]!['totalCO2'] = (breakdown[typeName]!['totalCO2'] as double) + activity.co2EmissionKg;
      breakdown[typeName]!['totalDuration'] = (breakdown[typeName]!['totalDuration'] as int) + activity.durationMinutes;
    }
    
    return breakdown;
  }

  Future<Map<String, dynamic>> _getUserPreferences() async {
    // This would integrate with your settings/preferences system
    return {
      'language': 'en',
      'units': 'metric',
      'notifications': true,
      'theme': 'system',
    };
  }

  Future<Map<String, dynamic>> _getSystemData() async {
    return {
      'appVersion': '1.0.0',
      'platform': Platform.operatingSystem,
      'exportDate': DateTime.now().toIso8601String(),
      'databaseVersion': '1.0',
    };
  }
}