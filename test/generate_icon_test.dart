import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/carbon_tracker_logo.dart';

void main() {
  testWidgets('Generate app icon from CarbonTrackerIcon', (WidgetTester tester) async {
    // Build the CarbonTrackerIcon widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CarbonTrackerIcon(size: 512), // High resolution
          ),
        ),
      ),
    );

    // Find the widget
    final iconFinder = find.byType(CarbonTrackerIcon);
    expect(iconFinder, findsOneWidget);

    // Get the RenderObject
    final RenderRepaintBoundary boundary = tester.renderObject(iconFinder);
    
    // Convert to image
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null) {
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // Save to assets folder
      final file = File('assets/icons/app_icon.png');
      await file.writeAsBytes(pngBytes);
      
      print('✅ Generated app icon: ${file.path}');
      print('📏 Image size: ${image.width}x${image.height}');
    }
  });
}