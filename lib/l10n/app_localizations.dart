import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = 
      _AppLocalizationsDelegate();

  Map<String, dynamic>? _localizedStrings;

  Future<bool> load() async {
    String jsonString = await rootBundle.loadString(
      'lib/l10n/app_${locale.languageCode}.json'
    );
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap;
    return true;
  }

  String translate(String key) {
    return _getTranslation(_localizedStrings, key) ?? key;
  }

  String? _getTranslation(Map<String, dynamic>? map, String key) {
    if (map == null) return null;
    
    List<String> keys = key.split('.');
    dynamic result = map;
    
    for (String k in keys) {
      if (result is Map<String, dynamic> && result.containsKey(k)) {
        result = result[k];
      } else {
        return null;
      }
    }
    
    return result is String ? result : null;
  }

  // Convenience getters for common sections
  String get appTitle => translate('appTitle');
  String get appSubtitle => translate('appSubtitle');

  // Navigation
  String get navHome => translate('navigation.home');
  String get navTransport => translate('navigation.transport');
  String get navEnergy => translate('navigation.energy');
  String get navFood => translate('navigation.food');
  String get navShopping => translate('navigation.shopping');
  String get navStatistics => translate('navigation.statistics');
  String get navAchievements => translate('navigation.achievements');
  String get navSettings => translate('navigation.settings');

  // Dashboard
  String get dashboardTodayTotal => translate('dashboard.todayTotal');
  String get dashboardWeeklyAverage => translate('dashboard.weeklyAverage');
  String get dashboardMonthlyGoal => translate('dashboard.monthlyGoal');
  String get dashboardCarbonEmission => translate('dashboard.carbonEmission');
  String get dashboardPerformance => translate('dashboard.performance');
  String get dashboardCategories => translate('dashboard.categories');
  String get dashboardLoading => translate('dashboard.loading');
  String get dashboardRefresh => translate('dashboard.refresh');

  // Transport
  String get transportTitle => translate('transport.title');
  String get transportSubtitle => translate('transport.subtitle');
  String get transportWalking => translate('transport.walking');
  String get transportCycling => translate('transport.cycling');
  String get transportPublicTransport => translate('transport.publicTransport');
  String get transportCar => translate('transport.car');
  String get transportMotorcycle => translate('transport.motorcycle');
  String get transportTaxi => translate('transport.taxi');
  String get transportPlane => translate('transport.plane');
  String get transportDistance => translate('transport.distance');
  String get transportKm => translate('transport.km');
  String get transportAddTrip => translate('transport.addTrip');
  String get transportSelectType => translate('transport.selectTransportType');
  String get transportEnterDistance => translate('transport.enterDistance');
  String get transportSave => translate('transport.save');
  String get transportCancel => translate('transport.cancel');

  // Energy
  String get energyTitle => translate('energy.title');
  String get energySubtitle => translate('energy.subtitle');
  String get energyElectricity => translate('energy.electricity');
  String get energyNaturalGas => translate('energy.naturalGas');
  String get energyHeating => translate('energy.heating');
  String get energyCooling => translate('energy.cooling');
  String get energyHotWater => translate('energy.hotWater');
  String get energyAppliances => translate('energy.appliances');
  String get energyConsumption => translate('energy.consumption');
  String get energyKwh => translate('energy.kwh');
  String get energyM3 => translate('energy.m3');
  String get energyAddConsumption => translate('energy.addConsumption');
  String get energySelectType => translate('energy.selectEnergyType');
  String get energyEnterAmount => translate('energy.enterAmount');

  // Achievements
  String get achievementsTitle => translate('achievements.title');
  String get achievementsUnlocked => translate('achievements.unlocked');
  String get achievementsLocked => translate('achievements.locked');
  String get achievementsProgress => translate('achievements.progress');
  String get achievementsCongratulations => translate('achievements.congratulations');
  String get achievementsNewAchievement => translate('achievements.newAchievement');
  String get achievementsContinue => translate('achievements.continue');
  String get achievementsClose => translate('achievements.close');
  String get achievementsLevel => translate('achievements.level');
  String get achievementsBronze => translate('achievements.bronze');
  String get achievementsSilver => translate('achievements.silver');
  String get achievementsGold => translate('achievements.gold');
  String get achievementsPlatinum => translate('achievements.platinum');
  String get achievementsDiamond => translate('achievements.diamond');

  // Goals
  String get goalsTitle => translate('goals.title');
  String get goalsDaily => translate('goals.daily');
  String get goalsWeekly => translate('goals.weekly');
  String get goalsMonthly => translate('goals.monthly');
  String get goalsSetGoal => translate('goals.setGoal');
  String get goalsCurrentGoal => translate('goals.currentGoal');
  String get goalsTarget => translate('goals.target');
  String get goalsProgress => translate('goals.progress');
  String get goalsCompleted => translate('goals.completed');
  String get goalsRemaining => translate('goals.remaining');
  String get goalsOnTrack => translate('goals.onTrack');
  String get goalsBehindSchedule => translate('goals.behindSchedule');
  String get goalsExceeded => translate('goals.exceeded');

  // Notifications
  String get notificationsTitle => translate('notifications.title');
  String get notificationsDailyReminder => translate('notifications.dailyReminder');
  String get notificationsWeeklyReport => translate('notifications.weeklyReport');
  String get notificationsAchievementUnlocked => translate('notifications.achievementUnlocked');
  String get notificationsGoalReached => translate('notifications.goalReached');
  String get notificationsSmartTip => translate('notifications.smartTip');
  String get notificationsPermissionRequired => translate('notifications.permissionRequired');
  String get notificationsEnable => translate('notifications.enable');
  String get notificationsDisable => translate('notifications.disable');

  // Location
  String get locationTitle => translate('location.title');
  String get locationTracking => translate('location.tracking');
  String get locationEnabled => translate('location.enabled');
  String get locationDisabled => translate('location.disabled');
  String get locationPermissionRequired => translate('location.permissionRequired');
  String get locationNearbyBikePaths => translate('location.nearbyBikePaths');
  String get locationPublicTransportStops => translate('location.publicTransportStops');
  String get locationEcoFriendlyRoutes => translate('location.ecoFriendlyRoutes');
  String get locationSuggestions => translate('location.suggestions');

  // Voice
  String get voiceTitle => translate('voice.title');
  String get voiceListening => translate('voice.listening');
  String get voiceSpeak => translate('voice.speak');
  String get voiceStopListening => translate('voice.stopListening');
  String get voicePermissionRequired => translate('voice.permissionRequired');
  String get voiceCommandHistory => translate('voice.commandHistory');
  String get voiceExamples => translate('voice.examples');
  String get voiceLogTransport => translate('voice.logTransport');
  String get voiceGetDailyStats => translate('voice.getDailyStats');
  String get voiceSetGoal => translate('voice.setGoal');

  // Smart Home
  String get smartHomeTitle => translate('smartHome.title');
  String get smartHomeConnectedDevices => translate('smartHome.connectedDevices');
  String get smartHomeAutomations => translate('smartHome.automations');
  String get smartHomeEnergyConsumption => translate('smartHome.energyConsumption');
  String get smartHomeOptimizations => translate('smartHome.optimizations');
  String get smartHomeThermostat => translate('smartHome.thermostat');
  String get smartHomeSmartMeter => translate('smartHome.smartMeter');
  String get smartHomeLightBulb => translate('smartHome.lightBulb');
  String get smartHomeSmartPlug => translate('smartHome.smartPlug');
  String get smartHomeConnected => translate('smartHome.connected');
  String get smartHomeDisconnected => translate('smartHome.disconnected');
  String get smartHomeConnecting => translate('smartHome.connecting');

  // Devices
  String get devicesTitle => translate('devices.title');
  String get devicesAppleWatch => translate('devices.appleWatch');
  String get devicesWearOS => translate('devices.wearOS');
  String get devicesSiriShortcuts => translate('devices.siriShortcuts');
  String get devicesGoogleAssistant => translate('devices.googleAssistant');
  String get devicesCarPlay => translate('devices.carPlay');
  String get devicesAndroidAuto => translate('devices.androidAuto');
  String get devicesSyncStatus => translate('devices.syncStatus');
  String get devicesLastSync => translate('devices.lastSync');
  String get devicesShortcuts => translate('devices.shortcuts');
  String get devicesHealthData => translate('devices.healthData');

  // Statistics
  String get statisticsTitle => translate('statistics.title');
  String get statisticsOverview => translate('statistics.overview');
  String get statisticsThisWeek => translate('statistics.thisWeek');
  String get statisticsThisMonth => translate('statistics.thisMonth');
  String get statisticsThisYear => translate('statistics.thisYear');
  String get statisticsComparison => translate('statistics.comparison');
  String get statisticsTrends => translate('statistics.trends');
  String get statisticsBreakdown => translate('statistics.breakdown');
  String get statisticsImprovement => translate('statistics.improvement');
  String get statisticsYourAverage => translate('statistics.yourAverage');
  String get statisticsTurkeyAverage => translate('statistics.turkeyAverage');
  String get statisticsParisTarget => translate('statistics.parisTarget');

  // Settings
  String get settingsTitle => translate('settings.title');
  String get settingsLanguage => translate('settings.language');
  String get settingsTheme => translate('settings.theme');
  String get settingsNotifications => translate('settings.notifications');
  String get settingsPrivacy => translate('settings.privacy');
  String get settingsPermissions => translate('settings.permissions');
  String get settingsAbout => translate('settings.about');
  String get settingsVersion => translate('settings.version');
  String get settingsLightTheme => translate('settings.lightTheme');
  String get settingsDarkTheme => translate('settings.darkTheme');
  String get settingsSystemTheme => translate('settings.systemTheme');
  String get settingsTurkish => translate('settings.turkish');
  String get settingsEnglish => translate('settings.english');

  // Permissions
  String get permissionsTitle => translate('permissions.title');
  String get permissionsLocation => translate('permissions.location');
  String get permissionsMicrophone => translate('permissions.microphone');
  String get permissionsNotifications => translate('permissions.notifications');
  String get permissionsCamera => translate('permissions.camera');
  String get permissionsStorage => translate('permissions.storage');
  String get permissionsRequired => translate('permissions.required');
  String get permissionsOptional => translate('permissions.optional');
  String get permissionsGranted => translate('permissions.granted');
  String get permissionsDenied => translate('permissions.denied');
  String get permissionsRequestPermission => translate('permissions.requestPermission');
  String get permissionsOpenSettings => translate('permissions.openSettings');

  // Common
  String get commonOk => translate('common.ok');
  String get commonCancel => translate('common.cancel');
  String get commonSave => translate('common.save');
  String get commonDelete => translate('common.delete');
  String get commonEdit => translate('common.edit');
  String get commonAdd => translate('common.add');
  String get commonRemove => translate('common.remove');
  String get commonEnable => translate('common.enable');
  String get commonDisable => translate('common.disable');
  String get commonLoading => translate('common.loading');
  String get commonError => translate('common.error');
  String get commonSuccess => translate('common.success');
  String get commonWarning => translate('common.warning');
  String get commonInfo => translate('common.info');
  String get commonRetry => translate('common.retry');
  String get commonSkip => translate('common.skip');
  String get commonNext => translate('common.next');
  String get commonPrevious => translate('common.previous');
  String get commonDone => translate('common.done');
  String get commonClose => translate('common.close');

  // Tips
  String get tipsWalkMore => translate('tips.walkMore');
  String get tipsUsePublicTransport => translate('tips.usePublicTransport');
  String get tipsEnergyEfficient => translate('tips.energyEfficient');
  String get tipsReduceWaste => translate('tips.reduceWaste');
  String get tipsLocalProducts => translate('tips.localProducts');
  String get tipsSmartThermostat => translate('tips.smartThermostat');

  // Errors
  String get errorsNetworkError => translate('errors.networkError');
  String get errorsPermissionDenied => translate('errors.permissionDenied');
  String get errorsLocationUnavailable => translate('errors.locationUnavailable');
  String get errorsMicrophoneUnavailable => translate('errors.microphoneUnavailable');
  String get errorsSaveError => translate('errors.saveError');
  String get errorsLoadError => translate('errors.loadError');
  String get errorsInvalidInput => translate('errors.invalidInput');
  String get errorsTryAgain => translate('errors.tryAgain');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}