import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'advanced_reporting_service.dart';
import 'language_service.dart';
import 'chart_to_image_service.dart';
import 'dart:math' as math;

/// Service for generating and exporting PDF reports
class PdfReportService {
  static PdfReportService? _instance;
  static PdfReportService get instance => _instance ??= PdfReportService._();
  
  PdfReportService._();

  final AdvancedReportingService _reportingService = AdvancedReportingService.instance;
  final LanguageService _languageService = LanguageService.instance;
  final ChartToImageService _chartService = ChartToImageService.instance;

  /// Generate comprehensive PDF report
  Future<String> generateComprehensiveReport({
    DateTime? fromDate,
    DateTime? toDate,
    bool includeTrends = true,
    bool includeBreakdown = true,
    bool includeInsights = true,
    bool includePredictions = true,
  }) async {
    try {
      // Get report data
      final report = await _reportingService.getDashboardReport();
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Load fonts for better appearance
      final font = await rootBundle.load("fonts/NotoSans-Regular.ttf");
      final ttf = pw.Font.ttf(font);

      // Add cover page
      pdf.addPage(_buildCoverPage(report, ttf));
      
      // Add summary page
      pdf.addPage(_buildSummaryPage(report, ttf));
      
      if (includeTrends) {
        pdf.addPage(_buildTrendsPage(report, ttf));
      }
      
      if (includeBreakdown) {
        pdf.addPage(_buildBreakdownPage(report, ttf));
      }
      
      if (includeInsights) {
        pdf.addPage(_buildInsightsPage(report, ttf));
      }
      
      if (includePredictions) {
        pdf.addPage(_buildPredictionsPage(report, ttf));
      }
      
      // Add footer page
      pdf.addPage(_buildFooterPage(ttf));
      
      // Save PDF
      final output = await getTemporaryDirectory();
      final fileName = 'carbon_tracker_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      
      return file.path;
    } catch (e) {
      debugPrint('Error generating PDF report: $e');
      throw Exception('Failed to generate PDF report: $e');
    }
  }

  /// Build cover page
  pw.Page _buildCoverPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Spacer(flex: 2),
            
            // App Logo/Icon (placeholder)
            pw.Container(
              width: 120,
              height: 120,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.green,
              ),
              child: pw.Center(
                child: pw.Icon(
                  const pw.IconData(0xe916), // Leaf icon
                  color: PdfColors.white,
                  size: 60,
                ),
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Title
            pw.Text(
              'Carbon Tracker',
              style: pw.TextStyle(
                font: font,
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            // Subtitle
            pw.Text(
              isEnglish ? 'Analytics Report' : 'Analitik Rapor',
              style: pw.TextStyle(
                font: font,
                fontSize: 24,
                color: PdfColors.grey700,
              ),
            ),
            
            pw.Spacer(),
            
            // Date range
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    isEnglish ? 'Report Period' : 'Rapor Dönemi',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now().subtract(const Duration(days: 30))),
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(' - ', style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            pw.Spacer(flex: 2),
            
            // Generation info
            pw.Text(
              '${isEnglish ? 'Generated on' : 'Oluşturulma tarihi'}: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build summary page
  pw.Page _buildSummaryPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            _buildPageHeader(isEnglish ? 'Executive Summary' : 'Özet', font),
            
            pw.SizedBox(height: 20),
            
            // Summary cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    isEnglish ? 'Today' : 'Bugün',
                    '${report.today.totalCO2.toStringAsFixed(1)} kg CO₂',
                    PdfColors.blue,
                    font,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildSummaryCard(
                    isEnglish ? 'This Week' : 'Bu Hafta',
                    '${report.week.totalCO2.toStringAsFixed(1)} kg CO₂',
                    PdfColors.green,
                    font,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildSummaryCard(
                    isEnglish ? 'This Month' : 'Bu Ay',
                    '${report.month.totalCO2.toStringAsFixed(1)} kg CO₂',
                    PdfColors.orange,
                    font,
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Key metrics
            pw.Text(
              isEnglish ? 'Key Metrics' : 'Temel Metrikler',
              style: pw.TextStyle(
                font: font,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            // Metrics table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green50,
                  ),
                  children: [
                    _buildTableCell(isEnglish ? 'Metric' : 'Metrik', font, isHeader: true),
                    _buildTableCell(isEnglish ? 'Value' : 'Değer', font, isHeader: true),
                    _buildTableCell(isEnglish ? 'Trend' : 'Trend', font, isHeader: true),
                  ],
                ),
                // Data rows
                pw.TableRow(
                  children: [
                    _buildTableCell(isEnglish ? 'Weekly Average' : 'Haftalık Ortalama', font),
                    _buildTableCell('${report.week.averageDaily.toStringAsFixed(1)} kg CO₂/day', font),
                    _buildTableCell(_getTrendText(report.weekTrend.direction, isEnglish), font),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell(isEnglish ? 'Monthly Total' : 'Aylık Toplam', font),
                    _buildTableCell('${report.month.totalCO2.toStringAsFixed(1)} kg CO₂', font),
                    _buildTableCell(_getTrendText(report.monthTrend.direction, isEnglish), font),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildTableCell(isEnglish ? 'Total Activities' : 'Toplam Aktivite', font),
                    _buildTableCell('${report.month.totalActivities}', font),
                    _buildTableCell('-', font),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Top insights
            if (report.insights.isNotEmpty) ...[
              pw.Text(
                isEnglish ? 'Top Insights' : 'Önemli Bulgular',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              ...report.insights.take(3).map((insight) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      insight.title,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      insight.description,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        );
      },
    );
  }

  /// Build trends page
  pw.Page _buildTrendsPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isEnglish ? 'Trends Analysis' : 'Trend Analizi', font),
            
            pw.SizedBox(height: 20),
            
            // Weekly trend
            _buildTrendSection(
              isEnglish ? 'Weekly Trend' : 'Haftalık Trend',
              report.weekTrend,
              font,
              isEnglish,
            ),
            
            pw.SizedBox(height: 20),
            
            // Monthly trend
            _buildTrendSection(
              isEnglish ? 'Monthly Trend' : 'Aylık Trend',
              report.monthTrend,
              font,
              isEnglish,
            ),
            
            pw.SizedBox(height: 30),
            
            // Daily emissions chart (simple bar representation)
            pw.Text(
              isEnglish ? 'Daily Emissions (Last 7 Days)' : 'Günlük Emisyonlar (Son 7 Gün)',
              style: pw.TextStyle(
                font: font,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            _buildDailyEmissionsChart(report.week.dailyBreakdown, font, isEnglish),
          ],
        );
      },
    );
  }

  /// Build breakdown page
  pw.Page _buildBreakdownPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isEnglish ? 'Emissions Breakdown' : 'Emisyon Dağılımı', font),
            
            pw.SizedBox(height: 20),
            
            if (report.categoryBreakdown.isNotEmpty) ...[
              // Category breakdown table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      _buildTableCell(isEnglish ? 'Category' : 'Kategori', font, isHeader: true),
                      _buildTableCell(isEnglish ? 'Amount (kg CO₂)' : 'Miktar (kg CO₂)', font, isHeader: true),
                      _buildTableCell(isEnglish ? 'Percentage' : 'Yüzde', font, isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...report.categoryBreakdown.map((category) => pw.TableRow(
                    children: [
                      _buildTableCell(category.name, font),
                      _buildTableCell(category.value.toStringAsFixed(1), font),
                      _buildTableCell('${category.percentage.toStringAsFixed(1)}%', font),
                    ],
                  )),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Simple pie chart representation
              pw.Text(
                isEnglish ? 'Visual Breakdown' : 'Görsel Dağılım',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              _buildSimplePieChart(report.categoryBreakdown, font),
            ] else ...[
              pw.Center(
                child: pw.Text(
                  isEnglish ? 'No breakdown data available' : 'Dağılım verisi bulunmuyor',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Build insights page
  pw.Page _buildInsightsPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isEnglish ? 'Insights & Recommendations' : 'Bulgular ve Öneriler', font),
            
            pw.SizedBox(height: 20),
            
            if (report.insights.isNotEmpty) ...[
              ...report.insights.map((insight) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: _getInsightBackgroundColor(insight.impact),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: _getInsightBorderColor(insight.impact),
                    width: 1,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 30,
                          height: 30,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: _getInsightIconColor(insight.impact),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              _getInsightIcon(insight.type),
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 16,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Text(
                            insight.title,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        pw.Text(
                          _getImpactText(insight.impact, isEnglish),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: _getInsightIconColor(insight.impact),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 10),
                    
                    pw.Text(
                      insight.description,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 13,
                        color: PdfColors.grey800,
                      ),
                    ),
                    
                    if (insight.recommendations.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(
                        isEnglish ? 'Recommendations:' : 'Öneriler:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      ...insight.recommendations.map((rec) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, top: 3),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: pw.TextStyle(font: font, fontSize: 12)),
                            pw.Expanded(
                              child: pw.Text(
                                rec,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              )),
            ] else ...[
              pw.Center(
                child: pw.Text(
                  isEnglish 
                      ? 'No insights available yet\nAdd more activities to get personalized insights'
                      : 'Henüz bulgu bulunmuyor\nKişiselleştirilmiş bulgular için daha fazla aktivite ekleyin',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Build predictions page
  pw.Page _buildPredictionsPage(DashboardReport report, pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isEnglish ? 'Predictions' : 'Tahminler', font),
            
            pw.SizedBox(height: 20),
            
            // Confidence indicator
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    isEnglish ? 'Prediction Confidence:' : 'Tahmin Güvenilirliği:',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    '${(report.predictions.confidence * 100).toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _getConfidenceColor(report.predictions.confidence),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Predictions summary
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildPredictionCard(
                    isEnglish ? 'Next Week' : 'Gelecek Hafta',
                    '${report.predictions.weeklyPrediction.toStringAsFixed(1)} kg CO₂',
                    PdfColors.blue,
                    font,
                  ),
                ),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  child: _buildPredictionCard(
                    isEnglish ? 'Next Month' : 'Gelecek Ay',
                    '${report.predictions.monthlyPrediction.toStringAsFixed(1)} kg CO₂',
                    PdfColors.purple,
                    font,
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Daily predictions chart
            pw.Text(
              isEnglish ? '7-Day Forecast' : '7 Günlük Tahmin',
              style: pw.TextStyle(
                font: font,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            _buildPredictionsChart(report.predictions.dailyPredictions, font, isEnglish),
            
            pw.SizedBox(height: 20),
            
            // Prediction notes
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.yellow50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isEnglish ? 'Note:' : 'Not:',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    isEnglish
                        ? 'Predictions are based on ${report.predictions.basedOnDays} days of historical data and may vary based on your actual activities.'
                        : 'Tahminler ${report.predictions.basedOnDays} günlük geçmiş veriye dayanmaktadır ve gerçek aktivitelerinize göre değişebilir.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build footer page
  pw.Page _buildFooterPage(pw.Font font) {
    final isEnglish = _languageService.isEnglish;
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Spacer(flex: 2),
            
            pw.Text(
              isEnglish ? 'Thank you for using Carbon Tracker!' : 'Carbon Tracker kullandığınız için teşekkürler!',
              style: pw.TextStyle(
                font: font,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
              textAlign: pw.TextAlign.center,
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Text(
              isEnglish
                  ? 'Continue tracking your carbon footprint and help create a sustainable future.'
                  : 'Karbon ayak izinizi takip etmeye devam edin ve sürdürülebilir bir gelecek yaratmaya yardımcı olun.',
              style: pw.TextStyle(
                font: font,
                fontSize: 16,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            
            pw.SizedBox(height: 40),
            
            // App icon placeholder
            pw.Container(
              width: 80,
              height: 80,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.green,
              ),
              child: pw.Center(
                child: pw.Icon(
                  const pw.IconData(0xe916), // Leaf icon
                  color: PdfColors.white,
                  size: 40,
                ),
              ),
            ),
            
            pw.Spacer(flex: 3),
            
            pw.Text(
              isEnglish ? 'Generated by Carbon Tracker App' : 'Carbon Tracker Uygulaması Tarafından Oluşturuldu',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            pw.Text(
              DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey500,
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper methods

  pw.Widget _buildPageHeader(String title, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColors.green,
        ),
      ],
    );
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPredictionCard(String title, String value, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Icon(
            const pw.IconData(0xe8df), // Timeline icon
            color: color,
            size: 24,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.green800 : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildTrendSection(String title, TrendAnalysis trend, pw.Font font, bool isEnglish) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  '${trend.formattedPercentageChange} ${_getTrendText(trend.direction, isEnglish)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _getTrendColor(trend.direction),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Text(
                '${isEnglish ? 'Current:' : 'Şu anki:'} ${trend.currentValue.toStringAsFixed(1)} kg',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Spacer(),
              pw.Text(
                '${isEnglish ? 'Previous:' : 'Önceki:'} ${trend.previousValue.toStringAsFixed(1)} kg',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${isEnglish ? 'Change:' : 'Değişim:'} ${trend.formattedChange}',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _getTrendColor(trend.direction),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDailyEmissionsChart(Map<String, double> dailyData, pw.Font font, bool isEnglish) {
    if (dailyData.isEmpty) {
      return pw.Center(
        child: pw.Text(
          isEnglish ? 'No data available' : 'Veri bulunamadı',
          style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final maxValue = sortedEntries.map((e) => e.value).reduce(math.max);

    return pw.Container(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: sortedEntries.map((entry) {
          final barHeight = maxValue > 0 ? (entry.value / maxValue) * 130 : 0;
          final date = DateTime.parse(entry.key);
          
          return pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  height: barHeight.toDouble(),
                  margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  DateFormat('MMM dd').format(date),
                  style: pw.TextStyle(font: font, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildSimplePieChart(List<CategoryBreakdown> categories, pw.Font font) {
    return pw.Container(
      height: 200,
      child: pw.Row(
        children: [
          // Legend
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: categories.take(5).map((category) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 12,
                      height: 12,
                      color: _getCategoryPdfColor(category.name),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        '${category.name}\n${category.percentage.toStringAsFixed(1)}%',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          
          // Simple visual representation
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              children: categories.take(5).map((category) => pw.Container(
                width: double.infinity,
                height: category.percentage * 2, // Height proportional to percentage
                margin: const pw.EdgeInsets.only(bottom: 2),
                color: _getCategoryPdfColor(category.name),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPredictionsChart(List<double> predictions, pw.Font font, bool isEnglish) {
    if (predictions.isEmpty) {
      return pw.Center(
        child: pw.Text(
          isEnglish ? 'No prediction data' : 'Tahmin verisi yok',
          style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    final maxValue = predictions.reduce(math.max);

    return pw.Container(
      height: 120,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: predictions.asMap().entries.map((entry) {
          final barHeight = maxValue > 0 ? (entry.value / maxValue) * 100 : 0;
          
          return pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  height: barHeight.toDouble(),
                  margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  '${isEnglish ? 'Day' : 'Gün'} ${entry.key + 1}',
                  style: pw.TextStyle(font: font, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Color helpers
  PdfColor _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.increasing:
        return PdfColors.red;
      case TrendDirection.decreasing:
        return PdfColors.green;
      case TrendDirection.stable:
        return PdfColors.grey;
    }
  }

  PdfColor _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return PdfColors.green;
    if (confidence > 0.4) return PdfColors.orange;
    return PdfColors.red;
  }

  PdfColor _getInsightBackgroundColor(InsightImpact impact) {
    switch (impact) {
      case InsightImpact.high:
        return PdfColors.red50;
      case InsightImpact.medium:
        return PdfColors.orange50;
      case InsightImpact.low:
        return PdfColors.blue50;
      case InsightImpact.positive:
        return PdfColors.green50;
    }
  }

  PdfColor _getInsightBorderColor(InsightImpact impact) {
    switch (impact) {
      case InsightImpact.high:
        return PdfColors.red;
      case InsightImpact.medium:
        return PdfColors.orange;
      case InsightImpact.low:
        return PdfColors.blue;
      case InsightImpact.positive:
        return PdfColors.green;
    }
  }

  PdfColor _getInsightIconColor(InsightImpact impact) {
    switch (impact) {
      case InsightImpact.high:
        return PdfColors.red;
      case InsightImpact.medium:
        return PdfColors.orange;
      case InsightImpact.low:
        return PdfColors.blue;
      case InsightImpact.positive:
        return PdfColors.green;
    }
  }

  PdfColor _getCategoryPdfColor(String category) {
    switch (category.toLowerCase()) {
      case 'car':
      case 'araba':
        return PdfColors.blue;
      case 'bus':
      case 'otobüs':
        return PdfColors.orange;
      case 'train':
      case 'tren':
        return PdfColors.green;
      case 'plane':
      case 'uçak':
        return PdfColors.red;
      case 'bike':
      case 'bisiklet':
        return PdfColors.lightGreen;
      case 'walking':
      case 'yürüme':
        return PdfColors.teal;
      default:
        return PdfColors.grey;
    }
  }

  // Text helpers
  String _getTrendText(TrendDirection direction, bool isEnglish) {
    switch (direction) {
      case TrendDirection.increasing:
        return isEnglish ? '↑ Increasing' : '↑ Artıyor';
      case TrendDirection.decreasing:
        return isEnglish ? '↓ Decreasing' : '↓ Azalıyor';
      case TrendDirection.stable:
        return isEnglish ? '→ Stable' : '→ Sabit';
    }
  }

  String _getImpactText(InsightImpact impact, bool isEnglish) {
    switch (impact) {
      case InsightImpact.high:
        return isEnglish ? 'High' : 'Yüksek';
      case InsightImpact.medium:
        return isEnglish ? 'Medium' : 'Orta';
      case InsightImpact.low:
        return isEnglish ? 'Low' : 'Düşük';
      case InsightImpact.positive:
        return isEnglish ? 'Positive' : 'Olumlu';
    }
  }

  String _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.highUsageDay:
        return '📅';
      case InsightType.categoryDominance:
        return '📊';
      case InsightType.improvement:
        return '📈';
      case InsightType.warning:
        return '⚠️';
      case InsightType.prediction:
        return '🔮';
    }
  }

  /// Share PDF report
  Future<void> shareReport(String filePath, {String? subject}) async {
    try {
      final isEnglish = _languageService.isEnglish;
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? (isEnglish ? 'Carbon Tracker Report' : 'Carbon Tracker Rapor'),
        text: isEnglish 
            ? 'Check out my carbon footprint analysis report!'
            : 'Karbon ayak izi analiz raporumu inceleyin!',
      );
    } catch (e) {
      throw Exception('Failed to share report: $e');
    }
  }

  /// Generate and share report in one step
  Future<void> generateAndShareReport({
    DateTime? fromDate,
    DateTime? toDate,
    bool includeTrends = true,
    bool includeBreakdown = true,
    bool includeInsights = true,
    bool includePredictions = true,
  }) async {
    try {
      final filePath = await generateComprehensiveReport(
        fromDate: fromDate,
        toDate: toDate,
        includeTrends: includeTrends,
        includeBreakdown: includeBreakdown,
        includeInsights: includeInsights,
        includePredictions: includePredictions,
      );
      
      await shareReport(filePath);
    } catch (e) {
      throw Exception('Failed to generate and share report: $e');
    }
  }
}