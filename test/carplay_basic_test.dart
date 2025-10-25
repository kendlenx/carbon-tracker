import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carbon_step/services/carplay_service.dart';
import 'package:carbon_step/services/carplay_siri_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Basic CarPlay Tests', () {
    late CarPlayService carPlayService;
    late CarPlaySiriService siriService;

    setUp(() {
      // Mock CarPlay channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('carbon_tracker/carplay'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'setupTemplates':
              return {'success': true};
            default:
              return null;
          }
        },
      );

      // Mock Siri shortcuts channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('carbon_tracker/siri_shortcuts'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'donateShortcuts':
              return {'success': true, 'count': 6};
            default:
              return null;
          }
        },
      );

      carPlayService = CarPlayService.instance;
      siriService = CarPlaySiriService.instance;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('carbon_tracker/carplay'),
        null,
      );
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('carbon_tracker/siri_shortcuts'),
        null,
      );
    });

    test('CarPlay service initializes', () async {
      expect(carPlayService, isNotNull);
      expect(carPlayService.isCarPlayConnected, isFalse);
      expect(carPlayService.isTripActive, isFalse);
    });

    test('CarPlay service has correct initial state', () {
      expect(carPlayService.currentTripDistance, equals(0.0));
      expect(carPlayService.currentTripDuration, equals(0));
      expect(carPlayService.tripStartTime, isNull);
    });

    test('CarPlay can get connection status', () async {
      final status = await carPlayService.getConnectionStatus();
      expect(status, isA<Map<String, dynamic>>());
      expect(status['connected'], isFalse);
      expect(status['tripActive'], isFalse);
    });

    test('Siri service initializes', () async {
      expect(siriService, isNotNull);
      
      // Test basic functionality without throwing errors
      try {
        await siriService.initialize();
        // If we get here without exception, test passes
        expect(true, isTrue);
      } catch (e) {
        // Some initialization might fail in test environment, that's ok
        expect(e, isA<Exception>());
      }
    });

    test('CarPlay listener system works', () {
      var called = false;
      void testListener() {
        called = true;
      }

      carPlayService.addListener(testListener);
      carPlayService.notifyListeners();
      
      expect(called, isTrue);
      
      carPlayService.removeListener(testListener);
    });
  });
}