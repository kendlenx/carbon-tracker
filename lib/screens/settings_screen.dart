import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/data_export_service.dart';
import '../services/security_service.dart';
import '../services/firebase_service.dart';
import 'cloud_backup_screen.dart';
import 'user_profile_screen.dart';
import 'privacy_policy_screen.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/export_share_widgets.dart' hide ExportFormat;
import '../widgets/share_composer_bottom_sheet.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentLanguageName() {
    final code = Localizations.localeOf(context).languageCode;
    final l = AppLocalizations.of(context)!;
    switch (code) {
      case 'tr':
        return l.translate('settings.turkish');
      case 'en':
        return l.translate('settings.english');
      case 'es':
        return l.translate('settings.spanish');
      case 'de':
        return l.translate('settings.german');
      case 'fr':
        return l.translate('settings.french');
      case 'it':
        return l.translate('settings.italian');
      case 'pt':
        return l.translate('settings.portuguese');
      case 'ru':
        return l.translate('settings.russian');
      default:
        return l.translate('settings.english');
    }
  }
  final LanguageService _languageService = LanguageService.instance;
  final ThemeService _themeService = ThemeService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final SecurityService _securityService = SecurityService();
  final FirebaseService _firebaseService = FirebaseService();

  String _userName = '';
  String _defaultUserName = '';
  String _userEmail = '';
  bool _notificationsEnabled = true;
  bool _hapticFeedbackEnabled = true;
  bool _autoBackupEnabled = false;
  bool _biometricEnabled = false;
  bool _appLockEnabled = false;
  Map<String, bool> _securityStatus = {};
  double _dailyCarbonGoal = 10.0;
  int _totalActivities = 0;
  double _totalCarbon = 0.0;
  String _joinDate = '';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadUserStats();
    _loadNotificationSettings();
    _loadSecuritySettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate default username if not exists
      String defaultUsername = prefs.getString('default_user_name') ?? '';
      if (defaultUsername.isEmpty) {
        final random = Random();
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final randomPart = random.nextInt(999).toString().padLeft(3, '0');
        // Use last 6 digits of timestamp + 3 random digits for uniqueness
        final uniquePart = timestamp.substring(timestamp.length - 6) + randomPart;
        defaultUsername = 'user_$uniquePart';
        await prefs.setString('default_user_name', defaultUsername);
      }
      
      setState(() {
        _defaultUserName = defaultUsername;
        _userName = prefs.getString('user_name') ?? defaultUsername;
        _userEmail = prefs.getString('user_email') ?? 'user@carbontracker.com';
        _joinDate = prefs.getString('user_join_date') ?? '2024-01-01';
      });
    } catch (e) {
      // Fallback to defaults
      final random = Random();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final randomPart = random.nextInt(999).toString().padLeft(3, '0');
      final uniquePart = timestamp.substring(timestamp.length - 6) + randomPart;
      final defaultUsername = 'user_$uniquePart';
      
      setState(() {
        _defaultUserName = defaultUsername;
        _userName = defaultUsername;
        _userEmail = 'user@carbontracker.com';
        _joinDate = '2024-01-01';
      });
    }
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      _notificationsEnabled = _notificationService.notificationsEnabled;
    });
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final securityStatus = await _securityService.getSecurityStatus();
      final biometricEnabled = await _securityService.isBiometricEnabled();
      final appLockEnabled = await _securityService.isAppLockEnabled();
      
      if (mounted) {
        setState(() {
          _securityStatus = securityStatus;
          _biometricEnabled = biometricEnabled;
          _appLockEnabled = appLockEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final success = await _securityService.enableBiometricAuth();
        if (success) {
          await _securityService.setAppLockEnabled(true);
          await _loadSecuritySettings();
          _showSecuritySnackBar(
            AppLocalizations.of(context)!.translate('settings.biometricEnabledSuccess'),
            Colors.green,
          );
        } else {
          _showSecuritySnackBar(
            AppLocalizations.of(context)!.translate('settings.biometricEnableFailed'),
            Colors.red,
          );
        }
      } else {
        await _securityService.disableBiometricAuth();
        await _loadSecuritySettings();
        _showSecuritySnackBar(
          AppLocalizations.of(context)!.translate('settings.biometricDisabled'),
          Colors.orange,
        );
      }
    } catch (e) {
      _showSecuritySnackBar(
        '${AppLocalizations.of(context)!.translate('common.error')}: $e',
        Colors.red,
      );
    }
  }

  void _showSecuritySnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.security,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_join_date', _joinDate);
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await DatabaseService.instance.getDashboardStats();
      final activities = await DatabaseService.instance.getAllActivities();
      
      setState(() {
        _totalActivities = activities.length;
        _totalCarbon = stats['totalCarbon'] ?? 0.0;
      });
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _exportData(ExportFormat format) async {
    try {
      await DataExportService.instance.exportAndShare(format);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('settings.export.success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.translate('settings.export.failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _showExportOptions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('settings.export.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.translate('settings.export.chooseFormat')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _exportData(ExportFormat.json);
                    },
                    icon: const Icon(Icons.code),
                    label: Text(AppLocalizations.of(context)!.translate('settings.export.jsonLabel')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _exportData(ExportFormat.csv);
                    },
                    icon: const Icon(Icons.table_chart),
                    label: Text(AppLocalizations.of(context)!.translate('settings.export.csvLabel')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
        ],
      ),
    );
  }
  
  Future<void> _importData() async {
    try {
      await DataExportService.instance.pickAndImportBackup();
      
      // Refresh stats after import
      await _loadUserStats();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('import.success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.translate('import.failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('settings.clearAllDataTitle')),
        content: Text(AppLocalizations.of(context)!.translate('settings.clearAllDataBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.translate('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.clearAllData();
        await _loadUserStats();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('settings.clearAllDataSuccess')),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.translate('settings.clearAllDataFailed')}: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: LiquidPullRefresh(
        onRefresh: () async {
          await _loadUserSettings();
          await _loadUserStats();
          await _loadNotificationSettings();
          await _loadSecuritySettings();
        },
        color: Colors.blue,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // User Account Section
            if (_firebaseService.isUserSignedIn)
              _buildUserAccountSection(),
            if (_firebaseService.isUserSignedIn)
              const SizedBox(height: 24),

              // App Preferences
              _buildAppPreferencesSection(),
              const SizedBox(height: 24),


              // Security Section
              _buildSecuritySection(),
              const SizedBox(height: 24),

              // User Stats
              _buildStatsSection(),
              const SizedBox(height: 24),

              // Data Management
              _buildDataManagementSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _openFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(),
    );
  }

  String _localizedThemeSubtitle() {
    // Map current theme to localized description
    final l = AppLocalizations.of(context)!;
    final mode = _themeService.themeMode;
    switch (mode) {
      case ThemeMode.light:
        return l.translate('settings.themeLightDesc');
      case ThemeMode.dark:
        return l.translate('settings.themeDarkDesc');
      case ThemeMode.system:
      default:
        return l.translate('settings.themeSystemDesc');
    }
  }

  Widget _buildAppPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.appPreferences'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Language Setting
              _buildPreferenceItem(
              icon: Icons.language,
              title: AppLocalizations.of(context)!.settingsLanguage,
              subtitle: _currentLanguageName(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_languageService.currentLanguageFlag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.withValues(alpha: 0.6)),
                ],
              ),
              onTap: () => _showLanguageSettings(),
            ),

            const Divider(),

            // Theme Setting
              _buildPreferenceItem(
              icon: _themeService.themeIcon,
              title: AppLocalizations.of(context)!.settingsTheme,
              subtitle: _localizedThemeSubtitle(),
              trailing: Icon(
                _themeService.themeIcon,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              onTap: () => _showThemeSettings(),
            ),

            const Divider(),

              // Notifications  
              MicroCard(
              onTap: () => _showNotificationSettings(),
              hapticType: HapticType.light,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.settingsNotifications,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _notificationsEnabled 
                              ? AppLocalizations.of(context)!.locationEnabled
                              : AppLocalizations.of(context)!.locationDisabled,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                          color: _notificationsEnabled ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(),

            // Feedback
            _buildPreferenceItem(
              icon: Icons.feedback,
              title: AppLocalizations.of(context)!.translate('ui.feedback'),
              subtitle: AppLocalizations.of(context)!.translate('settings.feedbackSubtitle'),
              onTap: _openFeedbackDialog,
            ),

            const Divider(),

            // Share progress
            _buildPreferenceItem(
              icon: Icons.share,
              title: AppLocalizations.of(context)!.translate('ui.shareProgress'),
              subtitle: AppLocalizations.of(context)!.translate('settings.shareSubtitle'),
              onTap: () => ShareComposerBottomSheet.show(context),
            ),

            const Divider(),

            // Haptic Feedback
            _buildSwitchPreference(
              icon: Icons.vibration,
              title: AppLocalizations.of(context)!.translate('ui.hapticFeedback'),
              subtitle: AppLocalizations.of(context)!.translate('settings.hapticSubtitle'),
              value: _hapticFeedbackEnabled,
              onChanged: (value) {
                setState(() {
                  _hapticFeedbackEnabled = value;
                });
              },
            ),

            const Divider(),

            // Daily Goal
            _buildSliderPreference(
              icon: Icons.flag,
              title: AppLocalizations.of(context)!.translate('ui.dailyCarbonGoal'),
              subtitle: '${_dailyCarbonGoal.toStringAsFixed(1)} kg CO₂',
              value: _dailyCarbonGoal,
              min: 1.0,
              max: 50.0,
              onChanged: (value) {
                setState(() {
                  _dailyCarbonGoal = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getUserDisplayName(currentUser) {
    // Önce Firebase displayName'i kontrol et
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      return currentUser.displayName!;
    }
    
    // Sonra local user name'i kontrol et
    if (_userName.isNotEmpty) {
      return _userName;
    }
    
    // En son generic text (localized)
    return AppLocalizations.of(context)!.translate('profile.user');
  }

  Widget _buildUserAccountSection() {
    final currentUser = _firebaseService.currentUser;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_circle,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getUserDisplayName(currentUser),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      currentUser?.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildPreferenceItem(
              icon: Icons.person,
              iconColor: Colors.blue,
              title: AppLocalizations.of(context)!.translate('ui.profileSettings'),
              subtitle: AppLocalizations.of(context)!.translate('ui.profileSettingsSubtitle'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUser?.emailVerified == true)
                    Icon(Icons.verified, color: Colors.green, size: 16)
                  else
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                );
              },
            ),
            
            const Divider(),
            
            _buildPreferenceItem(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: AppLocalizations.of(context)!.translate('ui.signOut'),
              subtitle: AppLocalizations.of(context)!.translate('ui.signOutSubtitle'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.translate('ui.signOut')),
                    content: Text(
                      AppLocalizations.of(context)!.translate('ui.signOutConfirmMessage')
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(AppLocalizations.of(context)!.translate('ui.signOut')),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await _firebaseService.signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.translate('ui.signedOutSuccess')),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh to update UI
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      AppLocalizations.of(context)!.translate('ui.securityPrivacy'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.translate('ui.securityPrivacySubtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Biometric Authentication
            _buildSwitchPreference(
              icon: _securityStatus['biometricsAvailable'] == true 
                ? Icons.fingerprint 
                : Icons.security,
              title: AppLocalizations.of(context)!.translate('settings.biometricAuthTitle'),
              subtitle: _securityStatus['biometricsAvailable'] == true
                ? AppLocalizations.of(context)!.translate('settings.biometricsUseHint')
                : AppLocalizations.of(context)!.translate('settings.biometricsNotAvailable'),
              value: _biometricEnabled && (_securityStatus['biometricsAvailable'] == true),
              onChanged: _securityStatus['biometricsAvailable'] == true 
                ? (bool value) {
                    _toggleBiometric(value);
                  }
                : null,
            ),

            const Divider(),

            // App Lock Status
            _buildPreferenceItem(
              icon: _appLockEnabled ? Icons.lock : Icons.lock_open,
              iconColor: _appLockEnabled ? Colors.green : Colors.orange,
              title: AppLocalizations.of(context)!.translate('settings.appLockStatus'),
              subtitle: _appLockEnabled 
                ? AppLocalizations.of(context)!.translate('settings.appSecured')
                : AppLocalizations.of(context)!.translate('settings.appUnlocked'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _appLockEnabled ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _appLockEnabled 
                    ? AppLocalizations.of(context)!.translate('settings.secureBadge')
                    : AppLocalizations.of(context)!.translate('settings.openBadge'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const Divider(),

            // Data Encryption Status
            _buildPreferenceItem(
              icon: Icons.enhanced_encryption,
              iconColor: _securityStatus['dataEncrypted'] == true ? Colors.green : Colors.grey,
              title: AppLocalizations.of(context)!.translate('settings.dataEncryption'),
              subtitle: _securityStatus['dataEncrypted'] == true
                ? AppLocalizations.of(context)!.translate('settings.dataEncrypted')
                : AppLocalizations.of(context)!.translate('settings.dataEncryptionDisabled'),
              trailing: Icon(
                _securityStatus['dataEncrypted'] == true 
                  ? Icons.check_circle 
                  : Icons.warning,
                color: _securityStatus['dataEncrypted'] == true 
                  ? Colors.green 
                  : Colors.orange,
              ),
            ),

            const Divider(),

            // Clear Security Data
            _buildPreferenceItem(
              icon: Icons.delete_sweep,
              iconColor: Colors.red,
              title: AppLocalizations.of(context)!.translate('settings.clearSecurityData'),
              subtitle: AppLocalizations.of(context)!.translate('settings.clearSecurityDataSubtitle'),
              onTap: _clearSecurityData,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearSecurityData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.translate('settings.clearSecurityConfirmTitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
          ],
        ),
        content: Text(AppLocalizations.of(context)!.translate('settings.clearSecurityConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.translate('settings.clear')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _securityService.clearSecureStorage();
        await _loadSecuritySettings();
        _showSecuritySnackBar(
          AppLocalizations.of(context)!.translate('settings.clearSecurityDataSuccess'),
          Colors.green,
        );
      } catch (e) {
        _showSecuritySnackBar(
          '${AppLocalizations.of(context)!.translate('settings.clearSecurityDataFailed')}: $e',
          Colors.red,
        );
      }
    }
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.yourStatistics'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context)!.translate('ui.totalActivities'),
                    _totalActivities.toString(),
                    Icons.list_alt,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context)!.translate('ui.totalCO2'),
                    '${_totalCarbon.toStringAsFixed(1)} kg',
                    Icons.cloud,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.dataManagement'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildPreferenceItem(
              icon: Icons.cloud,
              iconColor: Colors.blue,
              title: AppLocalizations.of(context)!.translate('ui.cloudBackup'),
              subtitle: _firebaseService.isUserSignedIn 
                ? AppLocalizations.of(context)!.translate('cloud.manageBackup')
                : AppLocalizations.of(context)!.translate('cloud.signInToBackup'),
              trailing: _firebaseService.isUserSignedIn
                ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                : Icon(Icons.cloud_off, color: Colors.orange, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CloudBackupScreen()),
                );
              },
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.download,
              title: AppLocalizations.of(context)!.translate('ui.exportData'),
              subtitle: AppLocalizations.of(context)!.translate('ui.exportDataSubtitle'),
              onTap: _showExportOptions,
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.upload,
              title: AppLocalizations.of(context)!.translate('ui.importData'),
              subtitle: AppLocalizations.of(context)!.translate('ui.importDataSubtitle'),
              onTap: _importData,
            ),

            const Divider(),

            _buildSwitchPreference(
              icon: Icons.cloud_upload,
              title: AppLocalizations.of(context)!.translate('ui.autoBackup'),
              subtitle: AppLocalizations.of(context)!.translate('ui.autoBackupSubtitle'),
              value: _autoBackupEnabled,
              onChanged: (value) {
                setState(() {
                  _autoBackupEnabled = value;
                });
              },
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.privacy_tip,
              iconColor: Colors.purple,
              title: AppLocalizations.of(context)!.translate('ui.privacyPolicy'),
              subtitle: AppLocalizations.of(context)!.translate('ui.privacyPolicySubtitle'),
              onTap: () => _navigateToPrivacyPolicy(),
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.security,
              iconColor: Colors.blue,
              title: AppLocalizations.of(context)!.translate('ui.dataConsent'),
              subtitle: AppLocalizations.of(context)!.translate('ui.dataConsentSubtitle'),
              onTap: () => _showConsentDialog(),
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              title: AppLocalizations.of(context)!.translate('ui.clearAllData'),
              subtitle: AppLocalizations.of(context)!.translate('ui.clearAllDataSubtitle'),
              onTap: _clearAllData,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return MicroCard(
      onTap: onTap,
      hapticType: onTap != null ? HapticType.light : HapticType.light,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null) const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchPreference({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade300
                      : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderPreference({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.translate('profile.editProfile'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate('profile.fullName'),
                  border: const OutlineInputBorder(),
                  hintText: _defaultUserName,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate('profile.emailAddress'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();

                    String? error;
                    if (name.isEmpty) {
                      error = AppLocalizations.of(context)!.translate('profile.nameEmpty');
                    } else if (email.isEmpty || !RegExp(r'^.+@.+\\..+').hasMatch(email)) {
                      // Basic email validation fallback
                      error = AppLocalizations.of(context)!.translate('auth.emailInvalid');
                    }

                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }

                    setState(() {
                      _userName = name;
                      _userEmail = email;
                    });
                    await _saveUserSettings();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.translate('profile.profileUpdated')),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(AppLocalizations.of(context)!.translate('common.save')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.settingsNotifications,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.translate('settings.notificationsIntro'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Single permission toggle only
                  _buildModalSwitchItem(
                    title: AppLocalizations.of(context)!.translate('settings.enableNotifications'),
                    subtitle: AppLocalizations.of(context)!.translate('settings.allowNotifications'),
                    value: _notificationService.notificationsEnabled,
                    onChanged: (value) async {
                      await _notificationService.updateSettings(notificationsEnabled: value);
                      setModalState(() {
                        _notificationsEnabled = value;
                      });
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildModalSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade600)
                      : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimePicker({
    required String title,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final newTime = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (newTime != null) {
                onTimeChanged(newTime);
              }
            },
            icon: const Icon(Icons.access_time),
            label: Text(AppLocalizations.of(context)!.translate('common.edit')),
          ),
        ],
      ),
    );
  }
  
  void _showThemeSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.settingsTheme,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Light theme option
                  _buildThemeOption(
                    title: AppLocalizations.of(context)!.settingsLightTheme,
                    subtitle: AppLocalizations.of(context)!.translate('settings.themeLightDesc'),
                    icon: Icons.light_mode,
                    color: Colors.orange,
                    isSelected: _themeService.themeMode == ThemeMode.light,
                    onTap: () async {
                      await _themeService.setTheme(ThemeMode.light);
                      setModalState(() {});
                      setState(() {});
                      HapticFeedback.selectionClick();
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Dark theme option
                  _buildThemeOption(
                    title: AppLocalizations.of(context)!.settingsDarkTheme,
                    subtitle: AppLocalizations.of(context)!.translate('settings.themeDarkDesc'),
                    icon: Icons.dark_mode,
                    color: Colors.indigo,
                    isSelected: _themeService.themeMode == ThemeMode.dark,
                    onTap: () async {
                      await _themeService.setTheme(ThemeMode.dark);
                      setModalState(() {});
                      setState(() {});
                      HapticFeedback.selectionClick();
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // System theme option
                  _buildThemeOption(
                    title: AppLocalizations.of(context)!.settingsSystemTheme,
                    subtitle: AppLocalizations.of(context)!.translate('settings.themeSystemDesc'),
                    icon: Icons.settings_system_daydream,
                    color: Colors.purple,
                    isSelected: _themeService.themeMode == ThemeMode.system,
                    onTap: () async {
                      await _themeService.setTheme(ThemeMode.system);
                      setModalState(() {});
                      setState(() {});
                      HapticFeedback.selectionClick();
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
            ? color.withValues(alpha: 0.1) 
            : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showLanguageSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.language, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                        AppLocalizations.of(context)!.settingsLanguage,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Dynamic language list from LanguageService
                      ...[
                        'en','tr','es','de','fr','it','pt','ru'
                      ].map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildLanguageOption(
                          title: _languageService.getLanguageDisplayName(code),
                          subtitle: null,
                          flag: _languageService.getLanguageFlag(code),
                          isSelected: _languageService.currentLanguageCode == code,
                          onTap: () async {
                            if (_languageService.currentLanguageCode != code) {
                              await _languageService.setLanguage(code);
                              setModalState(() {});
                              setState(() {});
                              HapticFeedback.selectionClick();
                            }
                          },
                        ),
                      )),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildLanguageOption({
    required String title,
    String? subtitle,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1) 
            : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                flag,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('ui.helpTitle')),
        content: Text(AppLocalizations.of(context)!.translate('ui.helpBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.ok')),
          ),
        ],
      ),
    );
  }

  void _navigateToPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      builder: (context) => const ConsentDialog(),
    );
  }
}
