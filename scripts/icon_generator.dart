import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create the icon widget
  final icon = Container(
    width: 512,
    height: 512,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(512 * 0.2),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF66BB6A), // Colors.green.shade400
          Color(0xFF2E7D32), // Colors.green.shade700
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: const Icon(
      Icons.eco,
      color: Colors.white,
      size: 300,
    ),
  );
  
  // Create a picture recorder
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Paint the widget to canvas
  final painter = _ContainerPainter(icon);
  painter.paint(canvas, const Size(512, 512));
  
  // Convert to image
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 512);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  if (byteData != null) {
    final bytes = byteData.buffer.asUint8List();
    final file = File('assets/icons/app_icon.png');
    await file.writeAsBytes(bytes);
    print('✅ Generated app icon: ${file.path}');
  }
}

class _ContainerPainter {
  final Widget widget;
  
  _ContainerPainter(this.widget);
  
  void paint(Canvas canvas, Size size) {
    // Draw background with gradient
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF66BB6A), // Colors.green.shade400
          Color(0xFF2E7D32), // Colors.green.shade700
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.2),
    );
    
    canvas.drawRRect(rect, paint);
    
    // Draw the eco icon
    _drawEcoIcon(canvas, size);
  }
  
  void _drawEcoIcon(Canvas canvas, Size size) {
    final iconSize = size.width * 0.6;
    final center = Offset(size.width / 2, size.height / 2);
    
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Simple leaf shape
    final path = Path();
    final leafSize = iconSize * 0.4;
    
    // Main leaf body
    path.moveTo(center.dx, center.dy - leafSize);
    path.quadraticBezierTo(
      center.dx + leafSize * 0.6, center.dy - leafSize * 0.3,
      center.dx + leafSize * 0.3, center.dy + leafSize * 0.3,
    );
    path.quadraticBezierTo(
      center.dx, center.dy + leafSize * 0.5,
      center.dx - leafSize * 0.3, center.dy + leafSize * 0.3,
    );
    path.quadraticBezierTo(
      center.dx - leafSize * 0.6, center.dy - leafSize * 0.3,
      center.dx, center.dy - leafSize,
    );
    
    canvas.drawPath(path, paint);
    
    // Leaf vein
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(center.dx, center.dy - leafSize * 0.8),
      Offset(center.dx, center.dy + leafSize * 0.4),
      veinPaint,
    );
  }
}