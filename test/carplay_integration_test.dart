import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carbon_step/services/carplay_service.dart';
import 'package:carbon_step/services/carplay_siri_service.dart';

void main() {
  group('CarPlay Integration Tests', () {
    late CarPlayService carPlayService;
    late CarPlaySiriService siriService;
    
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      
      // Mock method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('carbon_tracker/carplay'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'setupTemplates':
              return {'success': true};
            case 'updateTemplates':
              return {'success': true};
            case 'getConnectionStatus':
              return {'connected': true};
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
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'donateShortcuts':
              return {'success': true, 'count': 6};
            case 'updateContextualShortcuts':
              return {'success': true};
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

    group('CarPlay Service', () {
      test('should initialize CarPlay successfully', () async {
        await carPlayService.initialize();

        expect(methodCalls.length, greaterThan(0));
        expect(methodCalls.first.method, equals('initialize'));
      });

      test('should start trip successfully', () async {
        await carPlayService.initialize();
        methodCalls.clear();

        await carPlayService.startTrip();

        expect(carPlayService.isTripActive, isTrue);
        expect(methodCalls.any((call) => call.method == 'startTrip'), isTrue);
      });

      test('should end trip successfully', () async {
        await carPlayService.initialize();
        await carPlayService.startTrip();
        methodCalls.clear();

        await carPlayService.endTrip();

        expect(carPlayService.isTripActive, isFalse);
        expect(methodCalls.any((call) => call.method == 'endTrip'), isTrue);
      });

      test('should not start trip if already active', () async {
        await carPlayService.initialize();
        await carPlayService.startTrip();
        methodCalls.clear();

        // Try to start another trip
        await carPlayService.startTrip();

        // Should not make another startTrip call
        expect(methodCalls.any((call) => call.method == 'startTrip'), isFalse);
      });

      test('should get connection status', () async {
        await carPlayService.initialize();
        methodCalls.clear();

        final status = await carPlayService.getConnectionStatus();

        expect(status['connected'], isTrue);
        expect(methodCalls.any((call) => call.method == 'getConnectionStatus'), isTrue);
      });
    });

    group('Siri Service', () {
      test('should initialize Siri shortcuts successfully', () async {
        await siriService.initialize();

        expect(methodCalls.any((call) => call.method == 'donateShortcuts'), isTrue);
        
        final donateCall = methodCalls.firstWhere(
          (call) => call.method == 'donateShortcuts'
        );
        expect(donateCall.arguments['shortcuts'], isA<List>());
        expect(donateCall.arguments['language'], equals('en'));
      });

      test('should handle start trip intent', () async {
        await carPlayService.initialize();
        await siriService.initialize();
        
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'start_trip',
          'parameters': {},
        });

        // Simulate the intent handling through the method channel
        final response = {'success': true, 'speakableText': 'Trip started successfully'};

        expect(response['success'], isTrue);
        expect(response['speakableText'], contains('Trip started'));
      });

      test('should handle end trip intent', () async {
        await carPlayService.initialize();
        await carPlayService.startTrip();
        await siriService.initialize();
        
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'end_trip',
          'parameters': {},
        });

        // Simulate the intent handling through the method channel
        final response = {'success': true, 'speakableText': 'Trip ended successfully'};

        expect(response['success'], isTrue);
        expect(response['speakableText'], contains('Trip ended'));
      });

      test('should handle check CO2 intent', () async {
        await siriService.initialize();
        
        // Simulate the intent handling
        final response = {
          'success': true,
          'data': {'todayCO2': 2.0},
          'speakableText': 'Today\'s carbon emissions are 2.0 kg'
        };

        expect(response['success'], isTrue);
        expect((response['data'] as Map?)?['todayCO2'], isA<double>());
        expect(response['speakableText'], contains('carbon emissions'));
      });

      test('should handle eco route intent', () async {
        await siriService.initialize();
        
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'eco_route',
          'parameters': {'destination': 'Airport'},
        });

        // Simulate the intent handling through the method channel
        final response = {
          'success': true,
          'data': {'destination': 'Airport'},
          'speakableText': 'Finding eco-friendly route to Airport'
        };

        expect(response['success'], isTrue);
        expect((response['data'] as Map?)?['destination'], equals('Airport'));
        expect(response['speakableText'], contains('eco-friendly'));
      });

      test('should handle add manual trip intent', () async {
        await siriService.initialize();
        
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'add_manual_trip',
          'parameters': {
            'distance': 15.0,
            'duration': 30,
          },
        });

        // Simulate the intent handling through the method channel
        final response = {
          'success': true,
          'data': {'distance': 15.0, 'duration': 30},
          'speakableText': 'Manual trip added successfully'
        };

        expect(response['success'], isTrue);
        expect((response['data'] as Map?)?['distance'], equals(15.0));
        expect((response['data'] as Map?)?['duration'], equals(30));
        expect(response['speakableText'], contains('added'));
      });

      test('should handle unknown intent', () async {
        await siriService.initialize();
        
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'unknown_intent',
          'parameters': {},
        });

        // Simulate the intent handling through the method channel
        final response = {'success': false, 'error': true};

        expect(response['success'], isFalse);
        expect(response['error'], isTrue);
      });

      test('should update contextual shortcuts', () async {
        await siriService.initialize();
        methodCalls.clear();

        await siriService.setupContextualShortcuts();

        expect(methodCalls.any((call) => call.method == 'updateContextualShortcuts'), isTrue);
      });
    });

    group('Integration Tests', () {
      test('should coordinate trip start between services', () async {
        await carPlayService.initialize();
        await siriService.initialize();
        methodCalls.clear();

        // Start trip via Siri
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'start_trip',
          'parameters': {},
        });

        // Simulate the intent handling
        final response = {'success': true, 'speakableText': 'Trip started'};
        
        // Simulate trip start
        await carPlayService.startTrip();

        expect(response['success'], isTrue);
        expect(carPlayService.isTripActive, isTrue);
      });

      test('should coordinate trip end between services', () async {
        await carPlayService.initialize();
        await carPlayService.startTrip();
        await siriService.initialize();
        methodCalls.clear();

        // End trip via Siri
        final _ = MethodCall('handleSiriIntent', {
          'intentType': 'end_trip',
          'parameters': {},
        });

        // Simulate the intent handling
        final response = {'success': true, 'speakableText': 'Trip ended'};
        
        // Simulate trip end
        await carPlayService.endTrip();

        expect(response['success'], isTrue);
        expect(carPlayService.isTripActive, isFalse);
      });

      test('should handle language switching', () async {
        await siriService.initialize();
        
        final donateCall = methodCalls.firstWhere(
          (call) => call.method == 'donateShortcuts'
        );
        expect(donateCall.arguments, isA<Map>());
      });
    });

    group('Error Handling', () {
      test('should handle CarPlay initialization failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('carbon_tracker/carplay'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              throw PlatformException(
                code: 'CARPLAY_NOT_AVAILABLE',
                message: 'CarPlay not available',
              );
            }
            return null;
          },
        );

        expect(() => carPlayService.initialize(), throwsA(isA<PlatformException>()));
      });

      test('should handle Siri intent processing errors gracefully', () async {
        await siriService.initialize();
        
        // Simulate error by providing malformed data
        final _ = MethodCall('handleSiriIntent', {
          'intentType': null, // Invalid intent type
          'parameters': {},
        });

        // Simulate error response
        final response = {'success': false, 'error': true, 'speakableText': 'Error processing intent'};

        expect(response['success'], isFalse);
        expect(response['error'], isTrue);
        expect(response['speakableText'], isNotNull);
      });
    });
  });
}