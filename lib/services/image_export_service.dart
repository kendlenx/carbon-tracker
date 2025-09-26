import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'language_service.dart';

/// Service for exporting widgets/charts as images and sharing them
class ImageExportService {
  static ImageExportService? _instance;
  static ImageExportService get instance => _instance ??= ImageExportService._();
  
  ImageExportService._();

  final LanguageService _languageService = LanguageService.instance;

  /// Capture a widget as an image
  Future<Uint8List> captureWidget({
    required Widget widget,
    Size? size,
    double pixelRatio = 3.0,
  }) async {
    try {
      // Create a RepaintBoundary to capture the widget
      final repaintBoundary = RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: widget,
        ),
      );

      // Create an offscreen widget tree
      final renderRepaintBoundary = RenderRepaintBoundary();
      final renderView = RenderView(
        view: WidgetsBinding.instance.platformDispatcher.views.first,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: renderRepaintBoundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints.tight(size ?? const Size(300, 200)),
          devicePixelRatio: pixelRatio,
        ),
      );

      // Build the widget tree
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: renderView,
        child: repaintBoundary,
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      // Layout and paint
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      // Capture the image
      final image = await renderRepaintBoundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to capture widget as image: $e');
    }
  }

  /// Create a summary card widget for export
  Widget buildSummaryCardForExport({
    required String title,
    required String value,
    required String subtitle,
    Color color = Colors.green,
    Size size = const Size(300, 200),
  }) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App branding
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Carbon Tracker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Main value
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            
            const Spacer(),
            
            // Date
            Text(
              DateFormat('MMM dd, yyyy').format(DateTime.now()),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create a trend chart widget for export
  Widget buildTrendChartForExport({
    required String title,
    required List<double> values,
    required List<String> labels,
    Color color = Colors.green,
    Size size = const Size(400, 300),
    bool showTrend = true,
  }) {
    if (values.isEmpty || labels.isEmpty) {
      return Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _languageService.isEnglish ? 'No data available' : 'Veri bulunamadı',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final maxValue = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 1.0;
    final minValue = values.isNotEmpty ? values.reduce((a, b) => a < b ? a : b) : 0.0;
    final range = maxValue - minValue;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Simple bar chart
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  final normalizedHeight = range > 0 ? (value - minValue) / range : 0.0;
                  final barHeight = normalizedHeight * (size.height - 120); // Reserve space for labels
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label
                      Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Bar
                      Container(
                        width: 20,
                        height: barHeight.clamp(2.0, double.infinity),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.6)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Label
                      Text(
                        index < labels.length ? labels[index] : '',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Carbon Tracker',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Export widget as PNG image and save to temporary directory
  Future<String> exportWidgetAsPng({
    required Widget widget,
    Size? size,
    double pixelRatio = 3.0,
  }) async {
    try {
      final imageBytes = await captureWidget(
        widget: widget,
        size: size,
        pixelRatio: pixelRatio,
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'carbon_tracker_chart_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to export widget as PNG: $e');
    }
  }

  /// Share widget as image
  Future<void> shareWidget({
    required Widget widget,
    Size? size,
    double pixelRatio = 3.0,
    String? subject,
    String? text,
  }) async {
    try {
      final filePath = await exportWidgetAsPng(
        widget: widget,
        size: size,
        pixelRatio: pixelRatio,
      );

      final isEnglish = _languageService.isEnglish;
      
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? (isEnglish ? 'Carbon Tracker Stats' : 'Carbon Tracker İstatistikleri'),
        text: text ?? (isEnglish 
            ? 'Check out my carbon footprint stats from Carbon Tracker!'
            : 'Carbon Tracker\'dan karbon ayak izi istatistiklerimi inceleyin!'),
      );
    } catch (e) {
      throw Exception('Failed to share widget: $e');
    }
  }

  /// Create and share a summary card
  Future<void> shareSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    Color color = Colors.green,
  }) async {
    final widget = buildSummaryCardForExport(
      title: title,
      value: value,
      subtitle: subtitle,
      color: color,
    );

    await shareWidget(
      widget: widget,
      size: const Size(300, 200),
    );
  }

  /// Create and share a trend chart
  Future<void> shareTrendChart({
    required String title,
    required List<double> values,
    required List<String> labels,
    Color color = Colors.green,
  }) async {
    final widget = buildTrendChartForExport(
      title: title,
      values: values,
      labels: labels,
      color: color,
    );

    await shareWidget(
      widget: widget,
      size: const Size(400, 300),
    );
  }

  /// Share multiple widgets as separate images
  Future<void> shareMultipleWidgets({
    required List<Widget> widgets,
    Size? size,
    double pixelRatio = 3.0,
    String? subject,
    String? text,
  }) async {
    try {
      final filePaths = <String>[];
      
      for (int i = 0; i < widgets.length; i++) {
        final filePath = await exportWidgetAsPng(
          widget: widgets[i],
          size: size,
          pixelRatio: pixelRatio,
        );
        filePaths.add(filePath);
      }

      final isEnglish = _languageService.isEnglish;
      
      await Share.shareXFiles(
        filePaths.map((path) => XFile(path)).toList(),
        subject: subject ?? (isEnglish ? 'Carbon Tracker Analytics' : 'Carbon Tracker Analitikleri'),
        text: text ?? (isEnglish 
            ? 'My carbon footprint analytics from Carbon Tracker!'
            : 'Carbon Tracker\'dan karbon ayak izi analizlerim!'),
      );
    } catch (e) {
      throw Exception('Failed to share multiple widgets: $e');
    }
  }

  /// Create a comprehensive dashboard overview widget
  Widget buildDashboardOverviewForExport({
    required String todayCO2,
    required String weekCO2,
    required String monthCO2,
    required String topCategory,
    Size size = const Size(400, 500),
  }) {
    final isEnglish = _languageService.isEnglish;
    
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.eco,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carbon Tracker',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        isEnglish ? 'Your Carbon Footprint' : 'Karbon Ayak İziniz',
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
            
            const SizedBox(height: 30),
            
            // Stats cards
            Expanded(
              child: Column(
                children: [
                  // Today
                  _buildStatRow(
                    isEnglish ? 'Today' : 'Bugün',
                    todayCO2,
                    Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // This week
                  _buildStatRow(
                    isEnglish ? 'This Week' : 'Bu Hafta',
                    weekCO2,
                    Colors.orange,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // This month
                  _buildStatRow(
                    isEnglish ? 'This Month' : 'Bu Ay',
                    monthCO2,
                    Colors.purple,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Top category
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEnglish ? 'Top Category' : 'En Yüksek Kategori',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                topCategory,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  isEnglish ? 'Shared from Carbon Tracker' : 'Carbon Tracker\'dan paylaşıldı',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Share dashboard overview
  Future<void> shareDashboardOverview({
    required String todayCO2,
    required String weekCO2,
    required String monthCO2,
    required String topCategory,
  }) async {
    final widget = buildDashboardOverviewForExport(
      todayCO2: todayCO2,
      weekCO2: weekCO2,
      monthCO2: monthCO2,
      topCategory: topCategory,
    );

    await shareWidget(
      widget: widget,
      size: const Size(400, 500),
    );
  }
}