import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transport_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'carbon_tracker.db';
  static const int _databaseVersion = 1;

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
        transport_type_id TEXT NOT NULL,
        distance_km REAL NOT NULL,
        co2_emission REAL NOT NULL,
        created_at INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // Create indices for better performance
    await db.execute('''
      CREATE INDEX idx_transport_created_at 
      ON $_transportActivitiesTable(created_at)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    // For now, we'll just recreate the tables
    if (oldVersion < newVersion) {
      await db.execute('DROP TABLE IF EXISTS $_transportActivitiesTable');
      await _onCreate(db, newVersion);
    }
  }

  // Transport Activities CRUD operations

  Future<String> insertTransportActivity(TransportActivity activity) async {
    final db = await database;
    
    await db.insert(
      _transportActivitiesTable,
      {
        'id': activity.id,
        'transport_type_id': activity.transportType.id,
        'distance_km': activity.distanceKm,
        'co2_emission': activity.co2Emission,
        'created_at': activity.createdAt.millisecondsSinceEpoch,
        'notes': activity.notes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return activity.id;
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
      whereClause += 'created_at >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'created_at <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _transportActivitiesTable,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => _mapToTransportActivity(map)).toList();
  }

  Future<List<TransportActivity>> getTransportActivitiesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return getTransportActivities(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  Future<double> getTotalCO2ForDate(DateTime date) async {
    final activities = await getTransportActivitiesForDate(date);
    return activities.fold<double>(0.0, (sum, activity) => sum + activity.co2Emission);
  }

  Future<double> getTotalCO2ForDateRange(DateTime startDate, DateTime endDate) async {
    final activities = await getTransportActivities(
      startDate: startDate,
      endDate: endDate,
    );
    return activities.fold<double>(0.0, (sum, activity) => sum + activity.co2Emission);
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
      final typeName = activity.transportType.name;
      result[typeName] = (result[typeName] ?? 0.0) + activity.co2Emission;
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

  TransportActivity _mapToTransportActivity(Map<String, dynamic> map) {
    final transportType = TransportData.getTransportTypeById(map['transport_type_id']);
    
    if (transportType == null) {
      throw Exception('Transport type not found: ${map['transport_type_id']}');
    }

    return TransportActivity(
      id: map['id'],
      transportType: transportType,
      distanceKm: map['distance_km'],
      co2Emission: map['co2_emission'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      notes: map['notes'],
    );
  }

  // Get statistics for dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    final todayTotal = await getTotalCO2ForDate(today);
    final weekTotal = await getTotalCO2ForDateRange(weekAgo, now);
    final monthTotal = await getTotalCO2ForDateRange(monthAgo, now);

    final weeklyAverage = weekTotal / 7;

    return {
      'todayTotal': todayTotal,
      'weeklyAverage': weeklyAverage,
      'monthTotal': monthTotal,
      'weekTotal': weekTotal,
    };
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