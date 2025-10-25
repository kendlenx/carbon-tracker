// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carbon_step/main.dart';
import 'package:carbon_step/services/security_service.dart';
import 'package:carbon_step/services/firebase_service.dart';

void main() {
  testWidgets('Carbon Tracker app smoke test', (WidgetTester tester) async {
    // Create mock services
    final securityService = SecurityService();
    final firebaseService = FirebaseService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(CarbonTrackerApp(
      securityService: securityService,
      firebaseService: firebaseService,
    ));
    
    // Wait for localization to load
    await tester.pumpAndSettle();

    // Verify that the app loads without error
    expect(find.byType(Scaffold), findsOneWidget);
    
    // Verify that loading indicator appears initially
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(0));
  });
}
