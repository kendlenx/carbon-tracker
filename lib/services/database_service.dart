import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transport_activity.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'carbon_tracker.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String _transportActivitiesTable = 'transport_activities';

  // Singleton pattern
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Transport Activities table
    await db.execute('''
      CREATE TABLE $_transportActivitiesTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        distanceKm REAL NOT NULL,
        durationMinutes INTEGER NOT NULL,
        co2EmissionKg REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        fromLocation TEXT,
        toLocation TEXT,
        notes TEXT,
        metadata TEXT
      )
    ''');

    // Create indices for better performance
    await db.execute('''
      CREATE INDEX idx_transport_timestamp 
      ON $_transportActivitiesTable(timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Version 2: Ensure timestamp column exists
      try {
        // Check if timestamp column exists
        final columns = await db.rawQuery('PRAGMA table_info($_transportActivitiesTable)');
        final hasTimestamp = columns.any((col) => col['name'] == 'timestamp');
        
        if (!hasTimestamp) {
          // Add timestamp column if missing
          await db.execute('ALTER TABLE $_transportActivitiesTable ADD COLUMN timestamp INTEGER NOT NULL DEFAULT 0');
          
          // Update existing records with current timestamp if they have timestamp 0
          await db.execute('''
            UPDATE $_transportActivitiesTable 
            SET timestamp = ? 
            WHERE timestamp = 0
          ''', [DateTime.now().millisecondsSinceEpoch]);
        }
        
        // Recreate index
        await db.execute('DROP INDEX IF EXISTS idx_transport_timestamp');
        await db.execute('''
          CREATE INDEX idx_transport_timestamp 
          ON $_transportActivitiesTable(timestamp)
        ''');
      } catch (e) {
        print('Migration error, recreating table: $e');
        // If migration fails, recreate the table
        await db.execute('DROP TABLE IF EXISTS $_transportActivitiesTable');
        await _onCreate(db, newVersion);
      }
    }
    
    // Future migrations can be added here
    // if (oldVersion < 3) { ... }
  }

  // Transport Activities CRUD operations

  Future<String> addActivity(TransportActivity activity) async {
    final db = await database;
    
    await db.insert(
      _transportActivitiesTable,
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return activity.id;
  }
  
  // Alias for backward compatibility
  Future<String> insertTransportActivity(TransportActivity activity) async {
    return addActivity(activity);
  }

  Future<List<TransportActivity>> getTransportActivities({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += 'timestamp >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'timestamp <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _transportActivitiesTable,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => TransportActivity.fromMap(map)).toList();
  }

  Future<List<TransportActivity>> getTransportActivitiesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return getTransportActivities(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get transport activities in a specific date range (alias for getTransportActivities)
  Future<List<TransportActivity>> getTransportActivitiesInDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    return getTransportActivities(
      startDate: startDate,
      endDate: endDate,
    );
  }
  
  /// Get activities in date range (CarPlay compatibility)
  Future<List<TransportActivity>> getActivitiesInDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    return getTransportActivities(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<double> getTotalCO2ForDate(DateTime date) async {
    final activities = await getTransportActivitiesForDate(date);
    return activities.fold<double>(0.0, (sum, activity) => sum + activity.co2EmissionKg);
  }

  Future<double> getTotalCO2ForDateRange(DateTime startDate, DateTime endDate) async {
    final activities = await getTransportActivities(
      startDate: startDate,
      endDate: endDate,
    );
    return activities.fold<double>(0.0, (sum, activity) => sum + activity.co2EmissionKg);
  }

  Future<Map<String, double>> getCO2ByTransportType({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final activities = await getTransportActivities(
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, double> result = {};
    for (final activity in activities) {
      final typeName = activity.type.name;
      result[typeName] = (result[typeName] ?? 0.0) + activity.co2EmissionKg;
    }

    return result;
  }

  Future<void> deleteTransportActivity(String id) async {
    final db = await database;
    await db.delete(
      _transportActivitiesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllTransportActivities() async {
    final db = await database;
    await db.delete(_transportActivitiesTable);
  }

  // Database version management
  Future<void> clearAllData() async {
    await deleteAllTransportActivities();
  }
  
  Future<int> getActivityCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_transportActivitiesTable'
    );
    return result.first['count'] as int;
  }

  // Generic activity addition - converts to TransportActivity
  Future<String> addGenericActivity(Map<String, dynamic> activityData) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final type = activityData['type'] as String? ?? 'car';
      final distance = activityData['distance'] as double? ?? 1.0;
      final carbonFootprint = activityData['carbonFootprint'] as double? ?? 0.2;
      final timestamp = activityData['timestamp'] as String? ?? DateTime.now().toIso8601String();
      final source = activityData['source'] as String? ?? 'manual';
      
      // Convert to TransportType
      TransportType transportType;
      if (type.toLowerCase().contains('walk') || type.toLowerCase().contains('yürü')) {
        transportType = TransportType.walking;
      } else if (type.toLowerCase().contains('bike') || type.toLowerCase().contains('bisiklet')) {
        transportType = TransportType.bicycle;
      } else if (type.toLowerCase().contains('bus')) {
        transportType = TransportType.bus;
      } else if (type.toLowerCase().contains('train')) {
        transportType = TransportType.train;
      } else {
        transportType = TransportType.car; // default
      }
      
      final activity = TransportActivity(
        id: id,
        type: transportType,
        distanceKm: distance,
        durationMinutes: (distance * 3).round(), // estimate 3 min per km
        co2EmissionKg: carbonFootprint.abs(),
        timestamp: DateTime.tryParse(timestamp) ?? DateTime.now(),
        notes: 'Added via $source',
      );
      
      return await addActivity(activity);
    } catch (e) {
      print('Error adding activity: $e');
      return '';
    }
  }

  // Get statistics for dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    final yearAgo = DateTime(now.year - 1, now.month, now.day);

    final todayTotal = await getTotalCO2ForDate(today);
    final weekTotal = await getTotalCO2ForDateRange(weekAgo, now);
    final monthTotal = await getTotalCO2ForDateRange(monthAgo, now);
    final yearTotal = await getTotalCO2ForDateRange(yearAgo, now);

    final weeklyAverage = weekTotal / 7;
    final allActivities = await getTransportActivities();
    final totalCarbon = allActivities.fold<double>(0.0, (sum, activity) => sum + activity.co2EmissionKg);

    return {
      'todayTotal': todayTotal,
      'weeklyAverage': weeklyAverage,
      'monthTotal': monthTotal,
      'weekTotal': weekTotal,
      'yearlyTotal': yearTotal,
      'totalCarbon': totalCarbon,
    };
  }

  // Initialize service
  Future<void> initialize() async {
    await database; // This will trigger database creation if needed
  }

  // Get all activities for export
  Future<List<Map<String, dynamic>>> getAllActivities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _transportActivitiesTable,
      orderBy: 'timestamp DESC',
    );
    return maps;
  }
  
  // Get all transport activities as objects
  Future<List<TransportActivity>> getAllTransportActivities() async {
    return await getTransportActivities();
  }
  
  /// Get activity by ID
  Future<Map<String, dynamic>?> getActivityById(int id) async {
    final db = await database;
    final results = await db.query(
      _transportActivitiesTable,
      where: 'id = ?',
      whereArgs: [id.toString()],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// Delete all user data (GDPR compliance)
  Future<void> deleteAllUserData() async {
    final db = await database;
    await db.delete(_transportActivitiesTable);
  }
  
  /// Delete activities before a certain date (data retention)
  Future<void> deleteActivitiesBefore(DateTime cutoffDate) async {
    final db = await database;
    await db.delete(
      _transportActivitiesTable,
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }
  
  /// Get activities by category for GDPR export
  Future<List<Map<String, dynamic>>> getActivitiesByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _transportActivitiesTable,
      where: 'type = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    return maps;
  }
  
  /// Insert activity from external data (for sync/import)
  Future<String> insertActivity(Map<String, dynamic> activityData) async {
    final db = await database;
    
    // Convert generic activity data to TransportActivity format
    final id = activityData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final type = activityData['type']?.toString() ?? 'car';
    final distance = double.tryParse(activityData['amount']?.toString() ?? '0') ?? 0.0;
    final carbonFootprint = double.tryParse(activityData['carbon_footprint']?.toString() ?? '0') ?? 0.0;
    final timestamp = DateTime.tryParse(activityData['date']?.toString() ?? '') ?? DateTime.now();
    
    // Convert to TransportType
    TransportType transportType;
    switch (type.toLowerCase()) {
      case 'walking':
      case 'yürüme':
        transportType = TransportType.walking;
        break;
      case 'bicycle':
      case 'bisiklet':
        transportType = TransportType.bicycle;
        break;
      case 'bus':
      case 'otobüs':
        transportType = TransportType.bus;
        break;
      case 'train':
      case 'tren':
        transportType = TransportType.train;
        break;
      case 'metro':
        transportType = TransportType.metro;
        break;
      default:
        transportType = TransportType.car;
    }
    
    final activity = TransportActivity(
      id: id,
      type: transportType,
      distanceKm: distance,
      durationMinutes: (distance * 3).round(),
      co2EmissionKg: carbonFootprint,
      timestamp: timestamp,
      notes: activityData['description']?.toString() ?? '',
    );
    
    await db.insert(
      _transportActivitiesTable,
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return id;
  }
  
  /// Parse transport type from string
  TransportType _parseTransportType(String typeString) {
    final type = typeString.toLowerCase();
    if (type.contains('walk') || type.contains('yürü')) {
      return TransportType.walking;
    } else if (type.contains('bike') || type.contains('bisiklet')) {
      return TransportType.bicycle;
    } else if (type.contains('bus') || type.contains('otobüs')) {
      return TransportType.bus;
    } else if (type.contains('train') || type.contains('tren') || type.contains('metro')) {
      return TransportType.train;
    } else if (type.contains('taxi')) {
      return TransportType.taxi;
    } else {
      return TransportType.car;
    }
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}