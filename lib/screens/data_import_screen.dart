import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/advanced_import_service.dart';
import '../services/error_handler_service.dart';
import '../l10n/app_localizations.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  final AdvancedImportService _importService = AdvancedImportService();
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  ImportFormat _selectedFormat = ImportFormat.json;
  ImportConflictResolution _conflictResolution = ImportConflictResolution.skip;
  String? _selectedFilePath;
  ImportResult? _lastResult;
  bool _isImporting = false;
  bool _isValidating = false;
  double _importProgress = 0.0;
  String _importStatus = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFileSelectionCard(),
            const SizedBox(height: 16),
            _buildFormatSelectionCard(),
            const SizedBox(height: 16),
            _buildConflictResolutionCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
            if (_isImporting || _isValidating) _buildProgressCard(),
            if (_lastResult != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Select File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedFilePath != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFilePath!.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedFilePath = null;
                          _lastResult = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Text(
                    'No file selected',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _selectFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Import Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ImportFormat.values.map((format) {
              return RadioListTile<ImportFormat>(
                title: Text(_getFormatDisplayName(format)),
                subtitle: Text(_getFormatDescription(format)),
                value: format,
                groupValue: _selectedFormat,
                activeColor: Colors.green.shade700,
                onChanged: (value) {
                  setState(() {
                    _selectedFormat = value!;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictResolutionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.merge_type, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Conflict Resolution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ImportConflictResolution.values.map((resolution) {
              return RadioListTile<ImportConflictResolution>(
                title: Text(_getConflictResolutionDisplayName(resolution)),
                subtitle: Text(_getConflictResolutionDescription(resolution)),
                value: resolution,
                groupValue: _conflictResolution,
                activeColor: Colors.orange.shade700,
                onChanged: (value) {
                  setState(() {
                    _conflictResolution = value!;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final canValidate = _selectedFilePath != null && !_isImporting && !_isValidating;
    final canImport = _selectedFilePath != null && !_isImporting && !_isValidating;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canValidate ? _validateFile : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Validate Only'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canImport ? _importFile : null,
            icon: const Icon(Icons.download),
            label: const Text('Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isValidating ? Icons.check_circle_outline : Icons.download,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _isValidating ? 'Validating...' : 'Importing...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _importProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
            const SizedBox(height: 8),
            Text(_importStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_lastResult == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastResult!.isSuccessful ? Icons.check_circle : Icons.warning,
                  color: _lastResult!.isSuccessful ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Import Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildResultSummary(),
            if (_lastResult!.validations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildValidationResults(),
            ],
            if (_lastResult!.conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildConflictResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSummary() {
    final result = _lastResult!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isSuccessful ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.isSuccessful ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Records:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${result.totalRecords}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Imported:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${result.importedRecords}', style: const TextStyle(color: Colors.green)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Skipped:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${result.skippedRecords}', style: const TextStyle(color: Colors.orange)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Errors:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${result.errorRecords}', style: const TextStyle(color: Colors.red)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Success Rate:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${(result.successRate * 100).toStringAsFixed(1)}%'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Processing Time:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('${result.processingTime.inMilliseconds}ms'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResults() {
    final validations = _lastResult!.validations;
    final errors = validations.where((v) => v.hasError).toList();
    final warnings = validations.where((v) => v.hasWarning).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Validation Issues',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (errors.isNotEmpty) ...[
          Text(
            'Errors (${errors.length}):',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
          ...errors.take(5).map((validation) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Line ${validation.lineNumber}: ${validation.message}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
          if (errors.length > 5)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                '... and ${errors.length - 5} more errors',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Warnings (${warnings.length}):',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
          ),
          ...warnings.take(3).map((validation) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Line ${validation.lineNumber}: ${validation.message}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
          if (warnings.length > 3)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Text(
                '... and ${warnings.length - 3} more warnings',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildConflictResults() {
    final conflicts = _lastResult!.conflicts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conflicts Found (${conflicts.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...conflicts.take(3).map((conflict) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  conflict.conflictReason,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
        if (conflicts.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              '... and ${conflicts.length - 3} more conflicts',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path!;
          _lastResult = null;
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to select file: ${e.toString()}');
    }
  }

  Future<void> _validateFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isValidating = true;
      _importProgress = 0.0;
      _importStatus = 'Starting validation...';
    });

    try {
      final result = await _importService.importData(
        filePath: _selectedFilePath!,
        format: _selectedFormat,
        validateOnly: true,
        onProgress: (progress, status) {
          setState(() {
            _importProgress = progress;
            _importStatus = status;
          });
        },
      );

      setState(() {
        _lastResult = result;
        _isValidating = false;
      });

      if (result.hasErrors) {
        _showResultDialog(
          'Validation Failed',
          '${result.errorRecords} errors found in ${result.totalRecords} records.',
          isError: true,
        );
      } else {
        _showResultDialog(
          'Validation Successful',
          'All ${result.totalRecords} records are valid and ready for import.',
          isError: false,
        );
      }

    } catch (e) {
      setState(() {
        _isValidating = false;
      });
      _showErrorDialog('Validation failed: ${e.toString()}');
    }
  }

  Future<void> _importFile() async {
    if (_selectedFilePath == null) return;

    final confirmed = await _showConfirmDialog(
      'Confirm Import',
      'Are you sure you want to import data from this file? This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = 'Starting import...';
    });

    try {
      final result = await _importService.importData(
        filePath: _selectedFilePath!,
        format: _selectedFormat,
        conflictResolution: _conflictResolution,
        validateOnly: false,
        onProgress: (progress, status) {
          setState(() {
            _importProgress = progress;
            _importStatus = status;
          });
        },
      );

      setState(() {
        _lastResult = result;
        _isImporting = false;
      });

      _showResultDialog(
        AppLocalizations.of(context)!.translate('import.importCompleteTitle'),
        AppLocalizations.of(context)!.translate('import.success'),
        isError: result.hasErrors,
      );

    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      _showErrorDialog('Import failed: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.translate('common.error')),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.ok')),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(String title, String message, {required bool isError}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.warning : Icons.check_circle,
              color: isError ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.ok')),
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
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _getFormatDisplayName(ImportFormat format) {
    switch (format) {
      case ImportFormat.json:
        return 'JSON Format';
      case ImportFormat.csv:
        return 'CSV Format';
      case ImportFormat.carbonTracker:
        return 'Carbon Tracker Format';
    }
  }

  String _getFormatDescription(ImportFormat format) {
    switch (format) {
      case ImportFormat.json:
        return 'JavaScript Object Notation - structured data format';
      case ImportFormat.csv:
        return 'Comma Separated Values - spreadsheet compatible';
      case ImportFormat.carbonTracker:
        return 'Native Carbon Tracker export format';
    }
  }

  String _getConflictResolutionDisplayName(ImportConflictResolution resolution) {
    switch (resolution) {
      case ImportConflictResolution.skip:
        return 'Skip Conflicts';
      case ImportConflictResolution.overwrite:
        return 'Overwrite Existing';
      case ImportConflictResolution.keepBoth:
        return 'Keep Both Records';
      case ImportConflictResolution.merge:
        return 'Merge Records';
    }
  }

  String _getConflictResolutionDescription(ImportConflictResolution resolution) {
    switch (resolution) {
      case ImportConflictResolution.skip:
        return 'Skip importing records that conflict with existing data';
      case ImportConflictResolution.overwrite:
        return 'Replace existing records with imported data';
      case ImportConflictResolution.keepBoth:
        return 'Keep both existing and imported records';
      case ImportConflictResolution.merge:
        return 'Combine data from existing and imported records';
    }
  }
}