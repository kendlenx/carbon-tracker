import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'error_handler_service.dart';
import '../models/transport_activity.dart';

enum MigrationType {
  schemaUpdate,
  dataTransformation,
  versionUpgrade,
  formatConversion,
}

enum MigrationStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped,
}

class MigrationStep {
  final String id;
  final String name;
  final String description;
  final String fromVersion;
  final String toVersion;
  final MigrationType type;
  final int priority;
  final bool isReversible;
  final Future<bool> Function(Database db, Map<String, dynamic> context) migrationFunction;
  final Future<bool> Function(Database db, Map<String, dynamic> context)? rollbackFunction;

  MigrationStep({
    required this.id,
    required this.name,
    required this.description,
    required this.fromVersion,
    required this.toVersion,
    required this.type,
    required this.priority,
    required this.isReversible,
    required this.migrationFunction,
    this.rollbackFunction,
  });
}

class MigrationResult {
  final String stepId;
  final MigrationStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  MigrationResult({
    required this.stepId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.errorMessage,
    this.metadata = const {},
  });

  Duration? get duration => endTime?.difference(startTime);

  Map<String, dynamic> toMap() {
    return {
      'stepId': stepId,
      'status': status.toString(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'errorMessage': errorMessage,
      'durationMs': duration?.inMilliseconds,
      'metadata': jsonEncode(metadata),
    };
  }
}

class MigrationPlan {
  final String fromVersion;
  final String toVersion;
  final List<MigrationStep> steps;
  final bool requiresBackup;
  final bool canRollback;

  MigrationPlan({
    required this.fromVersion,
    required this.toVersion,
    required this.steps,
    required this.requiresBackup,
    required this.canRollback,
  });

  Duration get estimatedDuration => Duration(
    milliseconds: steps.length * 1000, // Rough estimate: 1 second per step
  );
}

class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  static const String _currentVersion = '1.0.0';
  static const String _migrationTableName = 'migration_history';

  final List<MigrationStep> _allMigrationSteps = [];

  /// Initialize migration service and register all migration steps
  Future<void> initialize() async {
    _registerMigrationSteps();
    await _createMigrationTable();
  }

  /// Check if migration is needed and return migration plan
  Future<MigrationPlan?> checkMigrationNeeded() async {
    try {
      final currentDbVersion = await _getCurrentDatabaseVersion();
      
      if (currentDbVersion == _currentVersion) {
        return null; // No migration needed
      }

      final migrationSteps = _getMigrationPath(currentDbVersion, _currentVersion);
      
      if (migrationSteps.isEmpty) {
        return null;
      }

      return MigrationPlan(
        fromVersion: currentDbVersion,
        toVersion: _currentVersion,
        steps: migrationSteps,
        requiresBackup: migrationSteps.any((step) => 
          step.type == MigrationType.schemaUpdate || 
          step.type == MigrationType.dataTransformation
        ),
        canRollback: migrationSteps.every((step) => step.isReversible),
      );

    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.high,
        context: {'operation': 'check_migration_needed'},
      );
      return null;
    }
  }

  /// Execute migration plan
  Future<List<MigrationResult>> executeMigrationPlan(
    MigrationPlan plan, {
    Function(double progress, String status)? onProgress,
  }) async {
    final results = <MigrationResult>[];
    
    try {
      onProgress?.call(0.0, 'Starting migration from ${plan.fromVersion} to ${plan.toVersion}');

      final db = await _databaseService.database;
      
      for (int i = 0; i < plan.steps.length; i++) {
        final step = plan.steps[i];
        final progress = (i / plan.steps.length) * 0.9;
        
        onProgress?.call(progress, 'Executing: ${step.name}');
        
        final result = await _executeMigrationStep(step, db);
        results.add(result);
        
        if (result.status == MigrationStatus.failed) {
          _errorHandler.log(
            'Migration step failed: ${step.name}',
            LogLevel.error,
            context: result.toMap(),
          );
          break;
        }
      }

      // Update database version if all migrations succeeded
      if (results.every((r) => r.status == MigrationStatus.completed)) {
        await _updateDatabaseVersion(_currentVersion);
        onProgress?.call(1.0, 'Migration completed successfully');
        
        _errorHandler.log(
          'Migration completed: ${plan.fromVersion} -> ${plan.toVersion}',
          LogLevel.info,
          context: {
            'from_version': plan.fromVersion,
            'to_version': plan.toVersion,
            'steps_executed': results.length,
          },
        );
      }

      return results;

    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.critical,
        context: {
          'operation': 'execute_migration_plan',
          'from_version': plan.fromVersion,
          'to_version': plan.toVersion,
        },
      );
      rethrow;
    }
  }

  /// Rollback migration steps
  Future<List<MigrationResult>> rollbackMigration(
    List<MigrationStep> steps, {
    Function(double progress, String status)? onProgress,
  }) async {
    final results = <MigrationResult>[];
    
    try {
      onProgress?.call(0.0, 'Starting migration rollback');

      final db = await _databaseService.database;
      final reversedSteps = steps.reversed.toList();
      
      for (int i = 0; i < reversedSteps.length; i++) {
        final step = reversedSteps[i];
        final progress = (i / reversedSteps.length) * 0.9;
        
        if (!step.isReversible || step.rollbackFunction == null) {
          results.add(MigrationResult(
            stepId: step.id,
            status: MigrationStatus.skipped,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
            errorMessage: 'Step is not reversible',
          ));
          continue;
        }
        
        onProgress?.call(progress, 'Rolling back: ${step.name}');
        
        final result = await _executeRollbackStep(step, db);
        results.add(result);
        
        if (result.status == MigrationStatus.failed) {
          break;
        }
      }

      onProgress?.call(1.0, 'Rollback completed');
      return results;

    } catch (e, stackTrace) {
      _errorHandler.recordError(
        e,
        stackTrace,
        severity: ErrorSeverity.critical,
        context: {'operation': 'rollback_migration'},
      );
      rethrow;
    }
  }

  /// Get migration history
  Future<List<MigrationResult>> getMigrationHistory() async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        _migrationTableName,
        orderBy: 'startTime DESC',
      );
      
      return maps.map((map) => MigrationResult(
        stepId: map['stepId'] as String,
        status: MigrationStatus.values.firstWhere(
          (s) => s.toString() == map['status'],
          orElse: () => MigrationStatus.failed,
        ),
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
        errorMessage: map['errorMessage'] as String?,
        metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata'] as String))
          : {},
      )).toList();
      
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
      return [];
    }
  }

  /// Register all migration steps
  void _registerMigrationSteps() {
    // Migration from version 0.9.0 to 1.0.0 - Add new columns
    _allMigrationSteps.add(MigrationStep(
      id: 'add_notes_column_v1.0.0',
      name: 'Add Notes Column',
      description: 'Add notes column to transport activities table',
      fromVersion: '0.9.0',
      toVersion: '1.0.0',
      type: MigrationType.schemaUpdate,
      priority: 1,
      isReversible: true,
      migrationFunction: _addNotesColumn,
      rollbackFunction: _removeNotesColumn,
    ));

    // Migration from version 1.0.0 to 1.1.0 - Add indexing
    _allMigrationSteps.add(MigrationStep(
      id: 'add_timestamp_index_v1.1.0',
      name: 'Add Timestamp Index',
      description: 'Add index on timestamp column for better query performance',
      fromVersion: '1.0.0',
      toVersion: '1.1.0',
      type: MigrationType.schemaUpdate,
      priority: 1,
      isReversible: true,
      migrationFunction: _addTimestampIndex,
      rollbackFunction: _removeTimestampIndex,
    ));

    // Data transformation: Convert old distance format
    _allMigrationSteps.add(MigrationStep(
      id: 'convert_distance_format_v1.2.0',
      name: 'Convert Distance Format',
      description: 'Convert distance from meters to kilometers',
      fromVersion: '1.1.0',
      toVersion: '1.2.0',
      type: MigrationType.dataTransformation,
      priority: 2,
      isReversible: true,
      migrationFunction: _convertDistanceFormat,
      rollbackFunction: _revertDistanceFormat,
    ));

    // Add CO2 calculation improvements
    _allMigrationSteps.add(MigrationStep(
      id: 'recalculate_co2_v1.3.0',
      name: 'Recalculate CO2 Emissions',
      description: 'Recalculate CO2 emissions with improved formulas',
      fromVersion: '1.2.0',
      toVersion: '1.3.0',
      type: MigrationType.dataTransformation,
      priority: 3,
      isReversible: false,
      migrationFunction: _recalculateCO2Emissions,
    ));

    // Sort by priority
    _allMigrationSteps.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Get migration path from one version to another
  List<MigrationStep> _getMigrationPath(String fromVersion, String toVersion) {
    final relevantSteps = <MigrationStep>[];
    
    for (final step in _allMigrationSteps) {
      if (_isVersionInRange(step.fromVersion, fromVersion, toVersion)) {
        relevantSteps.add(step);
      }
    }
    
    return relevantSteps;
  }

  /// Check if version is in range
  bool _isVersionInRange(String stepFromVersion, String currentVersion, String targetVersion) {
    return _compareVersions(stepFromVersion, targetVersion) <= 0 &&
           _compareVersions(currentVersion, stepFromVersion) < 0;
  }

  /// Compare version strings
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;
      
      if (v1Part != v2Part) {
        return v1Part.compareTo(v2Part);
      }
    }
    
    return 0;
  }

  /// Execute single migration step
  Future<MigrationResult> _executeMigrationStep(MigrationStep step, Database db) async {
    final startTime = DateTime.now();
    
    try {
      final success = await step.migrationFunction(db, {});
      final endTime = DateTime.now();
      
      final result = MigrationResult(
        stepId: step.id,
        status: success ? MigrationStatus.completed : MigrationStatus.failed,
        startTime: startTime,
        endTime: endTime,
        metadata: {
          'step_name': step.name,
          'step_type': step.type.toString(),
        },
      );

      await _saveMigrationResult(result);
      return result;

    } catch (e) {
      final result = MigrationResult(
        stepId: step.id,
        status: MigrationStatus.failed,
        startTime: startTime,
        endTime: DateTime.now(),
        errorMessage: e.toString(),
      );

      await _saveMigrationResult(result);
      return result;
    }
  }

  /// Execute rollback step
  Future<MigrationResult> _executeRollbackStep(MigrationStep step, Database db) async {
    final startTime = DateTime.now();
    
    try {
      final success = await step.rollbackFunction!(db, {});
      final endTime = DateTime.now();
      
      return MigrationResult(
        stepId: '${step.id}_rollback',
        status: success ? MigrationStatus.completed : MigrationStatus.failed,
        startTime: startTime,
        endTime: endTime,
        metadata: {
          'step_name': '${step.name} (Rollback)',
          'step_type': step.type.toString(),
        },
      );

    } catch (e) {
      return MigrationResult(
        stepId: '${step.id}_rollback',
        status: MigrationStatus.failed,
        startTime: startTime,
        endTime: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  /// Database operations
  
  Future<void> _createMigrationTable() async {
    final db = await _databaseService.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_migrationTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stepId TEXT NOT NULL,
        status TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        errorMessage TEXT,
        durationMs INTEGER,
        metadata TEXT
      )
    ''');
  }

  Future<void> _saveMigrationResult(MigrationResult result) async {
    try {
      final db = await _databaseService.database;
      await db.insert(_migrationTableName, result.toMap());
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
    }
  }

  Future<String> _getCurrentDatabaseVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('database_version') ?? '0.9.0';
  }

  Future<void> _updateDatabaseVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('database_version', version);
  }

  // Migration step implementations

  Future<bool> _addNotesColumn(Database db, Map<String, dynamic> context) async {
    try {
      await db.execute('ALTER TABLE activities ADD COLUMN notes TEXT DEFAULT ""');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeNotesColumn(Database db, Map<String, dynamic> context) async {
    try {
      // SQLite doesn't support DROP COLUMN, so we need to recreate the table
      await db.execute('''
        CREATE TABLE activities_backup AS 
        SELECT id, type, distance_km, duration_minutes, co2_emission_kg, timestamp 
        FROM activities
      ''');
      
      await db.execute('DROP TABLE activities');
      
      await db.execute('''
        CREATE TABLE activities (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          distance_km REAL NOT NULL,
          duration_minutes INTEGER NOT NULL,
          co2_emission_kg REAL NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
      
      await db.execute('''
        INSERT INTO activities 
        SELECT * FROM activities_backup
      ''');
      
      await db.execute('DROP TABLE activities_backup');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _addTimestampIndex(Database db, Map<String, dynamic> context) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_activities_timestamp ON activities(timestamp)');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeTimestampIndex(Database db, Map<String, dynamic> context) async {
    try {
      await db.execute('DROP INDEX IF EXISTS idx_activities_timestamp');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _convertDistanceFormat(Database db, Map<String, dynamic> context) async {
    try {
      // Assume old data was stored in meters, convert to kilometers
      await db.execute('''
        UPDATE activities 
        SET distance_km = distance_km / 1000 
        WHERE distance_km > 100
      ''');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _revertDistanceFormat(Database db, Map<String, dynamic> context) async {
    try {
      // Convert back to meters
      await db.execute('''
        UPDATE activities 
        SET distance_km = distance_km * 1000 
        WHERE distance_km < 100
      ''');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _recalculateCO2Emissions(Database db, Map<String, dynamic> context) async {
    try {
      // Get all activities and recalculate CO2 with new formulas
      final activities = await db.query('activities');
      
      for (final activityData in activities) {
        final activity = TransportActivity.fromMap(activityData);
        final newCO2 = _calculateImprovedCO2(activity.type, activity.distanceKm);
        
        await db.update(
          'activities',
          {'co2_emission_kg': newCO2},
          where: 'id = ?',
          whereArgs: [activity.id],
        );
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Improved CO2 calculation (example implementation)
  double _calculateImprovedCO2(TransportType type, double distanceKm) {
    final Map<TransportType, double> improvedFactors = {
      TransportType.walking: 0.0,
      TransportType.bicycle: 0.0,
      TransportType.car: 0.21, // Updated factor
      TransportType.bus: 0.089,
      TransportType.metro: 0.041,
      TransportType.train: 0.045,
      TransportType.plane: 0.255,
      TransportType.motorbike: 0.113,
    };
    
    final factor = improvedFactors[type] ?? 0.15;
    return distanceKm * factor;
  }

  /// Utility methods

  /// Check system compatibility
  Future<Map<String, dynamic>> checkSystemCompatibility() async {
    try {
      final currentVersion = await _getCurrentDatabaseVersion();
      final migrationPlan = await checkMigrationNeeded();
      
      return {
        'current_version': currentVersion,
        'target_version': _currentVersion,
        'migration_needed': migrationPlan != null,
        'can_migrate': migrationPlan != null,
        'requires_backup': migrationPlan?.requiresBackup ?? false,
        'can_rollback': migrationPlan?.canRollback ?? false,
        'estimated_duration_ms': migrationPlan?.estimatedDuration.inMilliseconds ?? 0,
        'migration_steps': migrationPlan?.steps.length ?? 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'migration_needed': false,
        'can_migrate': false,
      };
    }
  }

  /// Get available migration information
  Map<String, dynamic> getMigrationInfo() {
    return {
      'current_version': _currentVersion,
      'registered_steps': _allMigrationSteps.length,
      'migration_types': MigrationType.values.map((t) => t.toString()).toList(),
      'available_versions': _allMigrationSteps.map((s) => s.toVersion).toSet().toList(),
    };
  }

  /// Clean old migration history (keep last 50 entries)
  Future<void> cleanupMigrationHistory() async {
    try {
      final db = await _databaseService.database;
      
      // Keep only the last 50 migration records
      await db.execute('''
        DELETE FROM $_migrationTableName 
        WHERE id NOT IN (
          SELECT id FROM $_migrationTableName 
          ORDER BY startTime DESC 
          LIMIT 50
        )
      ''');
    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
    }
  }
}