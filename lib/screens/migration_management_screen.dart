import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/migration_service.dart';
import '../services/backup_management_service.dart';
import '../services/error_handler_service.dart';

class MigrationManagementScreen extends StatefulWidget {
  const MigrationManagementScreen({super.key});

  @override
  State<MigrationManagementScreen> createState() => _MigrationManagementScreenState();
}

class _MigrationManagementScreenState extends State<MigrationManagementScreen> {
  final MigrationService _migrationService = MigrationService();
  final BackupManagementService _backupService = BackupManagementService();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  Map<String, dynamic> _systemCompatibility = {};
  Map<String, dynamic> _migrationInfo = {};
  List<MigrationResult> _migrationHistory = [];
  MigrationPlan? _currentMigrationPlan;
  
  bool _isLoading = false;
  bool _isMigrating = false;
  double _migrationProgress = 0.0;
  String _migrationStatus = '';
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _migrationService.initialize();
      await _loadData();
    } catch (e) {
      _showErrorDialog('Failed to initialize migration service: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final compatibility = await _migrationService.checkSystemCompatibility();
      final migrationInfo = _migrationService.getMigrationInfo();
      final history = await _migrationService.getMigrationHistory();
      final migrationPlan = await _migrationService.checkMigrationNeeded();

      setState(() {
        _systemCompatibility = compatibility;
        _migrationInfo = migrationInfo;
        _migrationHistory = history;
        _currentMigrationPlan = migrationPlan;
      });
    } catch (e) {
      _showErrorDialog('Failed to load migration data: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration Manager'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isMigrating) _buildMigrationProgressCard(),
                    if (_isMigrating) const SizedBox(height: 16),
                    _buildSystemStatusCard(),
                    const SizedBox(height: 16),
                    if (_currentMigrationPlan != null) ...[
                      _buildMigrationPlanCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildMigrationInfoCard(),
                    const SizedBox(height: 16),
                    _buildMigrationHistoryCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMigrationProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upgrade, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Migration in Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _migrationProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade700),
            ),
            const SizedBox(height: 8),
            Text(_migrationStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    final isCompatible = !(_systemCompatibility['migration_needed'] ?? false);
    final currentVersion = _systemCompatibility['current_version'] ?? 'Unknown';
    final targetVersion = _systemCompatibility['target_version'] ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompatible ? Icons.check_circle : Icons.warning,
                  color: isCompatible ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompatible ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompatible ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildStatusRow('Current Version', currentVersion),
                  _buildStatusRow('Target Version', targetVersion),
                  _buildStatusRow(
                    'Status',
                    isCompatible ? 'Up to Date' : 'Migration Required',
                  ),
                  if (!isCompatible) ...[
                    _buildStatusRow(
                      'Migration Steps',
                      '${_systemCompatibility['migration_steps'] ?? 0}',
                    ),
                    _buildStatusRow(
                      'Requires Backup',
                      _systemCompatibility['requires_backup'] == true ? 'Yes' : 'No',
                    ),
                    _buildStatusRow(
                      'Can Rollback',
                      _systemCompatibility['can_rollback'] == true ? 'Yes' : 'No',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationPlanCard() {
    final plan = _currentMigrationPlan!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Migration Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Migration: ${plan.fromVersion} → ${plan.toVersion}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Steps: ${plan.steps.length}'),
                  Text('Estimated Duration: ${_formatDuration(plan.estimatedDuration)}'),
                  Text('Requires Backup: ${plan.requiresBackup ? 'Yes' : 'No'}'),
                  Text('Can Rollback: ${plan.canRollback ? 'Yes' : 'No'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Migration Steps:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...plan.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return _buildMigrationStepTile(step, index + 1);
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMigrating ? null : () => _executeMigration(plan),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Execute Migration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (plan.requiresBackup) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isMigrating ? null : _createBackupBeforeMigration,
                      icon: const Icon(Icons.backup),
                      label: const Text('Backup First'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationStepTile(MigrationStep step, int stepNumber) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getMigrationTypeColor(step.type),
          child: Text(
            '$stepNumber',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          step.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(step.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              step.isReversible ? Icons.undo : Icons.lock,
              size: 16,
              color: step.isReversible ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              step.type.toString().split('.').last,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Migration Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_migrationInfo.isNotEmpty) ...[
              _buildInfoRow('Current Version', _migrationInfo['current_version'] ?? 'Unknown'),
              _buildInfoRow('Registered Steps', '${_migrationInfo['registered_steps'] ?? 0}'),
              _buildInfoRow('Migration Types', '${(_migrationInfo['migration_types'] as List?)?.length ?? 0}'),
              _buildInfoRow('Available Versions', '${(_migrationInfo['available_versions'] as List?)?.length ?? 0}'),
            ] else
              const Text(
                'No migration information available',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Migration History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_migrationHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(24.0),
                child: const Column(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No migration history',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _migrationHistory.length > 10 ? 10 : _migrationHistory.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final result = _migrationHistory[index];
                  return _buildMigrationHistoryTile(result);
                },
              ),
            if (_migrationHistory.length > 10)
              TextButton(
                onPressed: _showFullHistory,
                child: Text('View All (${_migrationHistory.length} total)'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationHistoryTile(MigrationResult result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getMigrationStatusColor(result.status),
        child: Icon(
          _getMigrationStatusIcon(result.status),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        result.stepId,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDateTime(result.startTime)),
          if (result.duration != null)
            Text('Duration: ${_formatDuration(result.duration!)}'),
          if (result.errorMessage != null)
            Text(
              'Error: ${result.errorMessage!}',
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Color _getMigrationTypeColor(MigrationType type) {
    switch (type) {
      case MigrationType.schemaUpdate:
        return Colors.blue;
      case MigrationType.dataTransformation:
        return Colors.orange;
      case MigrationType.versionUpgrade:
        return Colors.green;
      case MigrationType.formatConversion:
        return Colors.purple;
    }
  }

  Color _getMigrationStatusColor(MigrationStatus status) {
    switch (status) {
      case MigrationStatus.completed:
        return Colors.green;
      case MigrationStatus.failed:
        return Colors.red;
      case MigrationStatus.inProgress:
        return Colors.blue;
      case MigrationStatus.pending:
        return Colors.orange;
      case MigrationStatus.skipped:
        return Colors.grey;
    }
  }

  IconData _getMigrationStatusIcon(MigrationStatus status) {
    switch (status) {
      case MigrationStatus.completed:
        return Icons.check;
      case MigrationStatus.failed:
        return Icons.error;
      case MigrationStatus.inProgress:
        return Icons.hourglass_empty;
      case MigrationStatus.pending:
        return Icons.schedule;
      case MigrationStatus.skipped:
        return Icons.skip_next;
    }
  }

  Future<void> _executeMigration(MigrationPlan plan) async {
    final confirmed = await _showConfirmDialog(
      'Execute Migration',
      'Are you sure you want to execute the migration from ${plan.fromVersion} to ${plan.toVersion}?\n\n'
      'This will apply ${plan.steps.length} migration steps and may take several minutes.\n\n'
      '${plan.requiresBackup ? 'Warning: It is recommended to create a backup before proceeding.' : ''}',
    );

    if (!confirmed) return;

    setState(() {
      _isMigrating = true;
      _migrationProgress = 0.0;
      _migrationStatus = 'Preparing migration...';
    });

    try {
      final results = await _migrationService.executeMigrationPlan(
        plan,
        onProgress: (progress, status) {
          setState(() {
            _migrationProgress = progress;
            _migrationStatus = status;
          });
        },
      );

      final success = results.every((r) => r.status == MigrationStatus.completed);

      if (success) {
        _showSuccessDialog(
          'Migration Completed',
          'All migration steps have been executed successfully.',
        );
      } else {
        final failedSteps = results.where((r) => r.status == MigrationStatus.failed).length;
        _showErrorDialog(
          'Migration completed with $failedSteps failed steps. Please check the migration history for details.',
        );
      }

      await _loadData();

    } catch (e) {
      _showErrorDialog('Migration failed: ${e.toString()}');
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _createBackupBeforeMigration() async {
    try {
      setState(() {
        _isMigrating = true;
        _migrationProgress = 0.0;
        _migrationStatus = 'Creating backup before migration...';
      });

      await _backupService.createBackup(
        name: 'Pre-Migration Backup ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        onProgress: (progress, status) {
          setState(() {
            _migrationProgress = progress * 0.5; // Use first half of progress for backup
            _migrationStatus = status;
          });
        },
      );

      _showSuccessDialog(
        'Backup Created',
        'A backup has been created successfully. You can now proceed with the migration.',
      );

    } catch (e) {
      _showErrorDialog('Failed to create backup: ${e.toString()}');
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  void _showFullHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Migration History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _migrationHistory.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final result = _migrationHistory[index];
              return _buildMigrationHistoryTile(result);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Execute'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}