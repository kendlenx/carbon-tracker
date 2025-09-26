import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/permission_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final LanguageService _languageService = LanguageService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  Map<String, bool> _permissionStates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissionStates();
  }

  Future<void> _loadPermissionStates() async {
    setState(() => _isLoading = true);
    
    try {
      // Load current permission states
      _permissionStates = {
        'location': await _permissionService.hasLocationPermission(),
        'camera': await _permissionService.hasCameraPermission(),
        'notifications': await _permissionService.hasNotificationPermission(),
        'storage': await _permissionService.hasStoragePermission(),
        'contacts': false, // Example additional permission
        'microphone': false, // Example additional permission
      };
    } catch (e) {
      debugPrint('Error loading permissions: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Permissions' : 'İzinler'),
        backgroundColor: Colors.orange.withValues(alpha: 0.1),
        foregroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showPermissionHelp,
          ),
        ],
      ),
      body: LiquidPullRefresh(
        onRefresh: _loadPermissionStates,
        color: Colors.orange,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Information Card
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Essential Permissions
                  _buildPermissionSection(
                    title: _languageService.isEnglish ? 'Essential Permissions' : 'Temel İzinler',
                    subtitle: _languageService.isEnglish 
                      ? 'Required for core app functionality'
                      : 'Uygulamanın temel işlevselliği için gerekli',
                    permissions: [
                      PermissionItem(
                        key: 'storage',
                        titleEn: 'Storage Access',
                        titleTr: 'Depolama Erişimi',
                        descriptionEn: 'Store and access your carbon tracking data',
                        descriptionTr: 'Karbon takip verilerinizi saklayın ve erişin',
                        icon: Icons.storage,
                        color: Colors.blue,
                        isRequired: true,
                      ),
                      PermissionItem(
                        key: 'notifications',
                        titleEn: 'Notifications',
                        titleTr: 'Bildirimler',
                        descriptionEn: 'Receive reminders and updates about your carbon goals',
                        descriptionTr: 'Karbon hedefleriniz hakkında hatırlatmalar ve güncellemeler alın',
                        icon: Icons.notifications,
                        color: Colors.green,
                        isRequired: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Enhanced Features
                  _buildPermissionSection(
                    title: _languageService.isEnglish ? 'Enhanced Features' : 'Gelişmiş Özellikler',
                    subtitle: _languageService.isEnglish 
                      ? 'Optional permissions for additional functionality'
                      : 'Ek işlevsellik için isteğe bağlı izinler',
                    permissions: [
                      PermissionItem(
                        key: 'location',
                        titleEn: 'Location Services',
                        titleTr: 'Konum Servisleri',
                        descriptionEn: 'Auto-detect transport methods and calculate accurate distances',
                        descriptionTr: 'Ulaşım yöntemlerini otomatik algıla ve doğru mesafeleri hesapla',
                        icon: Icons.location_on,
                        color: Colors.red,
                        isRequired: false,
                      ),
                      PermissionItem(
                        key: 'camera',
                        titleEn: 'Camera Access',
                        titleTr: 'Kamera Erişimi',
                        descriptionEn: 'Scan barcodes and QR codes for quick activity logging',
                        descriptionTr: 'Hızlı aktivite kaydı için barkodları ve QR kodlarını tarayın',
                        icon: Icons.camera_alt,
                        color: Colors.purple,
                        isRequired: false,
                      ),
                      PermissionItem(
                        key: 'microphone',
                        titleEn: 'Microphone Access',
                        titleTr: 'Mikrofon Erişimi',
                        descriptionEn: 'Use voice commands to quickly add activities',
                        descriptionTr: 'Aktiviteleri hızlıca eklemek için sesli komutları kullanın',
                        icon: Icons.mic,
                        color: Colors.teal,
                        isRequired: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Privacy & Security
                  _buildPrivacySection(),
                  const SizedBox(height: 24),

                  // Manage All Button
                  _buildManageAllButton(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.security, color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            Text(
              _languageService.isEnglish ? 'Privacy & Permissions' : 'Gizlilik ve İzinler',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _languageService.isEnglish 
                ? 'Your privacy is our priority. We only request permissions that enhance your Carbon Tracker experience. You can manage these settings anytime.'
                : 'Gizliliğiniz önceliğimizdir. Sadece Carbon Tracker deneyiminizi geliştiren izinleri istiyoruz. Bu ayarları istediğiniz zaman yönetebilirsiniz.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection({
    required String title,
    required String subtitle,
    required List<PermissionItem> permissions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        
        Card(
          child: Column(
            children: permissions.asMap().entries.map((entry) {
              final index = entry.key;
              final permission = entry.value;
              final isLast = index == permissions.length - 1;
              
              return Column(
                children: [
                  _buildPermissionTile(permission),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(PermissionItem permission) {
    final isGranted = _permissionStates[permission.key] ?? false;
    
    return MicroCard(
      onTap: () => _handlePermissionTap(permission),
      hapticType: HapticType.light,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: permission.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                permission.icon,
                color: permission.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        permission.getTitle(_languageService.isEnglish),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (permission.isRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _languageService.isEnglish ? 'Required' : 'Gerekli',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    permission.getDescription(_languageService.isEnglish),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGranted ? Icons.check_circle : Icons.circle_outlined,
                        size: 14,
                        color: isGranted ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isGranted 
                          ? (_languageService.isEnglish ? 'Granted' : 'Verildi')
                          : (_languageService.isEnglish ? 'Denied' : 'Reddedildi'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isGranted ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  _languageService.isEnglish ? 'Privacy & Security' : 'Gizlilik ve Güvenlik',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildPrivacyItem(
              icon: Icons.local_shipping,
              titleEn: 'Data stays on your device',
              titleTr: 'Veriler cihazınızda kalır',
              descriptionEn: 'Your carbon tracking data is stored locally and never sent to external servers without your consent.',
              descriptionTr: 'Karbon takip verileriniz yerel olarak saklanır ve izniniz olmadan dış sunuculara asla gönderilmez.',
            ),
            
            const SizedBox(height: 16),
            
            _buildPrivacyItem(
              icon: Icons.no_accounts,
              titleEn: 'No tracking or profiling',
              titleTr: 'Takip veya profil oluşturma yok',
              descriptionEn: 'We don\'t track your behavior or create profiles for advertising purposes.',
              descriptionTr: 'Davranışlarınızı takip etmiyoruz veya reklam amaçlı profiller oluşturmuyoruz.',
            ),
            
            const SizedBox(height: 16),
            
            _buildPrivacyItem(
              icon: Icons.verified_user,
              titleEn: 'Transparent permissions',
              titleTr: 'Şeffaf izinler',
              descriptionEn: 'We clearly explain why each permission is needed and how it improves your experience.',
              descriptionTr: 'Her iznin neden gerekli olduğunu ve deneyiminizi nasıl iyileştirdiğini açıkça açıklıyoruz.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String titleEn,
    required String titleTr,
    required String descriptionEn,
    required String descriptionTr,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _languageService.isEnglish ? titleEn : titleTr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _languageService.isEnglish ? descriptionEn : descriptionTr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManageAllButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openSystemSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.settings),
        label: Text(
          _languageService.isEnglish ? 'Open System Settings' : 'Sistem Ayarlarını Aç',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handlePermissionTap(PermissionItem permission) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _PermissionDetailSheet(
        permission: permission,
        isGranted: _permissionStates[permission.key] ?? false,
        languageService: _languageService,
        onRequest: () async {
          await _requestPermission(permission);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _requestPermission(PermissionItem permission) async {
    bool granted = false;
    
    switch (permission.key) {
      case 'location':
        granted = await _permissionService.requestLocationPermission();
        break;
      case 'camera':
        granted = await _permissionService.requestCameraPermission();
        break;
      case 'notifications':
        granted = await _permissionService.requestNotificationPermission();
        break;
      case 'storage':
        granted = await _permissionService.requestStoragePermission();
        break;
      default:
        // Handle other permissions
        break;
    }
    
    setState(() {
      _permissionStates[permission.key] = granted;
    });
    
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService.isEnglish 
              ? '${permission.titleEn} permission granted!'
              : '${permission.titleTr} izni verildi!',
          ),
        ),
      );
    }
  }

  void _openSystemSettings() async {
    await _permissionService.openAppSettings();
  }

  void _showPermissionHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.isEnglish ? 'About Permissions' : 'İzinler Hakkında'),
        content: Text(
          _languageService.isEnglish
            ? 'Permissions allow Carbon Tracker to access device features that enhance your experience. You can always change these settings later in your device\'s system settings.'
            : 'İzinler, Carbon Tracker\'ın deneyiminizi geliştiren cihaz özelliklerine erişmesine olanak tanır. Bu ayarları daha sonra cihazınızın sistem ayarlarından değiştirebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'Got it' : 'Anladım'),
          ),
        ],
      ),
    );
  }
}

class _PermissionDetailSheet extends StatelessWidget {
  final PermissionItem permission;
  final bool isGranted;
  final LanguageService languageService;
  final VoidCallback onRequest;

  const _PermissionDetailSheet({
    required this.permission,
    required this.isGranted,
    required this.languageService,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Permission icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: permission.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              permission.icon,
              color: permission.color,
              size: 40,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            permission.getTitle(languageService.isEnglish),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isGranted 
                ? (languageService.isEnglish ? 'Permission Granted' : 'İzin Verildi')
                : (languageService.isEnglish ? 'Permission Denied' : 'İzin Reddedildi'),
              style: TextStyle(
                color: isGranted ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            permission.getDescription(languageService.isEnglish),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Action button
          if (!isGranted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: permission.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  languageService.isEnglish ? 'Grant Permission' : 'İzin Ver',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Text(
              languageService.isEnglish 
                ? 'You can manage this permission in system settings.'
                : 'Bu izni sistem ayarlarından yönetebilirsiniz.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class PermissionItem {
  final String key;
  final String titleEn;
  final String titleTr;
  final String descriptionEn;
  final String descriptionTr;
  final IconData icon;
  final Color color;
  final bool isRequired;

  PermissionItem({
    required this.key,
    required this.titleEn,
    required this.titleTr,
    required this.descriptionEn,
    required this.descriptionTr,
    required this.icon,
    required this.color,
    required this.isRequired,
  });

  String getTitle(bool isEnglish) => isEnglish ? titleEn : titleTr;
  String getDescription(bool isEnglish) => isEnglish ? descriptionEn : descriptionTr;
}