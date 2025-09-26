import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// Import our logo widget (we'll copy the painter logic here)
class CarbonTrackerLogoPainter extends CustomPainter {
  final bool isDark;
  final double size;

  CarbonTrackerLogoPainter({required this.isDark, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = canvasSize.width * 0.4;

    // Define colors based on theme
    final primaryGreen = isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
    final secondaryGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF66BB6A);
    final accentGreen = const Color(0xFF8BC34A);
    final darkColor = isDark ? const Color(0xFF1B1B1B) : const Color(0xFF212121);

    // Draw background circle with gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryGreen.withValues(alpha: 0.1),
          darkColor.withValues(alpha: 0.8),
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw main leaf shape
    _drawLeaf(canvas, center, canvasSize, primaryGreen, secondaryGreen);

    // Draw CO2 molecules
    _drawCO2Molecules(canvas, center, canvasSize, accentGreen);

    // Draw circular progress indicator (representing tracking)
    _drawProgressRing(canvas, center, radius * 0.85, primaryGreen);

    // Add sparkle effects
    _drawSparkles(canvas, center, canvasSize, accentGreen);
  }

  void _drawLeaf(Canvas canvas, Offset center, Size size, Color primary, Color secondary) {
    final leafPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [secondary, primary],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: size.width * 0.6, height: size.height * 0.4));

    // Main leaf body
    final leafPath = Path();
    final leafCenter = Offset(center.dx, center.dy - size.height * 0.05);
    
    leafPath.moveTo(leafCenter.dx, leafCenter.dy - size.height * 0.2);
    leafPath.quadraticBezierTo(
      leafCenter.dx + size.width * 0.15, leafCenter.dy - size.height * 0.1,
      leafCenter.dx + size.width * 0.1, leafCenter.dy + size.height * 0.1,
    );
    leafPath.quadraticBezierTo(
      leafCenter.dx, leafCenter.dy + size.height * 0.15,
      leafCenter.dx - size.width * 0.1, leafCenter.dy + size.height * 0.1,
    );
    leafPath.quadraticBezierTo(
      leafCenter.dx - size.width * 0.15, leafCenter.dy - size.height * 0.1,
      leafCenter.dx, leafCenter.dy - size.height * 0.2,
    );

    canvas.drawPath(leafPath, leafPaint);

    // Leaf vein
    final veinPaint = Paint()
      ..color = primary.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final veinPath = Path();
    veinPath.moveTo(leafCenter.dx, leafCenter.dy - size.height * 0.18);
    veinPath.lineTo(leafCenter.dx, leafCenter.dy + size.height * 0.12);

    canvas.drawPath(veinPath, veinPaint);
  }

  void _drawCO2Molecules(Canvas canvas, Offset center, Size size, Color color) {
    final moleculePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw small CO2 representations around the leaf
    final positions = [
      Offset(center.dx - size.width * 0.25, center.dy - size.height * 0.1),
      Offset(center.dx + size.width * 0.25, center.dy + size.height * 0.05),
      Offset(center.dx - size.width * 0.15, center.dy + size.height * 0.25),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, 3, moleculePaint);
      canvas.drawCircle(Offset(pos.dx + 8, pos.dy), 2, moleculePaint);
      canvas.drawCircle(Offset(pos.dx - 8, pos.dy), 2, moleculePaint);
    }
  }

  void _drawProgressRing(Canvas canvas, Offset center, double radius, Color color) {
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw partial circle to represent progress/tracking
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5, // start angle
      4.5, // sweep angle (about 3/4 of circle)
      false,
      ringPaint,
    );
  }

  void _drawSparkles(Canvas canvas, Offset center, Size size, Color color) {
    final sparklePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Small sparkles around the logo
    final sparklePositions = [
      Offset(center.dx + size.width * 0.3, center.dy - size.height * 0.3),
      Offset(center.dx - size.width * 0.35, center.dy - size.height * 0.2),
      Offset(center.dx + size.width * 0.35, center.dy + size.height * 0.3),
    ];

    for (final pos in sparklePositions) {
      // Draw cross-shaped sparkle
      canvas.drawLine(
        Offset(pos.dx - 4, pos.dy),
        Offset(pos.dx + 4, pos.dy),
        sparklePaint,
      );
      canvas.drawLine(
        Offset(pos.dx, pos.dy - 4),
        Offset(pos.dx, pos.dy + 4),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Future<void> generateIcon() async {
  const int size = 512; // High resolution for app icon
  
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  final painter = CarbonTrackerLogoPainter(isDark: false, size: size.toDouble());
  painter.paint(canvas, Size(size.toDouble(), size.toDouble()));
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  if (byteData != null) {
    final bytes = byteData.buffer.asUint8List();
    final file = File('assets/icons/app_icon.png');
    await file.writeAsBytes(bytes);
    print('✅ Generated app icon: ${file.path}');
  }
}

void main() async {
  await generateIcon();
}