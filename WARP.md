# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- This is a Flutter mobile app (Android/iOS) named Carbon Step for tracking personal carbon footprint. It uses a service-oriented architecture, local SQLite (sqflite) storage, and Firebase (Auth, Firestore, Crashlytics, Analytics, Performance, App Check). It also ships iOS/Android home screen widgets and CarPlay/Siri integrations.

Common commands
- Setup
  - flutter pub get
- Dev loop
  - Run on a connected device/emulator: flutter run
  - Specify device: flutter run -d ios or flutter run -d android
- Lint and formatting
  - Static analysis: flutter analyze
  - Apply quick fixes: dart fix --apply
  - Format code: dart format .
- Tests
  - Run all tests: flutter test
  - Run a single test file: flutter test test/carplay_basic_test.dart
  - Run tests matching a name: flutter test --name "CarPlay service initializes"
  - Coverage (optional): flutter test --coverage
- Build
  - Android release APK: flutter build apk --release
  - Android appbundle: flutter build appbundle --release
  - iOS (no codesign): flutter build ios --release --no-codesign
- Assets and tooling
  - Generate launcher icons (from pubspec config): dart run flutter_launcher_icons
  - Generate native splash (from pubspec config): dart run flutter_native_splash:create
  - Generate app icon via provided test (writes assets/icons/app_icon.png): flutter test test/generate_icon_test.dart

Big-picture architecture and key components
- UI and app shell
  - Entry point: lib/main.dart. Initializes lightweight services, starts BackgroundInitService in the background, and builds CarbonTrackerApp.
  - App uses AnimatedBuilder listening to ThemeService and LanguageService to drive theming and localization. Initial route is SplashScreen; navigation flows to category screens (Transport, Energy, Food, Shopping, Achievements, Analytics Dashboard, Settings, Goals, etc.).
- Services layer (singletons; core app logic)
  - FirebaseService: Central integration with Firebase Core/Auth/Firestore/Crashlytics/Analytics/App Check. Listens to auth state, starts periodic sync when signed in, sets Crashlytics handlers.
  - DatabaseService: Local persistence via sqflite. Manages transport_activities table, indices, and migrations with guarded onUpgrade logic; provides dashboard stats and activity CRUD.
  - CarbonCalculatorService: Domain logic for computing emissions for transport, electricity, natural gas, and food; comparison/targets/tips helpers.
  - WidgetService and WidgetDataProvider: Compose, persist, and push data for iOS/Android Home Widgets via home_widget; schedule periodic updates after app init.
  - Other notable services: notification_service (local notifications), permission_service (first-time permission setup), theme_service, language_service (i18n from lib/l10n), achievement_service and gamification_service, performance_service, background_init_service, admob_service.
- Data and models
  - Transport models (lib/models/transport_model.dart, transport_activity.dart) define emission factors tailored for Turkey and activity entities.
  - State is primarily service-managed; screens/widgets read from services rather than a global state container.
- Platform integrations
  - Android (android/): Application ID com.kendlenx.carbonstep, minSdk 26, Kotlin + Gradle, Google services and Firebase plugins enabled.
  - iOS (ios/): Runner with Swift, widgets (WidgetKit) and Siri intents. Platform channels used for CarPlay/Siri (see services/carplay_service.dart and services/carplay_siri_service.dart; tested via mocked MethodChannels in test/).
- Localization
  - AppLocalizations in lib/l10n with JSON resource files (tr, en, etc.). LanguageService mediates the active Locale; UI pulls strings through AppLocalizations and translation helpers.

Repository notes pulled from README
- Quick start is standard Flutter: clone, flutter pub get, flutter run.
- Architecture follows a clean, service-oriented layering: Presentation (screens/widgets), Business (services including calculator, achievements, smart features), Data (sqflite, Provider-style patterns, shared_preferences).

Testing guidance
- Widget and service tests live under test/. CarPlay/Siri are validated with mocked MethodChannel handlers (see test/carplay_basic_test.dart and test/carplay_integration_test.dart).
- Some auxiliary scripts/tests generate images or assets (e.g., test/generate_icon_test.dart) and will write under assets/; prefer running these explicitly rather than with the general test suite if you don’t want file writes.

Gotchas and environment
- Firebase configs are committed (android/app/google-services.json, ios/Runner/GoogleService-Info.plist). App Check is configured with debug providers; release builds may require proper provider keys and iOS dSYM/mapping uploads outside of this repo.
- Home widgets and CarPlay/Siri features require running on real devices/supported simulators; they won’t work on web.
