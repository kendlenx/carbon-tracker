import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'error_handler_service.dart';
import '../models/transport_activity.dart';

enum ImportFormat {
  json,
  csv,
  carbonTracker, // Our own format
}

enum ImportValidationResult {
  valid,
  warning,
  error,
}

enum ImportConflictResolution {
  skip,
  overwrite,
  keepBoth,
  merge,
}

class ImportValidation {
  final ImportValidationResult result;
  final String message;
  final int? lineNumber;
  final Map<String, dynamic>? context;

  ImportValidation({
    required this.result,
    required this.message,
    this.lineNumber,
    this.context,
  });

  bool get isValid => result == ImportValidationResult.valid;
  bool get hasWarning => result == ImportValidationResult.warning;
  bool get hasError => result == ImportValidationResult.error;
}

class ImportConflict {
  final String existingId;
  final Map<String, dynamic> existingData;
  final Map<String, dynamic> newData;
  final String conflictReason;

  ImportConflict({
    required this.existingId,
    required this.existingData,
    required this.newData,
    required this.conflictReason,
  });
}

class ImportResult {
  final int totalRecords;
  final int importedRecords;
  final int skippedRecords;
  final int errorRecords;
  final List<ImportValidation> validations;
  final List<ImportConflict> conflicts;
  final DateTime importDate;
  final Duration processingTime;
  final String sourceFile;

  ImportResult({
    required this.totalRecords,
    required this.importedRecords,
    required this.skippedRecords,
    required this.errorRecords,
    required this.validations,
    required this.conflicts,
    required this.importDate,
    required this.processingTime,
    required this.sourceFile,
  });

  bool get hasErrors => errorRecords > 0;
  bool get hasWarnings => validations.any((v) => v.hasWarning);
  bool get isSuccessful => importedRecords > 0 && errorRecords == 0;
  
  double get successRate => totalRecords > 0 ? importedRecords / totalRecords : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'totalRecords': totalRecords,
      'importedRecords': importedRecords,
      'skippedRecords': skippedRecords,
      'errorRecords': errorRecords,
      'successRate': successRate,
      'hasErrors': hasErrors,
      'hasWarnings': hasWarnings,
      'importDate': importDate.toIso8601String(),
      'processingTimeMs': processingTime.inMilliseconds,
      'sourceFile': sourceFile,
    };
  }
}

class AdvancedImportService {
  static final AdvancedImportService _instance = AdvancedImportService._internal();
  factory AdvancedImportService() => _instance;
  AdvancedImportService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  /// Import data from file with advanced validation and conflict resolution
  Future<ImportResult> importData({
    required String filePath,
    required ImportFormat format,
    ImportConflictResolution conflictResolution = ImportConflictResolution.skip,
    bool validateOnly = false,
    Function(double progress, String status)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final validations = <ImportValidation>[];
    final conflicts = <ImportConflict>[];
    int totalRecords = 0;
    int importedRecords = 0;
    int skippedRecords = 0;
    int errorRecords = 0;

    try {
      onProgress?.call(0.1, 'Reading file...');
      
      // Read and parse file
      final fileContent = await File(filePath).readAsString();
      final parsedData = await _parseFileContent(fileContent, format);
      
      totalRecords = parsedData.length;
      onProgress?.call(0.2, 'Parsed $totalRecords records');
      
      // Validate data
      onProgress?.call(0.3, 'Validating data...');
      final validationResults = await _validateImportData(parsedData);
      validations.addAll(validationResults);
      
      if (validateOnly) {
        errorRecords = validations.where((v) => v.hasError).length;
        return ImportResult(
          totalRecords: totalRecords,
          importedRecords: 0,
          skippedRecords: 0,
          errorRecords: errorRecords,
          validations: validations,
          conflicts: conflicts,
          importDate: DateTime.now(),
          processingTime: DateTime.now().difference(startTime),
          sourceFile: filePath.split('/').last,
        );
      }
      
      // Check for conflicts
      onProgress?.call(0.4, 'Checking for conflicts...');
      final existingActivities = await _databaseService.getAllTransportActivities();
      
      for (int i = 0; i < parsedData.length; i++) {
        try {
          final record = parsedData[i];
          final progressValue = 0.4 + (i / parsedData.length) * 0.5;
          onProgress?.call(progressValue, 'Processing record ${i + 1}/$totalRecords');
          
          // Skip records with validation errors
          final recordValidations = validations.where((v) => v.lineNumber == i + 1);
          if (recordValidations.any((v) => v.hasError)) {
            errorRecords++;
            continue;
          }
          
          // Convert to TransportActivity
          final activity = await _convertToTransportActivity(record);
          if (activity == null) {
            errorRecords++;
            continue;
          }
          
          // Check for conflicts
          final conflict = _findConflict(activity, existingActivities);
          if (conflict != null) {
            conflicts.add(conflict);
            
            switch (conflictResolution) {
              case ImportConflictResolution.skip:
                skippedRecords++;
                continue;
                
              case ImportConflictResolution.overwrite:
                await _databaseService.deleteTransportActivity(conflict.existingId);
                await _databaseService.addActivity(activity);
                importedRecords++;
                break;
                
              case ImportConflictResolution.keepBoth:
                // Create new ID for imported record
                final newActivity = TransportActivity(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  type: activity.type,
                  distanceKm: activity.distanceKm,
                  durationMinutes: activity.durationMinutes,
                  co2EmissionKg: activity.co2EmissionKg,
                  timestamp: activity.timestamp,
                  notes: '${activity.notes} (Imported)',
                );
                await _databaseService.addActivity(newActivity);
                importedRecords++;
                break;
                
              case ImportConflictResolution.merge:
                // Merge data (average CO2, sum distance, etc.)
                final mergedActivity = await _mergeActivities(
                  existingActivities.firstWhere((a) => a.id == conflict.existingId),
                  activity,
                );
                await _databaseService.deleteTransportActivity(conflict.existingId);
                await _databaseService.addActivity(mergedActivity);
                importedRecords++;
                break;
            }
          } else {
            // No conflict, add directly
            await _databaseService.addActivity(activity);
            importedRecords++;
          }
          
        } catch (e) {
          errorRecords++;
          validations.add(ImportValidation(
            result: ImportValidationResult.error,
            message: 'Failed to process record: ${e.toString()}',
            lineNumber: i + 1,
          ));
        }
      }
      
      onProgress?.call(1.0, 'Import completed');
      
      final result = ImportResult(
        totalRecords: totalRecords,
        importedRecords: importedRecords,
        skippedRecords: skippedRecords,
        errorRecords: errorRecords,
        validations: validations,
        conflicts: conflicts,
        importDate: DateTime.now(),
        processingTime: DateTime.now().difference(startTime),
        sourceFile: filePath.split('/').last,
      );
      
      // Log import event
      _errorHandler.trackEvent('data_import_completed', parameters: result.toMap());
      
      _errorHandler.log(
        'Data import completed: ${result.importedRecords}/${result.totalRecords} records imported',
        result.hasErrors ? LogLevel.warning : LogLevel.info,
        context: result.toMap(),
      );
      
      return result;
      
    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.high,
        context: {
          'operation': 'data_import',
          'format': format.toString(),
          'file_path': filePath,
        },
      );
      rethrow;
    }
  }

  /// Parse file content based on format
  Future<List<Map<String, dynamic>>> _parseFileContent(
    String content,
    ImportFormat format,
  ) async {
    switch (format) {
      case ImportFormat.json:
        return await _parseJsonContent(content);
        
      case ImportFormat.csv:
        return await _parseCsvContent(content);
        
      case ImportFormat.carbonTracker:
        return await _parseCarbonTrackerContent(content);
    }
  }

  Future<List<Map<String, dynamic>>> _parseJsonContent(String content) async {
    try {
      final jsonData = jsonDecode(content);
      
      if (jsonData is Map && jsonData.containsKey('activities')) {
        // Carbon Tracker export format
        return List<Map<String, dynamic>>.from(jsonData['activities']);
      } else if (jsonData is List) {
        // Direct array format
        return List<Map<String, dynamic>>.from(jsonData);
      } else {
        throw Exception('Invalid JSON format');
      }
    } catch (e) {
      throw Exception('Failed to parse JSON: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> _parseCsvContent(String content) async {
    try {
      final csvData = const CsvToListConverter().convert(content);
      if (csvData.isEmpty) return [];
      
      final headers = csvData.first.map((e) => e.toString().toLowerCase()).toList();
      final records = <Map<String, dynamic>>[];
      
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        final record = <String, dynamic>{};
        
        for (int j = 0; j < headers.length && j < row.length; j++) {
          record[headers[j]] = row[j];
        }
        
        records.add(record);
      }
      
      return records;
    } catch (e) {
      throw Exception('Failed to parse CSV: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> _parseCarbonTrackerContent(String content) async {
    // Same as JSON for now, but could have special handling
    return await _parseJsonContent(content);
  }

  /// Validate import data
  Future<List<ImportValidation>> _validateImportData(
    List<Map<String, dynamic>> data,
  ) async {
    final validations = <ImportValidation>[];
    
    for (int i = 0; i < data.length; i++) {
      final record = data[i];
      final lineNumber = i + 1;
      
      // Required fields validation
      final requiredFields = ['type', 'distance', 'co2', 'date'];
      for (final field in requiredFields) {
        if (!_hasValidField(record, field)) {
          validations.add(ImportValidation(
            result: ImportValidationResult.error,
            message: 'Missing or invalid required field: $field',
            lineNumber: lineNumber,
            context: {'field': field, 'record': record},
          ));
        }
      }
      
      // Data type validation
      if (_hasValidField(record, 'distance')) {
        final distance = _parseDouble(record['distance'] ?? record['distance_km']);
        if (distance == null || distance < 0) {
          validations.add(ImportValidation(
            result: ImportValidationResult.error,
            message: 'Invalid distance value',
            lineNumber: lineNumber,
          ));
        } else if (distance > 1000) {
          validations.add(ImportValidation(
            result: ImportValidationResult.warning,
            message: 'Unusually high distance value: ${distance}km',
            lineNumber: lineNumber,
          ));
        }
      }
      
      // CO2 validation
      if (_hasValidField(record, 'co2')) {
        final co2 = _parseDouble(record['co2'] ?? record['co2_emission_kg']);
        if (co2 == null || co2 < 0) {
          validations.add(ImportValidation(
            result: ImportValidationResult.error,
            message: 'Invalid CO2 emission value',
            lineNumber: lineNumber,
          ));
        }
      }
      
      // Date validation
      if (_hasValidField(record, 'date')) {
        final dateStr = record['date']?.toString() ?? record['timestamp']?.toString();
        if (dateStr == null || _parseDateTime(dateStr) == null) {
          validations.add(ImportValidation(
            result: ImportValidationResult.error,
            message: 'Invalid date format',
            lineNumber: lineNumber,
          ));
        }
      }
      
      // Transport type validation
      if (_hasValidField(record, 'type')) {
        final typeStr = record['type']?.toString() ?? record['transport_type']?.toString();
        if (typeStr == null || _parseTransportType(typeStr) == null) {
          validations.add(ImportValidation(
            result: ImportValidationResult.warning,
            message: 'Unknown transport type: $typeStr',
            lineNumber: lineNumber,
          ));
        }
      }
    }
    
    return validations;
  }

  /// Convert parsed record to TransportActivity
  Future<TransportActivity?> _convertToTransportActivity(
    Map<String, dynamic> record,
  ) async {
    try {
      // Parse transport type
      final typeStr = record['type']?.toString() ?? 
                     record['transport_type']?.toString() ??
                     record['typeName']?.toString();
      final type = _parseTransportType(typeStr) ?? TransportType.car;
      
      // Parse distance
      final distance = _parseDouble(record['distance'] ?? 
                                  record['distance_km'] ?? 
                                  record['distancekm']) ?? 0.0;
      
      // Parse duration
      final duration = _parseInt(record['duration'] ?? 
                                record['duration_minutes'] ?? 
                                record['durationminutes']) ?? 
                      (distance * 3).round(); // Estimate if not provided
      
      // Parse CO2
      final co2 = _parseDouble(record['co2'] ?? 
                             record['co2_emission_kg'] ??
                             record['co2emissionkg']) ?? 0.0;
      
      // Parse timestamp
      final dateStr = record['date']?.toString() ?? 
                     record['timestamp']?.toString();
      final timeStr = record['time']?.toString();
      final timestamp = _parseDateTime(dateStr, timeStr) ?? DateTime.now();
      
      // Parse notes
      final notes = record['notes']?.toString() ?? '';
      
      // Generate ID if not present
      final id = record['id']?.toString() ?? 
                DateTime.now().microsecondsSinceEpoch.toString();
      
      return TransportActivity(
        id: id,
        type: type,
        distanceKm: distance,
        durationMinutes: duration,
        co2EmissionKg: co2,
        timestamp: timestamp,
        notes: notes,
      );
      
    } catch (e) {
      return null;
    }
  }

  /// Find conflict with existing data
  ImportConflict? _findConflict(
    TransportActivity activity,
    List<TransportActivity> existing,
  ) {
    // Check for exact timestamp and type match
    for (final existingActivity in existing) {
      if (existingActivity.timestamp.isAtSameMomentAs(activity.timestamp) &&
          existingActivity.type == activity.type) {
        return ImportConflict(
          existingId: existingActivity.id,
          existingData: existingActivity.toMap(),
          newData: activity.toMap(),
          conflictReason: 'Same timestamp and transport type',
        );
      }
    }
    
    // Check for near timestamp (within 1 minute) and same type
    for (final existingActivity in existing) {
      final timeDiff = activity.timestamp.difference(existingActivity.timestamp).abs();
      if (timeDiff.inMinutes <= 1 && existingActivity.type == activity.type) {
        return ImportConflict(
          existingId: existingActivity.id,
          existingData: existingActivity.toMap(),
          newData: activity.toMap(),
          conflictReason: 'Very similar timestamp and same transport type',
        );
      }
    }
    
    return null;
  }

  /// Merge two activities
  Future<TransportActivity> _mergeActivities(
    TransportActivity existing,
    TransportActivity imported,
  ) async {
    return TransportActivity(
      id: existing.id,
      type: existing.type,
      distanceKm: (existing.distanceKm + imported.distanceKm) / 2, // Average
      durationMinutes: existing.durationMinutes + imported.durationMinutes,
      co2EmissionKg: (existing.co2EmissionKg + imported.co2EmissionKg) / 2, // Average
      timestamp: existing.timestamp, // Keep original timestamp
      notes: '${existing.notes} | Merged with: ${imported.notes}',
    );
  }

  // Helper methods

  bool _hasValidField(Map<String, dynamic> record, String field) {
    final possibleKeys = _getFieldVariations(field);
    return possibleKeys.any((key) => record.containsKey(key) && record[key] != null);
  }

  List<String> _getFieldVariations(String field) {
    switch (field.toLowerCase()) {
      case 'type':
        return ['type', 'transport_type', 'typeName', 'transport type'];
      case 'distance':
        return ['distance', 'distance_km', 'distancekm', 'distance (km)'];
      case 'co2':
        return ['co2', 'co2_emission_kg', 'co2emissionkg', 'co2 emissions (kg)'];
      case 'date':
        return ['date', 'timestamp', 'datetime'];
      default:
        return [field];
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  DateTime? _parseDateTime(String? dateStr, [String? timeStr]) {
    if (dateStr == null) return null;
    
    try {
      // Try parsing as ISO 8601
      final iso8601 = DateTime.tryParse(dateStr);
      if (iso8601 != null) return iso8601;
      
      // Try parsing with time
      if (timeStr != null) {
        final combined = '$dateStr $timeStr';
        final withTime = DateTime.tryParse(combined);
        if (withTime != null) return withTime;
      }
      
      // Try common date formats
      final formats = [
        'yyyy-MM-dd',
        'MM/dd/yyyy',
        'dd/MM/yyyy',
        'yyyy/MM/dd',
        'dd-MM-yyyy',
        'MM-dd-yyyy',
      ];
      
      for (final format in formats) {
        try {
          return DateFormat(format).parse(dateStr);
        } catch (e) {
          continue;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  TransportType? _parseTransportType(String? typeStr) {
    if (typeStr == null) return null;
    
    final normalized = typeStr.toLowerCase();
    
    for (final type in TransportType.values) {
      if (type.toString().toLowerCase().contains(normalized) ||
          normalized.contains(type.toString().split('.').last.toLowerCase())) {
        return type;
      }
    }
    
    // Custom mappings
    final mappings = {
      'walk': TransportType.walking,
      'bike': TransportType.bicycle,
      'public': TransportType.bus,
      'metro': TransportType.metro,
      'subway': TransportType.metro,
      'rail': TransportType.train,
      'automobile': TransportType.car,
      'vehicle': TransportType.car,
    };
    
    for (final entry in mappings.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Get supported import formats
  List<ImportFormat> getSupportedFormats() {
    return ImportFormat.values;
  }
}