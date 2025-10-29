import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Service for exporting widgets/charts as images and sharing them
class ImageExportService {
  static ImageExportService? _instance;
  static ImageExportService get instance => _instance ??= ImageExportService._();
  
  ImageExportService._();


  /// Capture a widget as an image
  Future<Uint8List> captureWidget({
    required Widget widget,
    Size? size,
    double pixelRatio = 3.0,
  }) async {
    try {
      // Create a RepaintBoundary to capture the widget
      final repaintBoundary = RepaintBoundary(
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              color: Colors.transparent,
              child: widget,
            ),
          ),
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

      // Allow a microtask for paint to settle
      await Future<void>.delayed(const Duration(milliseconds: 16));
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

  Future<File> exportWidgetAsPng({
    required Widget widget,
    Size size = const Size(800, 800),
    double pixelRatio = 3.0,
    String fileName = 'share.png',
  }) async {
    final bytes = await captureWidget(widget: widget, size: size, pixelRatio: pixelRatio);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> shareWidget({
    required Widget widget,
    Size size = const Size(800, 800),
    String fileName = 'share.png',
    String? subject,
    String? text,
  }) async {
    try {
      final file = await exportWidgetAsPng(widget: widget, size: size, fileName: fileName);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'Carbon Tracker',
        text: text,
      );
    } catch (e) {
      throw Exception('Failed to share widget: $e');
    }
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
            'No data available',
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
      final files = <XFile>[];
      
      for (int i = 0; i < widgets.length; i++) {
        final file = await exportWidgetAsPng(
          widget: widgets[i],
          size: size ?? const Size(800, 800),
          pixelRatio: pixelRatio,
        );
        files.add(XFile(file.path));
      }

      await Share.shareXFiles(
        files,
        subject: subject ?? 'Carbon Tracker Analytics',
        text: text ?? 'My carbon footprint analytics from Carbon Tracker!',
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
                        'Your Carbon Footprint',
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
                    'Today',
                    todayCO2,
                    Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // This week
                  _buildStatRow(
                    'This Week',
                    weekCO2,
                    Colors.orange,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // This month
                  _buildStatRow(
                    'This Month',
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
                                'Top Category',
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
                  'Shared from Carbon Tracker',
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

  Future<File> exportFromRepaintBoundary({
    required GlobalKey key,
    Size size = const Size(800, 800),
    double pixelRatio = 3.0,
    String fileName = 'share.png',
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Preview not ready');
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      throw Exception('Failed to export from preview: $e');
    }
  }

  Future<void> shareFromRepaintBoundary({
    required GlobalKey key,
    Size size = const Size(800, 800),
    String fileName = 'share.png',
    String? subject,
    String? text,
  }) async {
    final file = await exportFromRepaintBoundary(key: key, size: size, fileName: fileName);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'Carbon Tracker',
      text: text,
    );
  }
}
