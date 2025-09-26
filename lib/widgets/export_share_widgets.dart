import 'package:flutter/material.dart';
import '../services/pdf_report_service.dart';
import '../services/image_export_service.dart';
import '../services/language_service.dart';
import '../services/advanced_reporting_service.dart';

/// Export options available to users
enum ExportFormat {
  pdf,
  image,
  dashboardOverview,
  summaryCard,
  trendChart,
}

/// Export and Share UI Components
class ExportShareWidgets {
  static final LanguageService _languageService = LanguageService.instance;
  static final PdfReportService _pdfService = PdfReportService.instance;
  static final ImageExportService _imageService = ImageExportService.instance;

  /// Floating Action Button for quick share
  static Widget buildShareFAB(BuildContext context, {
    VoidCallback? onPressed,
    String? heroTag,
  }) {
    final isEnglish = _languageService.isEnglish;
    
    return FloatingActionButton(
      onPressed: onPressed ?? () => showExportDialog(context),
      heroTag: heroTag ?? "share_fab",
      backgroundColor: Colors.green,
      child: const Icon(Icons.share, color: Colors.white),
      tooltip: isEnglish ? 'Share Report' : 'Rapor Paylaş',
    );
  }

  /// Export button for app bars
  static Widget buildExportButton(BuildContext context, {
    VoidCallback? onPressed,
    bool showText = true,
  }) {
    final isEnglish = _languageService.isEnglish;
    
    return TextButton.icon(
      onPressed: onPressed ?? () => showExportDialog(context),
      icon: const Icon(Icons.file_download),
      label: showText 
          ? Text(isEnglish ? 'Export' : 'Dışa Aktar')
          : const SizedBox.shrink(),
      style: TextButton.styleFrom(
        foregroundColor: Colors.green,
      ),
    );
  }

  /// Share button for app bars
  static Widget buildShareButton(BuildContext context, {
    VoidCallback? onPressed,
    bool showText = true,
  }) {
    final isEnglish = _languageService.isEnglish;
    
    return TextButton.icon(
      onPressed: onPressed ?? () => showQuickShareDialog(context),
      icon: const Icon(Icons.share),
      label: showText 
          ? Text(isEnglish ? 'Share' : 'Paylaş')
          : const SizedBox.shrink(),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
      ),
    );
  }

  /// Export options bottom sheet
  static void showExportBottomSheet(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                isEnglish ? 'Export Options' : 'Dışa Aktarma Seçenekleri',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Export options
            _buildExportOption(
              context,
              icon: Icons.picture_as_pdf,
              title: isEnglish ? 'PDF Report' : 'PDF Raporu',
              subtitle: isEnglish ? 'Complete analytics report' : 'Tam analitik rapor',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                await _exportAsPdf(context);
              },
            ),
            
            _buildExportOption(
              context,
              icon: Icons.image,
              title: isEnglish ? 'Dashboard Image' : 'Dashboard Görseli',
              subtitle: isEnglish ? 'Share as image' : 'Görsel olarak paylaş',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                await _exportDashboardAsImage(context);
              },
            ),
            
            _buildExportOption(
              context,
              icon: Icons.bar_chart,
              title: isEnglish ? 'Summary Card' : 'Özet Kartı',
              subtitle: isEnglish ? 'Quick stats card' : 'Hızlı istatistik kartı',
              color: Colors.green,
              onTap: () async {
                Navigator.pop(context);
                await _exportSummaryCard(context);
              },
            ),
            
            _buildExportOption(
              context,
              icon: Icons.trending_up,
              title: isEnglish ? 'Trend Chart' : 'Trend Grafiği',
              subtitle: isEnglish ? 'Trend visualization' : 'Trend görselleştirmesi',
              color: Colors.orange,
              onTap: () async {
                Navigator.pop(context);
                await _exportTrendChart(context);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Main export dialog
  static void showExportDialog(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.file_download,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish ? 'Export & Share' : 'Dışa Aktar ve Paylaş',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isEnglish ? 'Choose format and options' : 'Format ve seçenekleri belirleyin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Export format buttons
              Row(
                children: [
                  Expanded(
                    child: _buildFormatButton(
                      context,
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      color: Colors.red,
                      onPressed: () async {
                        Navigator.pop(context);
                        await _exportAsPdf(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormatButton(
                      context,
                      icon: Icons.image,
                      label: isEnglish ? 'Image' : 'Resim',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pop(context);
                        showImageExportOptions(context);
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Quick share buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _quickShareDashboard(context);
                      },
                      icon: const Icon(Icons.share),
                      label: Text(isEnglish ? 'Quick Share' : 'Hızlı Paylaş'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isEnglish ? 'Cancel' : 'İptal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick share dialog for fast sharing
  static void showQuickShareDialog(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.share, color: Colors.blue),
            const SizedBox(width: 8),
            Text(isEnglish ? 'Quick Share' : 'Hızlı Paylaş'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEnglish 
                  ? 'What would you like to share?'
                  : 'Ne paylaşmak istiyorsunuz?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Quick share options
            _buildQuickShareOption(
              context,
              icon: Icons.dashboard,
              title: isEnglish ? 'Dashboard Overview' : 'Dashboard Özeti',
              onTap: () async {
                Navigator.pop(context);
                await _quickShareDashboard(context);
              },
            ),
            
            _buildQuickShareOption(
              context,
              icon: Icons.assessment,
              title: isEnglish ? 'Today\'s Summary' : 'Bugünkü Özet',
              onTap: () async {
                Navigator.pop(context);
                await _quickShareToday(context);
              },
            ),
            
            _buildQuickShareOption(
              context,
              icon: Icons.trending_up,
              title: isEnglish ? 'Weekly Trend' : 'Haftalık Trend',
              onTap: () async {
                Navigator.pop(context);
                await _quickShareWeeklyTrend(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Cancel' : 'İptal'),
          ),
        ],
      ),
    );
  }

  /// Image export options dialog
  static void showImageExportOptions(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Export as Image' : 'Resim Olarak Dışa Aktar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: Text(isEnglish ? 'Dashboard Overview' : 'Dashboard Özeti'),
              subtitle: Text(isEnglish ? 'Complete dashboard view' : 'Tam dashboard görünümü'),
              onTap: () async {
                Navigator.pop(context);
                await _exportDashboardAsImage(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.green),
              title: Text(isEnglish ? 'Summary Card' : 'Özet Kartı'),
              subtitle: Text(isEnglish ? 'Compact summary' : 'Kompakt özet'),
              onTap: () async {
                Navigator.pop(context);
                await _exportSummaryCard(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.orange),
              title: Text(isEnglish ? 'Trend Chart' : 'Trend Grafiği'),
              subtitle: Text(isEnglish ? 'Weekly/Monthly trends' : 'Haftalık/Aylık trendler'),
              onTap: () async {
                Navigator.pop(context);
                await _exportTrendChart(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Cancel' : 'İptal'),
          ),
        ],
      ),
    );
  }

  /// Loading dialog for export operations
  static void showExportLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // Helper widgets

  static Widget _buildExportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  static Widget _buildFormatButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Widget _buildQuickShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      dense: true,
    );
  }

  // Export functions

  static Future<void> _exportAsPdf(BuildContext context) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      showExportLoadingDialog(
        context,
        isEnglish ? 'Generating PDF report...' : 'PDF raporu oluşturuluyor...',
      );

      await _pdfService.generateAndShareReport();
      
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'PDF report shared successfully!' : 'PDF raporu başarıyla paylaşıldı!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Failed to export PDF: $e' : 'PDF dışa aktarma başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _exportDashboardAsImage(BuildContext context) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      showExportLoadingDialog(
        context,
        isEnglish ? 'Creating dashboard image...' : 'Dashboard görseli oluşturuluyor...',
      );

      final reportingService = AdvancedReportingService.instance;
      final report = await reportingService.getDashboardReport();
      
      await _imageService.shareDashboardOverview(
        todayCO2: '${report.today.totalCO2.toStringAsFixed(1)} kg CO₂',
        weekCO2: '${report.week.totalCO2.toStringAsFixed(1)} kg CO₂',
        monthCO2: '${report.month.totalCO2.toStringAsFixed(1)} kg CO₂',
        topCategory: report.categoryBreakdown.isNotEmpty 
            ? report.categoryBreakdown.first.name 
            : (isEnglish ? 'No data' : 'Veri yok'),
      );
      
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Dashboard image shared!' : 'Dashboard görseli paylaşıldı!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Failed to export image: $e' : 'Görsel dışa aktarma başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _exportSummaryCard(BuildContext context) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      final reportingService = AdvancedReportingService.instance;
      final report = await reportingService.getDashboardReport();
      
      await _imageService.shareSummaryCard(
        title: isEnglish ? 'Today\'s Footprint' : 'Bugünkü Ayak İzi',
        value: '${report.today.totalCO2.toStringAsFixed(1)} kg CO₂',
        subtitle: isEnglish ? 'Carbon emissions today' : 'Bugünkü karbon emisyonu',
        color: Colors.blue,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Summary card shared!' : 'Özet kartı paylaşıldı!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Failed to export card: $e' : 'Kart dışa aktarma başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _exportTrendChart(BuildContext context) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      final reportingService = AdvancedReportingService.instance;
      final report = await reportingService.getDashboardReport();
      
      // Create sample trend data
      final values = List.generate(7, (index) => 
          report.week.averageDaily + (index % 3 - 1) * 0.5);
      final labels = List.generate(7, (index) => 
          'Day ${index + 1}');
      
      await _imageService.shareTrendChart(
        title: isEnglish ? 'Weekly CO₂ Trend' : 'Haftalık CO₂ Trendi',
        values: values,
        labels: labels,
        color: Colors.green,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Trend chart shared!' : 'Trend grafiği paylaşıldı!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'Failed to export chart: $e' : 'Grafik dışa aktarma başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _quickShareDashboard(BuildContext context) async {
    await _exportDashboardAsImage(context);
  }

  static Future<void> _quickShareToday(BuildContext context) async {
    await _exportSummaryCard(context);
  }

  static Future<void> _quickShareWeeklyTrend(BuildContext context) async {
    await _exportTrendChart(context);
  }
}