import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'error_handler_service.dart';
import 'advanced_import_service.dart';
import '../models/transport_activity.dart';

enum BackupType {
  full,
  incremental,
  differential,
}

enum BackupStatus {
  created,
  inProgress,
  completed,
  failed,
  restored,
}

enum RestoreStrategy {
  replaceAll,
  mergeWithExisting,
  restoreOnlyMissing,
}

class BackupMetadata {
  final String id;
  final String name;
  final BackupType type;
  final BackupStatus status;
  final DateTime createdAt;
  final DateTime? restoredAt;
  final int recordCount;
  final String filePath;
  final String checksum;
  final int sizeBytes;
  final String? parentBackupId; // For incremental/differential backups
  final String version;
  final Map<String, dynamic> metadata;

  BackupMetadata({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
    this.restoredAt,
    required this.recordCount,
    required this.filePath,
    required this.checksum,
    required this.sizeBytes,
    this.parentBackupId,
    required this.version,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'restoredAt': restoredAt?.toIso8601String(),
      'recordCount': recordCount,
      'filePath': filePath,
      'checksum': checksum,
      'sizeBytes': sizeBytes,
      'parentBackupId': parentBackupId,
      'version': version,
      'metadata': jsonEncode(metadata),
    };
  }

  factory BackupMetadata.fromMap(Map<String, dynamic> map) {
    return BackupMetadata(
      id: map['id'],
      name: map['name'],
      type: BackupType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => BackupType.full,
      ),
      status: BackupStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => BackupStatus.created,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      restoredAt: map['restoredAt'] != null ? DateTime.parse(map['restoredAt']) : null,
      recordCount: map['recordCount'],
      filePath: map['filePath'],
      checksum: map['checksum'],
      sizeBytes: map['sizeBytes'],
      parentBackupId: map['parentBackupId'],
      version: map['version'],
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
          : {},
    );
  }

  bool get isExpired {
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    return daysSinceCreation > 90; // Expire backups after 90 days
  }

  String get displaySize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class RestoreResult {
  final bool success;
  final int restoredRecords;
  final int skippedRecords;
  final int errorRecords;
  final List<String> errors;
  final Duration processingTime;
  final RestoreStrategy strategy;

  RestoreResult({
    required this.success,
    required this.restoredRecords,
    required this.skippedRecords,
    required this.errorRecords,
    required this.errors,
    required this.processingTime,
    required this.strategy,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'restoredRecords': restoredRecords,
      'skippedRecords': skippedRecords,
      'errorRecords': errorRecords,
      'errors': errors,
      'processingTimeMs': processingTime.inMilliseconds,
      'strategy': strategy.toString(),
    };
  }
}

class BackupManagementService {
  static final BackupManagementService _instance = BackupManagementService._internal();
  factory BackupManagementService() => _instance;
  BackupManagementService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();
  final AdvancedImportService _importService = AdvancedImportService();

  static const String _currentVersion = '1.0.0';
  static const int _maxBackupsToKeep = 20;

  /// Get backup directory
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Create a new backup
  Future<BackupMetadata> createBackup({
    String? name,
    BackupType type = BackupType.full,
    String? parentBackupId,
    Function(double progress, String status)? onProgress,
  }) async {
    final startTime = DateTime.now();
    onProgress?.call(0.1, 'Initializing backup...');

    try {
      // Generate backup info
      final backupId = DateTime.now().millisecondsSinceEpoch.toString();
      final backupName = name ?? 'Backup ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
      final backupDir = await _getBackupDirectory();
      final backupFile = File('${backupDir.path}/backup_$backupId.json');

      onProgress?.call(0.2, 'Fetching data...');

      // Fetch data based on backup type
      List<TransportActivity> activities;
      BackupMetadata? parentBackup;

      switch (type) {
        case BackupType.full:
          activities = await _databaseService.getAllTransportActivities();
          break;
          
        case BackupType.incremental:
          if (parentBackupId == null) {
            throw Exception('Parent backup ID required for incremental backup');
          }
          parentBackup = await _getBackupMetadata(parentBackupId);
          if (parentBackup == null) {
            throw Exception('Parent backup not found');
          }
          activities = await _getActivitiesSince(parentBackup.createdAt);
          break;
          
        case BackupType.differential:
          if (parentBackupId == null) {
            throw Exception('Parent backup ID required for differential backup');
          }
          parentBackup = await _getBackupMetadata(parentBackupId);
          if (parentBackup == null) {
            throw Exception('Parent backup not found');
          }
          activities = await _getActivitiesSince(parentBackup.createdAt);
          break;
      }

      onProgress?.call(0.5, 'Preparing backup data...');

      // Create backup data structure
      final backupData = {
        'version': _currentVersion,
        'backupId': backupId,
        'name': backupName,
        'type': type.toString(),
        'createdAt': startTime.toIso8601String(),
        'parentBackupId': parentBackupId,
        'recordCount': activities.length,
        'activities': activities.map((activity) => activity.toMap()).toList(),
        'metadata': {
          'app_version': _currentVersion,
          'platform': defaultTargetPlatform.toString(),
          'backup_sequence': await _getNextBackupSequence(),
        },
      };

      onProgress?.call(0.7, 'Writing backup file...');

      // Write to file
      final backupJson = jsonEncode(backupData);
      await backupFile.writeAsString(backupJson);

      onProgress?.call(0.8, 'Calculating checksum...');

      // Calculate checksum
      final checksum = await _calculateChecksum(backupFile);
      final fileSize = await backupFile.length();

      onProgress?.call(0.9, 'Saving backup metadata...');

      // Create metadata
      final metadata = BackupMetadata(
        id: backupId,
        name: backupName,
        type: type,
        status: BackupStatus.completed,
        createdAt: startTime,
        recordCount: activities.length,
        filePath: backupFile.path,
        checksum: checksum,
        sizeBytes: fileSize,
        parentBackupId: parentBackupId,
        version: _currentVersion,
        metadata: backupData['metadata'] as Map<String, dynamic>,
      );

      // Save metadata to database
      await _saveBackupMetadata(metadata);

      onProgress?.call(1.0, 'Backup completed');

      // Clean up old backups
      await _cleanupOldBackups();

      _errorHandler.log(
        'Backup created successfully: $backupName (${activities.length} records)',
        LogLevel.info,
        context: metadata.toMap(),
      );

      _errorHandler.trackEvent('backup_created', parameters: {
        'backup_type': type.toString(),
        'record_count': activities.length,
        'size_bytes': fileSize,
      });

      return metadata;

    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.medium,
        context: {
          'operation': 'create_backup',
          'backup_type': type.toString(),
          'parent_backup_id': parentBackupId,
        },
      );
      rethrow;
    }
  }

  /// Restore from backup
  Future<RestoreResult> restoreBackup({
    required String backupId,
    RestoreStrategy strategy = RestoreStrategy.replaceAll,
    Function(double progress, String status)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int restoredRecords = 0;
    int skippedRecords = 0;
    int errorRecords = 0;

    try {
      onProgress?.call(0.1, 'Loading backup...');

      // Get backup metadata
      final backup = await _getBackupMetadata(backupId);
      if (backup == null) {
        throw Exception('Backup not found');
      }

      // Verify backup file exists and integrity
      final backupFile = File(backup.filePath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: ${backup.filePath}');
      }

      onProgress?.call(0.2, 'Verifying backup integrity...');

      final currentChecksum = await _calculateChecksum(backupFile);
      if (currentChecksum != backup.checksum) {
        throw Exception('Backup file is corrupted (checksum mismatch)');
      }

      onProgress?.call(0.3, 'Reading backup data...');

      // Read and parse backup
      final backupContent = await backupFile.readAsString();
      final backupData = jsonDecode(backupContent);
      
      final activities = (backupData['activities'] as List)
          .map((data) => TransportActivity.fromMap(data))
          .toList();

      onProgress?.call(0.4, 'Preparing restoration...');

      // Handle different restore strategies
      switch (strategy) {
        case RestoreStrategy.replaceAll:
          await _restoreReplaceAll(activities, onProgress);
          restoredRecords = activities.length;
          break;
          
        case RestoreStrategy.mergeWithExisting:
          final result = await _restoreMergeWithExisting(activities, onProgress);
          restoredRecords = result['restored'] ?? 0;
          skippedRecords = result['skipped'] ?? 0;
          errorRecords = result['errors'] ?? 0;
          errors.addAll(result['errorMessages'] ?? []);
          break;
          
        case RestoreStrategy.restoreOnlyMissing:
          final result = await _restoreOnlyMissing(activities, onProgress);
          restoredRecords = result['restored'] ?? 0;
          skippedRecords = result['skipped'] ?? 0;
          errorRecords = result['errors'] ?? 0;
          errors.addAll(result['errorMessages'] ?? []);
          break;
      }

      onProgress?.call(0.9, 'Updating backup status...');

      // Update backup metadata
      final updatedBackup = BackupMetadata(
        id: backup.id,
        name: backup.name,
        type: backup.type,
        status: BackupStatus.restored,
        createdAt: backup.createdAt,
        restoredAt: DateTime.now(),
        recordCount: backup.recordCount,
        filePath: backup.filePath,
        checksum: backup.checksum,
        sizeBytes: backup.sizeBytes,
        parentBackupId: backup.parentBackupId,
        version: backup.version,
        metadata: backup.metadata,
      );

      await _updateBackupMetadata(updatedBackup);

      onProgress?.call(1.0, 'Restore completed');

      final result = RestoreResult(
        success: errorRecords == 0,
        restoredRecords: restoredRecords,
        skippedRecords: skippedRecords,
        errorRecords: errorRecords,
        errors: errors,
        processingTime: DateTime.now().difference(startTime),
        strategy: strategy,
      );

      _errorHandler.log(
        'Backup restored: ${result.restoredRecords} records restored',
        result.success ? LogLevel.info : LogLevel.warning,
        context: result.toMap(),
      );

      _errorHandler.trackEvent('backup_restored', parameters: result.toMap());

      return result;

    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.high,
        context: {
          'operation': 'restore_backup',
          'backup_id': backupId,
          'strategy': strategy.toString(),
        },
      );
      
      return RestoreResult(
        success: false,
        restoredRecords: restoredRecords,
        skippedRecords: skippedRecords,
        errorRecords: errorRecords + 1,
        errors: [...errors, e.toString()],
        processingTime: DateTime.now().difference(startTime),
        strategy: strategy,
      );
    }
  }

  /// Get all backup metadata
  Future<List<BackupMetadata>> getAllBackups() async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        'backups',
        orderBy: 'createdAt DESC',
      );
      
      return maps.map((map) => BackupMetadata.fromMap(map)).toList();
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
      return [];
    }
  }

  /// Delete backup
  Future<void> deleteBackup(String backupId) async {
    try {
      final backup = await _getBackupMetadata(backupId);
      if (backup == null) return;

      // Delete file
      final backupFile = File(backup.filePath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      // Delete from database
      final db = await _databaseService.database;
      await db.delete('backups', where: 'id = ?', whereArgs: [backupId]);

      _errorHandler.log('Backup deleted: ${backup.name}', LogLevel.info);
      _errorHandler.trackEvent('backup_deleted', parameters: {'backup_id': backupId});

    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
      rethrow;
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackup(String backupId) async {
    try {
      final backup = await _getBackupMetadata(backupId);
      if (backup == null) return false;

      final backupFile = File(backup.filePath);
      if (!await backupFile.exists()) return false;

      final currentChecksum = await _calculateChecksum(backupFile);
      return currentChecksum == backup.checksum;
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
      return false;
    }
  }

  // Private helper methods

  Future<BackupMetadata?> _getBackupMetadata(String backupId) async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        'backups',
        where: 'id = ?',
        whereArgs: [backupId],
      );
      
      if (maps.isEmpty) return null;
      return BackupMetadata.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveBackupMetadata(BackupMetadata metadata) async {
    final db = await _databaseService.database;
    
    // Create table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS backups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        restoredAt TEXT,
        recordCount INTEGER NOT NULL,
        filePath TEXT NOT NULL,
        checksum TEXT NOT NULL,
        sizeBytes INTEGER NOT NULL,
        parentBackupId TEXT,
        version TEXT NOT NULL,
        metadata TEXT
      )
    ''');

    await db.insert('backups', metadata.toMap());
  }

  Future<void> _updateBackupMetadata(BackupMetadata metadata) async {
    final db = await _databaseService.database;
    await db.update(
      'backups',
      metadata.toMap(),
      where: 'id = ?',
      whereArgs: [metadata.id],
    );
  }

  Future<List<TransportActivity>> _getActivitiesSince(DateTime since) async {
    final activities = await _databaseService.getAllTransportActivities();
    return activities.where((activity) => activity.timestamp.isAfter(since)).toList();
  }

  Future<String> _calculateChecksum(File file) async {
    // Simple checksum based on file size and modification time
    final stat = await file.stat();
    return '${stat.size}_${stat.modified.millisecondsSinceEpoch}';
  }

  Future<int> _getNextBackupSequence() async {
    final backups = await getAllBackups();
    return backups.length + 1;
  }

  Future<void> _restoreReplaceAll(
    List<TransportActivity> activities,
    Function(double, String)? onProgress,
  ) async {
    onProgress?.call(0.5, 'Clearing existing data...');
    
    // Clear all existing activities
    final existingActivities = await _databaseService.getAllTransportActivities();
    for (final activity in existingActivities) {
      await _databaseService.deleteTransportActivity(activity.id);
    }

    onProgress?.call(0.7, 'Restoring activities...');

    // Add all activities from backup
    for (int i = 0; i < activities.length; i++) {
      await _databaseService.addActivity(activities[i]);
      onProgress?.call(0.7 + (i / activities.length) * 0.2, 
          'Restoring ${i + 1}/${activities.length} activities...');
    }
  }

  Future<Map<String, dynamic>> _restoreMergeWithExisting(
    List<TransportActivity> activities,
    Function(double, String)? onProgress,
  ) async {
    int restored = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorMessages = [];

    onProgress?.call(0.5, 'Loading existing data...');
    final existingActivities = await _databaseService.getAllTransportActivities();

    for (int i = 0; i < activities.length; i++) {
      try {
        final activity = activities[i];
        onProgress?.call(0.5 + (i / activities.length) * 0.4, 
            'Processing ${i + 1}/${activities.length} activities...');

        // Check if activity already exists
        final existingActivity = existingActivities.firstWhere(
          (existing) => existing.id == activity.id,
          orElse: () => TransportActivity(
            id: '',
            type: TransportType.walking,
            distanceKm: 0,
            durationMinutes: 0,
            co2EmissionKg: 0,
            timestamp: DateTime.now(),
          ),
        );

        if (existingActivity.id.isEmpty) {
          // Activity doesn't exist, add it
          await _databaseService.addActivity(activity);
          restored++;
        } else {
          // Activity exists, skip it
          skipped++;
        }
      } catch (e) {
        errors++;
        errorMessages.add('Error processing activity ${activity.id}: $e');
      }
    }

    return {
      'restored': restored,
      'skipped': skipped,
      'errors': errors,
      'errorMessages': errorMessages,
    };
  }

  Future<Map<String, dynamic>> _restoreOnlyMissing(
    List<TransportActivity> activities,
    Function(double, String)? onProgress,
  ) async {
    int restored = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorMessages = [];

    onProgress?.call(0.5, 'Checking for missing activities...');
    final existingActivities = await _databaseService.getAllTransportActivities();
    final existingIds = existingActivities.map((a) => a.id).toSet();

    final missingActivities = activities
        .where((activity) => !existingIds.contains(activity.id))
        .toList();

    for (int i = 0; i < missingActivities.length; i++) {
      try {
        final activity = missingActivities[i];
        onProgress?.call(0.5 + (i / missingActivities.length) * 0.4, 
            'Restoring ${i + 1}/${missingActivities.length} missing activities...');

        await _databaseService.addActivity(activity);
        restored++;
      } catch (e) {
        errors++;
        errorMessages.add('Error restoring activity ${activity.id}: $e');
      }
    }

    skipped = activities.length - missingActivities.length;

    return {
      'restored': restored,
      'skipped': skipped,
      'errors': errors,
      'errorMessages': errorMessages,
    };
  }

  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await getAllBackups();
      
      // Remove expired backups
      for (final backup in backups) {
        if (backup.isExpired) {
          await deleteBackup(backup.id);
        }
      }

      // Keep only the latest N backups
      final activeBackups = await getAllBackups();
      if (activeBackups.length > _maxBackupsToKeep) {
        final backupsToDelete = activeBackups
            .skip(_maxBackupsToKeep)
            .toList();
        
        for (final backup in backupsToDelete) {
          await deleteBackup(backup.id);
        }
      }
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
    }
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final backups = await getAllBackups();
      
      final totalSize = backups.fold<int>(0, (sum, backup) => sum + backup.sizeBytes);
      final totalRecords = backups.fold<int>(0, (sum, backup) => sum + backup.recordCount);
      
      final typeCount = <BackupType, int>{};
      for (final type in BackupType.values) {
        typeCount[type] = backups.where((b) => b.type == type).length;
      }

      final lastBackup = backups.isNotEmpty ? backups.first : null;

      return {
        'total_backups': backups.length,
        'total_size_bytes': totalSize,
        'total_records': totalRecords,
        'type_distribution': typeCount.map((k, v) => MapEntry(k.toString(), v)),
        'last_backup_date': lastBackup?.createdAt.toIso8601String(),
        'oldest_backup_date': backups.isNotEmpty ? backups.last.createdAt.toIso8601String() : null,
      };
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
      return {};
    }
  }
}