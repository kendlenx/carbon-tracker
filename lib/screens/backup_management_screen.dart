import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_management_service.dart';
import '../services/error_handler_service.dart';

class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  final BackupManagementService _backupService = BackupManagementService();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  List<BackupMetadata> _backups = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  bool _isCreatingBackup = false;
  bool _isRestoringBackup = false;
  double _operationProgress = 0.0;
  String _operationStatus = '';

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingBackup ? null : () => _showCreateBackupDialog(),
        icon: const Icon(Icons.backup),
        label: const Text('Create Backup'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isCreatingBackup || _isRestoringBackup)
                      _buildOperationProgressCard(),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(),
                    const SizedBox(height: 16),
                    _buildBackupsListCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOperationProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isCreatingBackup ? Icons.backup : Icons.restore,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCreatingBackup ? 'Creating Backup...' : 'Restoring Backup...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _operationProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
            const SizedBox(height: 8),
            Text(_operationStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
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
                  'Backup Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_statistics.isNotEmpty) ...[
              _buildStatisticRow(
                'Total Backups',
                '${_statistics['total_backups'] ?? 0}',
                Icons.folder_special,
              ),
              _buildStatisticRow(
                'Total Size',
                _formatBytes(_statistics['total_size_bytes'] ?? 0),
                Icons.storage,
              ),
              _buildStatisticRow(
                'Total Records',
                '${_statistics['total_records'] ?? 0}',
                Icons.list_alt,
              ),
              if (_statistics['last_backup_date'] != null)
                _buildStatisticRow(
                  'Last Backup',
                  _formatDate(_statistics['last_backup_date']),
                  Icons.schedule,
                ),
            ] else
              const Text(
                'No statistics available',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
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
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Backup History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_backups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24.0),
                child: const Column(
                  children: [
                    Icon(
                      Icons.backup_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No backups found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create your first backup to get started',
                      style: TextStyle(
                        fontSize: 12,
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
                itemCount: _backups.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final backup = _backups[index];
                  return _buildBackupTile(backup);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTile(BackupMetadata backup) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getBackupTypeColor(backup.type),
        child: Icon(
          _getBackupTypeIcon(backup.type),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        backup.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDate(backup.createdAt.toIso8601String())),
          Text(
            '${backup.recordCount} records • ${backup.displaySize}',
            style: const TextStyle(fontSize: 12),
          ),
          if (backup.restoredAt != null)
            Text(
              'Restored: ${_formatDate(backup.restoredAt!.toIso8601String())}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleBackupAction(value, backup),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'restore',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restore),
                SizedBox(width: 8),
                Text('Restore'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'verify',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified),
                SizedBox(width: 8),
                Text('Verify'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'details',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info),
                SizedBox(width: 8),
                Text('Details'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackupTypeColor(BackupType type) {
    switch (type) {
      case BackupType.full:
        return Colors.green;
      case BackupType.incremental:
        return Colors.blue;
      case BackupType.differential:
        return Colors.orange;
    }
  }

  IconData _getBackupTypeIcon(BackupType type) {
    switch (type) {
      case BackupType.full:
        return Icons.backup;
      case BackupType.incremental:
        return Icons.add_to_drive;
      case BackupType.differential:
        return Icons.difference;
    }
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backups = await _backupService.getAllBackups();
      setState(() {
        _backups = backups;
      });
    } catch (e) {
      _showErrorDialog('Failed to load backups: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final statistics = await _backupService.getBackupStatistics();
      setState(() {
        _statistics = statistics;
      });
    } catch (e) {
      // Statistics are not critical, just log the error
      _errorHandler.recordError(e, null, severity: ErrorSeverity.low);
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadBackups(),
      _loadStatistics(),
    ]);
  }

  void _showCreateBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateBackupDialog(
        onBackupCreated: _createBackup,
        availableBackups: _backups,
      ),
    );
  }

  Future<void> _createBackup({
    required String name,
    required BackupType type,
    String? parentBackupId,
  }) async {
    setState(() {
      _isCreatingBackup = true;
      _operationProgress = 0.0;
      _operationStatus = 'Initializing...';
    });

    try {
      await _backupService.createBackup(
        name: name.isEmpty ? null : name,
        type: type,
        parentBackupId: parentBackupId,
        onProgress: (progress, status) {
          setState(() {
            _operationProgress = progress;
            _operationStatus = status;
          });
        },
      );

      _showSuccessDialog('Backup Created', 'Backup "$name" has been created successfully.');
      await _refreshData();

    } catch (e) {
      _showErrorDialog('Failed to create backup: ${e.toString()}');
    } finally {
      setState(() {
        _isCreatingBackup = false;
      });
    }
  }

  Future<void> _handleBackupAction(String action, BackupMetadata backup) async {
    switch (action) {
      case 'restore':
        _showRestoreDialog(backup);
        break;
      case 'verify':
        _verifyBackup(backup);
        break;
      case 'details':
        _showBackupDetails(backup);
        break;
      case 'delete':
        _confirmDeleteBackup(backup);
        break;
    }
  }

  void _showRestoreDialog(BackupMetadata backup) {
    showDialog(
      context: context,
      builder: (context) => _RestoreBackupDialog(
        backup: backup,
        onRestoreConfirmed: _restoreBackup,
      ),
    );
  }

  Future<void> _restoreBackup(BackupMetadata backup, RestoreStrategy strategy) async {
    setState(() {
      _isRestoringBackup = true;
      _operationProgress = 0.0;
      _operationStatus = 'Initializing restore...';
    });

    try {
      final result = await _backupService.restoreBackup(
        backupId: backup.id,
        strategy: strategy,
        onProgress: (progress, status) {
          setState(() {
            _operationProgress = progress;
            _operationStatus = status;
          });
        },
      );

      if (result.success) {
        _showSuccessDialog(
          'Restore Complete',
          'Successfully restored ${result.restoredRecords} records from "${backup.name}".',
        );
      } else {
        _showErrorDialog(
          'Restore completed with errors: ${result.errorRecords} errors occurred.',
        );
      }

      await _refreshData();

    } catch (e) {
      _showErrorDialog('Failed to restore backup: ${e.toString()}');
    } finally {
      setState(() {
        _isRestoringBackup = false;
      });
    }
  }

  Future<void> _verifyBackup(BackupMetadata backup) async {
    try {
      final isValid = await _backupService.verifyBackup(backup.id);
      
      if (isValid) {
        _showSuccessDialog(
          'Backup Verified',
          'The backup "${backup.name}" is valid and intact.',
        );
      } else {
        _showErrorDialog(
          'The backup "${backup.name}" is corrupted or missing.',
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to verify backup: ${e.toString()}');
    }
  }

  void _showBackupDetails(BackupMetadata backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Backup Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', backup.name),
              _buildDetailRow('Type', backup.type.toString().split('.').last),
              _buildDetailRow('Status', backup.status.toString().split('.').last),
              _buildDetailRow('Created', _formatDate(backup.createdAt.toIso8601String())),
              if (backup.restoredAt != null)
                _buildDetailRow('Restored', _formatDate(backup.restoredAt!.toIso8601String())),
              _buildDetailRow('Records', '${backup.recordCount}'),
              _buildDetailRow('Size', backup.displaySize),
              _buildDetailRow('Version', backup.version),
              if (backup.parentBackupId != null)
                _buildDetailRow('Parent Backup', backup.parentBackupId!),
              _buildDetailRow('File Path', backup.filePath),
              _buildDetailRow('Checksum', backup.checksum),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text(
          'Are you sure you want to delete the backup "${backup.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _backupService.deleteBackup(backup.id);
        _showSuccessDialog('Backup Deleted', 'The backup has been deleted successfully.');
        await _refreshData();
      } catch (e) {
        _showErrorDialog('Failed to delete backup: ${e.toString()}');
      }
    }
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class _CreateBackupDialog extends StatefulWidget {
  final Function({
    required String name,
    required BackupType type,
    String? parentBackupId,
  }) onBackupCreated;
  final List<BackupMetadata> availableBackups;

  const _CreateBackupDialog({
    required this.onBackupCreated,
    required this.availableBackups,
  });

  @override
  State<_CreateBackupDialog> createState() => _CreateBackupDialogState();
}

class _CreateBackupDialogState extends State<_CreateBackupDialog> {
  final _nameController = TextEditingController();
  BackupType _selectedType = BackupType.full;
  String? _selectedParentBackupId;

  @override
  Widget build(BuildContext context) {
    final fullBackups = widget.availableBackups
        .where((b) => b.type == BackupType.full)
        .toList();

    return AlertDialog(
      title: const Text('Create New Backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Backup Name (Optional)',
                hintText: 'Leave empty for auto-generated name',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BackupType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Backup Type',
              ),
              items: BackupType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getBackupTypeName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  if (_selectedType == BackupType.full) {
                    _selectedParentBackupId = null;
                  }
                });
              },
            ),
            if (_selectedType != BackupType.full) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedParentBackupId,
                decoration: const InputDecoration(
                  labelText: 'Parent Backup',
                ),
                items: fullBackups.map((backup) {
                  return DropdownMenuItem(
                    value: backup.id,
                    child: Text(backup.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedParentBackupId = value;
                  });
                },
                validator: (value) {
                  if (_selectedType != BackupType.full && value == null) {
                    return 'Please select a parent backup';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedType != BackupType.full && _selectedParentBackupId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a parent backup for incremental/differential backups'),
                ),
              );
              return;
            }

            Navigator.of(context).pop();
            widget.onBackupCreated(
              name: _nameController.text,
              type: _selectedType,
              parentBackupId: _selectedParentBackupId,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  String _getBackupTypeName(BackupType type) {
    switch (type) {
      case BackupType.full:
        return 'Full Backup';
      case BackupType.incremental:
        return 'Incremental Backup';
      case BackupType.differential:
        return 'Differential Backup';
    }
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  final BackupMetadata backup;
  final Function(BackupMetadata backup, RestoreStrategy strategy) onRestoreConfirmed;

  const _RestoreBackupDialog({
    required this.backup,
    required this.onRestoreConfirmed,
  });

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  RestoreStrategy _selectedStrategy = RestoreStrategy.mergeWithExisting;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Restore "${widget.backup.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This backup contains ${widget.backup.recordCount} records. Choose how to restore:',
          ),
          const SizedBox(height: 16),
          ...RestoreStrategy.values.map((strategy) {
            return RadioListTile<RestoreStrategy>(
              title: Text(_getStrategyName(strategy)),
              subtitle: Text(_getStrategyDescription(strategy)),
              value: strategy,
              groupValue: _selectedStrategy,
              onChanged: (value) {
                setState(() {
                  _selectedStrategy = value!;
                });
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRestoreConfirmed(widget.backup, _selectedStrategy);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Restore'),
        ),
      ],
    );
  }

  String _getStrategyName(RestoreStrategy strategy) {
    switch (strategy) {
      case RestoreStrategy.replaceAll:
        return 'Replace All Data';
      case RestoreStrategy.mergeWithExisting:
        return 'Merge with Existing';
      case RestoreStrategy.restoreOnlyMissing:
        return 'Restore Only Missing';
    }
  }

  String _getStrategyDescription(RestoreStrategy strategy) {
    switch (strategy) {
      case RestoreStrategy.replaceAll:
        return 'Remove all current data and replace with backup data';
      case RestoreStrategy.mergeWithExisting:
        return 'Add backup data, skip records that already exist';
      case RestoreStrategy.restoreOnlyMissing:
        return 'Only restore records that don\'t exist in current data';
    }
  }
}