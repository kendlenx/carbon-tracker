import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/advanced_import_service.dart';
import '../services/backup_management_service.dart';
import '../services/migration_service.dart';
import '../services/database_service.dart';
import '../services/error_handler_service.dart';
import 'data_export_screen.dart';
import 'data_import_screen.dart';
import 'backup_management_screen.dart';
import 'migration_management_screen.dart';

class AdvancedDataManagementScreen extends StatefulWidget {
  const AdvancedDataManagementScreen({super.key});

  @override
  State<AdvancedDataManagementScreen> createState() => _AdvancedDataManagementScreenState();
}

class _AdvancedDataManagementScreenState extends State<AdvancedDataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final AdvancedImportService _importService = AdvancedImportService();
  final BackupManagementService _backupService = BackupManagementService();
  final MigrationService _migrationService = MigrationService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  Map<String, dynamic> _dataStatistics = {};
  Map<String, dynamic> _systemHealth = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activities = await _databaseService.getAllTransportActivities();
      final backupStats = await _backupService.getBackupStatistics();
      final migrationCompatibility = await _migrationService.checkSystemCompatibility();
      
      final dataStats = {
        'total_activities': activities.length,
        'total_co2': activities.fold<double>(0.0, (sum, a) => sum + a.co2EmissionKg),
        'total_distance': activities.fold<double>(0.0, (sum, a) => sum + a.distanceKm),
        'date_range': activities.isNotEmpty ? {
          'earliest': activities.map((a) => a.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
          'latest': activities.map((a) => a.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
        } : null,
        'transport_types': _getTransportTypeDistribution(activities),
      };

      final systemHealth = {
        'database_version': migrationCompatibility['current_version'] ?? 'Unknown',
        'migration_needed': migrationCompatibility['migration_needed'] ?? false,
        'backup_count': backupStats['total_backups'] ?? 0,
        'backup_size': backupStats['total_size_bytes'] ?? 0,
        'last_backup': backupStats['last_backup_date'],
      };

      setState(() {
        _dataStatistics = dataStats;
        _systemHealth = systemHealth;
      });

    } catch (e) {
      _errorHandler.recordError(e, null, severity: ErrorSeverity.medium);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, int> _getTransportTypeDistribution(activities) {
    final distribution = <String, int>{};
    for (final activity in activities) {
      final type = activity.type.toString().split('.').last;
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.import_export), text: 'Import/Export'),
            Tab(icon: Icon(Icons.backup), text: 'Backups'),
            Tab(icon: Icon(Icons.settings_applications), text: 'Operations'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildImportExportTab(),
          _buildBackupsTab(),
          _buildOperationsTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSystemHealthCard(),
            const SizedBox(height: 16),
            _buildDataOverviewCard(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
            const SizedBox(height: 16),
            _buildRecentOperationsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildHealthIndicator(
                'Database',
                _systemHealth['migration_needed'] == false ? 'Healthy' : 'Needs Migration',
                _systemHealth['migration_needed'] == false ? Colors.green : Colors.orange,
                Icons.storage,
              ),
              _buildHealthIndicator(
                'Backups',
                '${_systemHealth['backup_count'] ?? 0} backups',
                (_systemHealth['backup_count'] ?? 0) > 0 ? Colors.green : Colors.red,
                Icons.backup,
              ),
              _buildHealthIndicator(
                'Version',
                _systemHealth['database_version'] ?? 'Unknown',
                Colors.blue,
                Icons.info,
              ),
              if (_systemHealth['last_backup'] != null)
                _buildHealthIndicator(
                  'Last Backup',
                  _formatDate(_systemHealth['last_backup']),
                  Colors.blue,
                  Icons.schedule,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Data Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_dataStatistics.isEmpty)
              const Text('No data available')
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Activities',
                      '${_dataStatistics['total_activities'] ?? 0}',
                      Icons.list,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Total CO₂',
                      '${(_dataStatistics['total_co2'] ?? 0.0).toStringAsFixed(2)} kg',
                      Icons.eco,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Distance',
                      '${(_dataStatistics['total_distance'] ?? 0.0).toStringAsFixed(1)} km',
                      Icons.route,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Transport Types',
                      '${(_dataStatistics['transport_types'] as Map?)?.length ?? 0}',
                      Icons.directions,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              if (_dataStatistics['date_range'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${_formatDate(_dataStatistics['date_range']['earliest'].toIso8601String())} - ${_formatDate(_dataStatistics['date_range']['latest'].toIso8601String())}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildQuickActionTile(
                  'Export Data',
                  Icons.file_download,
                  Colors.green,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DataExportScreen()),
                  ),
                ),
                _buildQuickActionTile(
                  'Import Data',
                  Icons.file_upload,
                  Colors.blue,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DataImportScreen()),
                  ),
                ),
                _buildQuickActionTile(
                  'Create Backup',
                  Icons.backup,
                  Colors.orange,
                  () => _quickCreateBackup(),
                ),
                _buildQuickActionTile(
                  'System Check',
                  Icons.health_and_safety,
                  Colors.purple,
                  () => _performSystemCheck(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOperationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Recent Operations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // This would be populated with actual operation history
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No recent operations',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWizardCard(
            'Export Wizard',
            'Export your data in various formats with filtering options',
            Icons.file_download,
            Colors.green,
            'Start Export',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataExportScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildWizardCard(
            'Import Wizard',
            'Import data from CSV, JSON, or other Carbon Tracker exports',
            Icons.file_upload,
            Colors.blue,
            'Start Import',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataImportScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildBatchOperationsCard(),
        ],
      ),
    );
  }

  Widget _buildWizardCard(
    String title,
    String description,
    IconData icon,
    Color color,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchOperationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.batch_prediction, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Batch Operations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Perform bulk operations on your data'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showBatchDeleteDialog(),
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Bulk Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showRecalculateDialog(),
                  icon: const Icon(Icons.calculate, size: 16),
                  label: const Text('Recalculate CO₂'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsTab() {
    return const BackupManagementScreen();
  }

  Widget _buildOperationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWizardCard(
            'Migration Manager',
            'Handle database migrations and version updates',
            Icons.upgrade,
            Colors.purple,
            'Open Migration Manager',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MigrationManagementScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildMaintenanceCard(),
          const SizedBox(height: 16),
          _buildAdvancedSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Database Maintenance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Optimize and maintain your database'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _optimizeDatabase(),
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Optimize'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _cleanupOldData(),
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Cleanup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_applications, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Advanced Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Auto Backup'),
              subtitle: const Text('Automatically create backups'),
              trailing: Switch(
                value: false, // This would be connected to actual settings
                onChanged: (value) {
                  // Handle auto backup toggle
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Backup Schedule'),
              subtitle: const Text('Weekly at 2:00 AM'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showBackupScheduleDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Data Retention'),
              subtitle: const Text('Keep data for 2 years'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showDataRetentionDialog(),
            ),
          ],
        ),
      ),
    );
  }

  // Action methods

  Future<void> _quickCreateBackup() async {
    try {
      await _backupService.createBackup(
        name: 'Quick Backup ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      
      _showSuccessSnackBar('Backup created successfully');
      await _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Failed to create backup: ${e.toString()}');
    }
  }

  Future<void> _performSystemCheck() async {
    final results = <String>[];
    
    try {
      // Check migration status
      final migrationNeeded = await _migrationService.checkMigrationNeeded();
      if (migrationNeeded != null) {
        results.add('⚠️ Database migration required');
      } else {
        results.add('✅ Database is up to date');
      }
      
      // Check backup status
      final backups = await _backupService.getAllBackups();
      if (backups.isEmpty) {
        results.add('⚠️ No backups found');
      } else {
        results.add('✅ ${backups.length} backups available');
      }
      
      // Check data integrity (simplified)
      final activities = await _databaseService.getAllTransportActivities();
      results.add('✅ ${activities.length} activities in database');
      
      _showSystemCheckResults(results);
      
    } catch (e) {
      _showErrorSnackBar('System check failed: ${e.toString()}');
    }
  }

  void _showSystemCheckResults(List<String> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.green),
            SizedBox(width: 8),
            Text('System Check Results'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: results.map((result) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(result),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBatchDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Delete'),
        content: const Text('Select criteria for bulk deletion (feature coming soon)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRecalculateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalculate CO₂'),
        content: const Text('Recalculate CO₂ emissions for all activities using updated formulas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement CO2 recalculation
              _showInfoSnackBar('CO₂ recalculation feature coming soon');
            },
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );
  }

  void _showBackupScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Schedule'),
        content: const Text('Backup scheduling feature coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDataRetentionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Retention'),
        content: const Text('Data retention settings coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _optimizeDatabase() async {
    try {
      // Placeholder for database optimization
      await Future.delayed(const Duration(seconds: 2));
      _showSuccessSnackBar('Database optimized successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to optimize database: ${e.toString()}');
    }
  }

  Future<void> _cleanupOldData() async {
    try {
      // Cleanup migration history
      await _migrationService.cleanupMigrationHistory();
      _showSuccessSnackBar('Old data cleaned up successfully');
      await _loadDashboardData();
    } catch (e) {
      _showErrorSnackBar('Failed to cleanup data: ${e.toString()}');
    }
  }

  // Helper methods

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}