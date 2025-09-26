import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/advanced_export_service.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({Key? key}) : super(key: key);

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final AdvancedExportService _exportService = AdvancedExportService();

  ExportFormat _selectedFormat = ExportFormat.json;
  ExportScope _selectedScope = ExportScope.all;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeUserPrefs = false;
  bool _includeSystemData = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFormatSelectionCard(),
            const SizedBox(height: 16),
            _buildScopeSelectionCard(),
            const SizedBox(height: 16),
            _buildOptionsCard(),
            const SizedBox(height: 16),
            if (_isExporting) _buildProgressCard(),
            const Spacer(),
            _buildExportButton(),
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
                Icon(Icons.file_download, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Export Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ExportFormat.values.map((format) {
              return RadioListTile<ExportFormat>(
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
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Export Scope',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ExportScope.values.map((scope) {
              return RadioListTile<ExportScope>(
                title: Text(_getScopeDisplayName(scope)),
                subtitle: Text(_getScopeDescription(scope)),
                value: scope,
                groupValue: _selectedScope,
                activeColor: Colors.blue.shade700,
                onChanged: (value) {
                  setState(() {
                    _selectedScope = value!;
                  });
                },
              );
            }).toList(),
            if (_selectedScope == ExportScope.dateRange) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_startDate != null 
                        ? DateFormat('MMM dd, yyyy').format(_startDate!)
                        : 'Select date'),
                      onTap: () => _selectStartDate(),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(_endDate != null 
                        ? DateFormat('MMM dd, yyyy').format(_endDate!)
                        : 'Select date'),
                      onTap: () => _selectEndDate(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Export Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Include User Preferences'),
              subtitle: const Text('Export app settings and preferences'),
              value: _includeUserPrefs,
              onChanged: (value) {
                setState(() {
                  _includeUserPrefs = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Include System Data'),
              subtitle: const Text('Export device and app metadata'),
              value: _includeSystemData,
              onChanged: (value) {
                setState(() {
                  _includeSystemData = value;
                });
              },
            ),
          ],
        ),
      ),
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
                Icon(Icons.file_download, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Exporting...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _exportProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
            const SizedBox(height: 8),
            Text(_exportStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: _isExporting ? null : _performExport,
      icon: const Icon(Icons.download),
      label: const Text('Export Data'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _performExport() async {
    if (_selectedScope == ExportScope.dateRange && (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates for date range export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Preparing export...';
    });

    try {
      final filter = ExportFilter(
        scope: _selectedScope,
        startDate: _startDate,
        endDate: _endDate,
        includeUserPreferences: _includeUserPrefs,
        includeSystemData: _includeSystemData,
      );

      final result = await _exportService.exportData(
        format: _selectedFormat,
        filter: filter,
        onProgress: (progress) {
          setState(() {
            _exportProgress = progress;
            _exportStatus = 'Processing... ${(progress * 100).toInt()}%';
          });
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export completed: ${result.totalRecords} records exported'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  String _getFormatDisplayName(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON Format';
      case ExportFormat.csv:
        return 'CSV Format';
      case ExportFormat.excel:
        return 'Excel Format';
    }
  }

  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JavaScript Object Notation - structured data format';
      case ExportFormat.csv:
        return 'Comma Separated Values - spreadsheet compatible';
      case ExportFormat.excel:
        return 'Excel compatible CSV format';
    }
  }

  String _getScopeDisplayName(ExportScope scope) {
    switch (scope) {
      case ExportScope.all:
        return 'All Data';
      case ExportScope.lastWeek:
        return 'Last Week';
      case ExportScope.lastMonth:
        return 'Last Month';
      case ExportScope.thisYear:
        return 'This Year';
      case ExportScope.dateRange:
        return 'Date Range';
      case ExportScope.category:
        return 'By Category';
    }
  }

  String _getScopeDescription(ExportScope scope) {
    switch (scope) {
      case ExportScope.all:
        return 'Export all available data';
      case ExportScope.lastWeek:
        return 'Export data from the last 7 days';
      case ExportScope.lastMonth:
        return 'Export data from the last 30 days';
      case ExportScope.thisYear:
        return 'Export data from this year';
      case ExportScope.dateRange:
        return 'Export data from a specific date range';
      case ExportScope.category:
        return 'Export data by category';
    }
  }
}