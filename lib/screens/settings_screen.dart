import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageService _languageService = LanguageService.instance;
  final ThemeService _themeService = ThemeService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  String _userName = '';
  String _userEmail = '';
  bool _notificationsEnabled = true;
  bool _hapticFeedbackEnabled = true;
  bool _autoBackupEnabled = false;
  double _dailyCarbonGoal = 10.0;
  int _totalActivities = 0;
  double _totalCarbon = 0.0;
  String _joinDate = '';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadUserStats();
  }

  Future<void> _loadUserSettings() async {
    // Load user preferences - in a real app, this would come from a user service
    setState(() {
      _userName = 'Carbon Tracker User';
      _userEmail = 'user@carbontracker.com';
      _joinDate = '2024-01-01';
    });
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
      print('Error loading user stats: $e');
    }
  }

  Future<void> _exportData() async {
    try {
      final activities = await DatabaseService.instance.getAllActivities();
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_activities': activities.length,
        'activities': activities,
        'user_info': {
          'name': _userName,
          'email': _userEmail,
          'join_date': _joinDate,
        }
      };

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/carbon_tracker_export.json');
      await file.writeAsString(exportData.toString());

      await Share.shareXFiles([XFile(file.path)], text: _languageService.isEnglish 
        ? 'Carbon Tracker Data Export'
        : 'Carbon Tracker Veri Aktarımı');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.isEnglish 
            ? 'Data exported successfully!'
            : 'Veriler başarıyla aktarıldı!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.isEnglish 
            ? 'Export failed: $e'
            : 'Aktarım başarısız: $e'),
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.isEnglish ? 'Clear All Data' : 'Tüm Verileri Temizle'),
        content: Text(_languageService.isEnglish 
          ? 'This will permanently delete all your carbon tracking data. This action cannot be undone.'
          : 'Bu işlem tüm karbon takip verilerinizi kalıcı olarak silecektir. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_languageService.isEnglish ? 'Delete' : 'Sil'),
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
            content: Text(_languageService.isEnglish 
              ? 'All data cleared successfully'
              : 'Tüm veriler başarıyla temizlendi'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_languageService.isEnglish 
              ? 'Failed to clear data: $e'
              : 'Veri temizleme başarısız: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Settings' : 'Ayarlar'),
        backgroundColor: Colors.blue.withOpacity(0.1),
        foregroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(),
          ),
        ],
      ),
      body: LiquidPullRefresh(
        onRefresh: () async {
          await _loadUserSettings();
          await _loadUserStats();
        },
        color: Colors.blue,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              _buildProfileSection(),
              const SizedBox(height: 24),

              // App Preferences
              _buildAppPreferencesSection(),
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

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_languageService.isEnglish ? 'Member since' : 'Üye olma tarihi'}: $_joinDate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _editProfile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'App Preferences' : 'Uygulama Tercihleri',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Language Setting
            _buildPreferenceItem(
              icon: Icons.language,
              title: _languageService.isEnglish ? 'Language' : 'Dil',
              subtitle: _languageService.currentLanguageDisplayName,
              trailing: _languageService.currentLanguageFlag,
              onTap: () async {
                await _languageService.toggleLanguage();
                HapticFeedback.selectionClick();
              },
            ),

            const Divider(),

            // Theme Setting
            _buildPreferenceItem(
              icon: _themeService.themeIcon,
              title: _languageService.isEnglish ? 'Theme' : 'Tema',
              subtitle: _languageService.isEnglish ? _themeService.themeName : 
                (_themeService.themeName == 'Light' ? 'Açık' : 
                 _themeService.themeName == 'Dark' ? 'Koyu' : 'Sistem'),
              onTap: () async {
                await _themeService.toggleTheme();
                HapticFeedback.selectionClick();
              },
            ),

            const Divider(),

            // Notifications
            _buildSwitchPreference(
              icon: Icons.notifications,
              title: _languageService.isEnglish ? 'Notifications' : 'Bildirimler',
              subtitle: _languageService.isEnglish ? 'Receive carbon tracking reminders' : 'Karbon takip hatırlatıcıları al',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),

            const Divider(),

            // Haptic Feedback
            _buildSwitchPreference(
              icon: Icons.vibration,
              title: _languageService.isEnglish ? 'Haptic Feedback' : 'Titreşim Geri Bildirimi',
              subtitle: _languageService.isEnglish ? 'Feel vibrations for interactions' : 'Etkileşimler için titreşim hisset',
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
              title: _languageService.isEnglish ? 'Daily Carbon Goal' : 'Günlük Karbon Hedefi',
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

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'Your Statistics' : 'İstatistikleriniz',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    _languageService.isEnglish ? 'Total Activities' : 'Toplam Aktivite',
                    _totalActivities.toString(),
                    Icons.list_alt,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    _languageService.isEnglish ? 'Total CO₂' : 'Toplam CO₂',
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
              _languageService.isEnglish ? 'Data Management' : 'Veri Yönetimi',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildPreferenceItem(
              icon: Icons.download,
              title: _languageService.isEnglish ? 'Export Data' : 'Verileri Aktar',
              subtitle: _languageService.isEnglish ? 'Download your carbon tracking data' : 'Karbon takip verilerinizi indirin',
              onTap: _exportData,
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.upload,
              title: _languageService.isEnglish ? 'Import Data' : 'Verileri İçe Aktar',
              subtitle: _languageService.isEnglish ? 'Restore from backup file' : 'Yedekleme dosyasından geri yükle',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_languageService.isEnglish ? 'Import feature coming soon!' : 'İçe aktarma özelliği yakında!'),
                  ),
                );
              },
            ),

            const Divider(),

            _buildSwitchPreference(
              icon: Icons.cloud_upload,
              title: _languageService.isEnglish ? 'Auto Backup' : 'Otomatik Yedekleme',
              subtitle: _languageService.isEnglish ? 'Automatically backup data weekly' : 'Verileri haftalık otomatik yedekle',
              value: _autoBackupEnabled,
              onChanged: (value) {
                setState(() {
                  _autoBackupEnabled = value;
                });
              },
            ),

            const Divider(),

            _buildPreferenceItem(
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              title: _languageService.isEnglish ? 'Clear All Data' : 'Tüm Verileri Temizle',
              subtitle: _languageService.isEnglish ? 'Permanently delete all tracking data' : 'Tüm takip verilerini kalıcı olarak sil',
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
    String? trailing,
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
            if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 18)),
            if (onTap != null) const Icon(Icons.chevron_right, color: Colors.grey),
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
    required ValueChanged<bool> onChanged,
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
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_languageService.isEnglish ? 'Profile editing coming soon!' : 'Profil düzenleme yakında!'),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.isEnglish ? 'Help' : 'Yardım'),
        content: Text(_languageService.isEnglish
          ? 'Carbon Tracker helps you monitor and reduce your carbon footprint. Track your daily activities across transport, energy, food, and shopping categories.'
          : 'Carbon Tracker karbon ayak izinizi izlemenize ve azaltmanıza yardımcı olur. Ulaşım, enerji, yemek ve alışveriş kategorilerinde günlük aktivitelerinizi takip edin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'OK' : 'Tamam'),
          ),
        ],
      ),
    );
  }
}