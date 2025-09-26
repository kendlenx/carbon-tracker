import 'package:flutter/material.dart';
import '../services/error_handler_service.dart';
import '../services/language_service.dart';
import '../utils/app_colors.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final LanguageService _languageService = LanguageService.instance;
  List<ErrorInfo> _errorHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _errorHistory = ErrorHandlerService().getErrorHistory();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ErrorHandlerService().recordError(
        e,
        StackTrace.current,
        severity: ErrorSeverity.medium,
        context: {'screen': 'analytics_dashboard'},
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = _languageService.isEnglish ? 'en' : 'tr';
        
    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              language == 'tr' ? 'Monitoring Dashboard' : 'Monitoring Dashboard',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _loadAnalyticsData,
                icon: const Icon(Icons.refresh),
                tooltip: language == 'tr' ? 'Yenile' : 'Refresh',
              ),
            ],
          ),
          body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummarySection(language),
                    const SizedBox(height: 24),
                    _buildActionsSection(language),
                  ],
                ),
              ),
    );
  }


  Widget _buildSummarySection(String language) {
    final totalErrors = _errorHistory.length;
    final criticalErrors = _errorHistory.where((e) => e.severity == ErrorSeverity.critical).length;
    final todayErrors = _errorHistory.where((e) => 
      DateTime.now().difference(e.timestamp).inDays == 0
    ).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == 'tr' ? 'Özet' : 'Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                language == 'tr' ? 'Toplam Hata' : 'Total Errors',
                totalErrors.toString(),
                Icons.error_outline,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                language == 'tr' ? 'Kritik Hata' : 'Critical',
                criticalErrors.toString(),
                Icons.dangerous,
                Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                language == 'tr' ? 'Bugün' : 'Today',
                todayErrors.toString(),
                Icons.today,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == 'tr' ? 'Test ve Yönetim' : 'Testing & Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _clearErrorHistory(language),
                icon: const Icon(Icons.clear_all),
                label: Text(
                  language == 'tr' ? 'Temizle' : 'Clear History',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _testError(),
                icon: const Icon(Icons.bug_report),
                label: Text(
                  language == 'tr' ? 'Test Hatası' : 'Test Error',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _clearErrorHistory(String language) {
    ErrorHandlerService().clearErrorHistory();
    _loadAnalyticsData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == 'tr'
            ? 'Hata geçmişi temizlendi'
            : 'Error history cleared',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _testError() {
    ErrorHandlerService().testNonFatalError();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test error recorded'),
        backgroundColor: Colors.orange,
      ),
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      _loadAnalyticsData();
    });
  }
}