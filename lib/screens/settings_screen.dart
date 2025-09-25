import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageService _languageService = LanguageService.instance;
  final ThemeService _themeService = ThemeService.instance;
  final PermissionService _permissionService = PermissionService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  String _userName = '';
  String _defaultUserName = '';
  String _userEmail = '';
  String _profileImagePath = '';
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
    _loadNotificationSettings();
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
        _profileImagePath = prefs.getString('user_profile_image') ?? '';
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

  Future<void> _saveUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_join_date', _joinDate);
    await prefs.setString('user_profile_image', _profileImagePath);
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
          await _loadNotificationSettings();
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
                GestureDetector(
                  onTap: _changeProfilePicture,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green,
                        backgroundImage: _profileImagePath.isNotEmpty 
                          ? FileImage(File(_profileImagePath)) 
                          : null,
                        child: _profileImagePath.isEmpty 
                          ? Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_languageService.currentLanguageFlag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                ],
              ),
              onTap: () => _showLanguageSettings(),
            ),

            const Divider(),

            // Theme Setting
            _buildPreferenceItem(
              icon: _themeService.themeIcon,
              title: _languageService.isEnglish ? 'Theme' : 'Tema',
              subtitle: _languageService.isEnglish ? _themeService.themeName : 
                (_themeService.themeName == 'Light' ? 'Açık' : 
                 _themeService.themeName == 'Dark' ? 'Koyu' : 'Sistem'),
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
                            _languageService.isEnglish ? 'Notifications' : 'Bildirimler',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _notificationsEnabled 
                              ? (_languageService.isEnglish ? 'Enabled' : 'Etkin')
                              : (_languageService.isEnglish ? 'Disabled' : 'Devre dışı'),
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
                    _languageService.isEnglish ? 'Edit Profile' : 'Profili Düzenle',
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
                  labelText: _languageService.isEnglish ? 'Username' : 'Kullanıcı Adı',
                  border: const OutlineInputBorder(),
                  hintText: _defaultUserName,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: _languageService.isEnglish ? 'Email' : 'E-posta',
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
                      error = _languageService.isEnglish ? 'Username cannot be empty' : 'Kullanıcı adı boş olamaz';
                    } else if (email.isEmpty || !RegExp(r'^.+@.+\..+').hasMatch(email)) {
                      // Basic email validation fallback
                      error = _languageService.isEnglish ? 'Please enter a valid email' : 'Geçerli bir e-posta girin';
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
                          content: Text(_languageService.isEnglish ? 'Profile updated' : 'Profil güncellendi'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(_languageService.isEnglish ? 'Save' : 'Kaydet'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageService.isEnglish ? 'Change Profile Picture' : 'Profil Fotoğrafını Değiştir',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: _languageService.isEnglish ? 'Camera' : 'Kamera',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 512,
                          maxHeight: 512,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          await _updateProfileImage(image.path);
                        }
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: _languageService.isEnglish ? 'Gallery' : 'Galeri',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          await _updateProfileImage(image.path);
                        }
                      },
                    ),
                    if (_profileImagePath.isNotEmpty)
                      _buildImageSourceOption(
                        icon: Icons.delete,
                        label: _languageService.isEnglish ? 'Remove' : 'Kaldır',
                        color: Colors.red,
                        onTap: () async {
                          Navigator.pop(context);
                          await _removeProfileImage();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.isEnglish ? 'Error accessing camera/gallery' : 'Kamera/galeri erişim hatası'),
        ),
      );
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color ?? Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfileImage(String imagePath) async {
    setState(() {
      _profileImagePath = imagePath;
    });
    await _saveUserSettings();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_languageService.isEnglish ? 'Profile picture updated' : 'Profil fotoğrafı güncellendi'),
      ),
    );
  }

  Future<void> _removeProfileImage() async {
    setState(() {
      _profileImagePath = '';
    });
    await _saveUserSettings();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_languageService.isEnglish ? 'Profile picture removed' : 'Profil fotoğrafı kaldırıldı'),
      ),
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
                        _languageService.isEnglish ? 'Notification Settings' : 'Bildirim Ayarları',
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
                  
                  // Master notification toggle
                  _buildModalSwitchItem(
                    title: _languageService.isEnglish ? 'Enable Notifications' : 'Bildirimleri Etkinleştir',
                    subtitle: _languageService.isEnglish ? 'Turn on/off all notifications' : 'Tüm bildirimleri aç/kapat',
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
                  
                  const Divider(),
                  
                  // Individual notification settings
                  AnimatedOpacity(
                    opacity: _notificationService.notificationsEnabled ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        _buildModalSwitchItem(
                          title: _languageService.isEnglish ? 'Daily Reminders' : 'Günlük Hatırlatıcılar',
                          subtitle: _languageService.isEnglish ? 'Get daily carbon tracking reminders' : 'Günlük karbon takip hatırlatıcıları al',
                          value: _notificationService.dailyRemindersEnabled,
                          enabled: _notificationService.notificationsEnabled,
                          onChanged: (value) async {
                            await _notificationService.updateSettings(dailyRemindersEnabled: value);
                            setModalState(() {});
                          },
                        ),
                        
                        const Divider(),
                        
                        _buildModalSwitchItem(
                          title: _languageService.isEnglish ? 'Achievement Notifications' : 'Başarı Bildirimleri',
                          subtitle: _languageService.isEnglish ? 'Get notified when you earn badges' : 'Rozet kazandığınızda bildirim al',
                          value: _notificationService.achievementNotificationsEnabled,
                          enabled: _notificationService.notificationsEnabled,
                          onChanged: (value) async {
                            await _notificationService.updateSettings(achievementNotificationsEnabled: value);
                            setModalState(() {});
                          },
                        ),
                        
                        const Divider(),
                        
                        _buildModalSwitchItem(
                          title: _languageService.isEnglish ? 'Weekly Reports' : 'Haftalık Raporlar',
                          subtitle: _languageService.isEnglish ? 'Receive weekly carbon footprint summaries' : 'Haftalık karbon ayak izi özetleri al',
                          value: _notificationService.weeklyReportsEnabled,
                          enabled: _notificationService.notificationsEnabled,
                          onChanged: (value) async {
                            await _notificationService.updateSettings(weeklyReportsEnabled: value);
                            setModalState(() {});
                          },
                        ),
                        
                        const Divider(),
                        
                        _buildModalSwitchItem(
                          title: _languageService.isEnglish ? 'Smart Suggestions' : 'Akıllı Öneriler',
                          subtitle: _languageService.isEnglish ? 'Get personalized eco-friendly tips' : 'Kişiselleştirilmiş çevre dostu ipuçları al',
                          value: _notificationService.smartSuggestionsEnabled,
                          enabled: _notificationService.notificationsEnabled,
                          onChanged: (value) async {
                            await _notificationService.updateSettings(smartSuggestionsEnabled: value);
                            setModalState(() {});
                          },
                        ),
                        
                        const Divider(),
                        
                        // Daily reminder time picker
                        if (_notificationService.dailyRemindersEnabled && _notificationService.notificationsEnabled)
                          _buildTimePicker(
                            title: _languageService.isEnglish ? 'Daily Reminder Time' : 'Günlük Hatırlatıcı Zamanı',
                            time: _notificationService.dailyReminderTime,
                            onTimeChanged: (time) async {
                              await _notificationService.updateSettings(dailyReminderTime: time);
                              setModalState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test notification button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _notificationService.notificationsEnabled ? () async {
                        await _notificationService.showSmartSuggestion(
                          _languageService.isEnglish 
                            ? 'This is a test notification from Carbon Tracker!' 
                            : 'Bu Carbon Tracker\'dan bir test bildirimidir!'
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_languageService.isEnglish ? 'Test notification sent!' : 'Test bildirimi gönderildi!'),
                            ),
                          );
                        }
                      } : null,
                      icon: const Icon(Icons.send),
                      label: Text(_languageService.isEnglish ? 'Send Test Notification' : 'Test Bildirimi Gönder'),
                    ),
                  ),
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
            label: Text(_languageService.isEnglish ? 'Change' : 'Değiştir'),
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
                        _languageService.isEnglish ? 'Theme Settings' : 'Tema Ayarları',
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
                    title: _languageService.isEnglish ? 'Light Theme' : 'Açık Tema',
                    subtitle: _languageService.isEnglish ? 'Bright and clean appearance' : 'Parlak ve temiz görünüm',
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
                    title: _languageService.isEnglish ? 'Dark Theme' : 'Koyu Tema',
                    subtitle: _languageService.isEnglish ? 'Easy on the eyes in low light' : 'Az ışıkta gözleri yormuyor',
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
                    title: _languageService.isEnglish ? 'System Theme' : 'Sistem Teması',
                    subtitle: _languageService.isEnglish ? 'Follow device settings' : 'Cihaz ayarlarını takip et',
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
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
            ? color.withOpacity(0.1) 
            : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
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
            return Padding(
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
                        _languageService.isEnglish ? 'Language Settings' : 'Dil Ayarları',
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
                  
                  // English option
                  _buildLanguageOption(
                    title: 'English',
                    subtitle: 'English language interface',
                    flag: '🇺🇸',
                    isSelected: _languageService.isEnglish,
                    onTap: () async {
                      if (!_languageService.isEnglish) {
                        await _languageService.setLanguage('en');
                        setModalState(() {});
                        setState(() {});
                        HapticFeedback.selectionClick();
                      }
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Turkish option
                  _buildLanguageOption(
                    title: 'Türkçe',
                    subtitle: 'Türkçe dil arabirimi',
                    flag: '🇹🇷',
                    isSelected: !_languageService.isEnglish,
                    onTap: () async {
                      if (_languageService.isEnglish) {
                        await _languageService.setLanguage('tr');
                        setModalState(() {});
                        setState(() {});
                        HapticFeedback.selectionClick();
                      }
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
  
  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
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
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
            ? Theme.of(context).primaryColor.withOpacity(0.1) 
            : Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
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
