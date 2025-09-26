import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler show openAppSettings;

enum AppPermission {
  location,
  locationAlways,
  microphone,
  notification,
  camera,
  storage,
  phone,
  sensors,
  activityRecognition,
}

class PermissionInfo {
  final AppPermission permission;
  final String name;
  final String description;
  final IconData icon;
  final bool isRequired;
  final Permission systemPermission;

  const PermissionInfo({
    required this.permission,
    required this.name,
    required this.description,
    required this.icon,
    required this.isRequired,
    required this.systemPermission,
  });
}

class PermissionService extends ChangeNotifier {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();
  
  PermissionService._();

  bool _isInitialized = false;
  Map<AppPermission, PermissionStatus> _permissionStatuses = {};
  Set<AppPermission> _requestedPermissions = {};

  // Permission definitions
  static const List<PermissionInfo> _permissionInfos = [
    PermissionInfo(
      permission: AppPermission.location,
      name: 'Konum',
      description: 'Ulaşım otomatik takibi ve yakındaki çevre dostu rotalar için gerekli',
      icon: Icons.location_on,
      isRequired: true,
      systemPermission: Permission.location,
    ),
    PermissionInfo(
      permission: AppPermission.locationAlways,
      name: 'Her Zaman Konum',
      description: 'Arka planda otomatik yolculuk takibi için isteğe bağlı',
      icon: Icons.location_history,
      isRequired: false,
      systemPermission: Permission.locationAlways,
    ),
    PermissionInfo(
      permission: AppPermission.microphone,
      name: 'Mikrofon',
      description: 'Sesli komutlar ve aktivite kaydı için gerekli',
      icon: Icons.mic,
      isRequired: true,
      systemPermission: Permission.microphone,
    ),
    PermissionInfo(
      permission: AppPermission.notification,
      name: 'Bildirimler',
      description: 'Günlük hatırlatmalar ve başarı bildirimleri için gerekli',
      icon: Icons.notifications,
      isRequired: true,
      systemPermission: Permission.notification,
    ),
    PermissionInfo(
      permission: AppPermission.camera,
      name: 'Kamera',
      description: 'Fatura QR kodu okuma için isteğe bağlı',
      icon: Icons.camera_alt,
      isRequired: false,
      systemPermission: Permission.camera,
    ),
    PermissionInfo(
      permission: AppPermission.storage,
      name: 'Depolama',
      description: 'Veri yedekleme ve rapor kaydetme için isteğe bağlı',
      icon: Icons.storage,
      isRequired: false,
      systemPermission: Permission.storage,
    ),
    PermissionInfo(
      permission: AppPermission.phone,
      name: 'Telefon',
      description: 'Cihaz tanımlaması için isteğe bağlı',
      icon: Icons.phone,
      isRequired: false,
      systemPermission: Permission.phone,
    ),
    PermissionInfo(
      permission: AppPermission.sensors,
      name: 'Sensörler',
      description: 'Adım sayma ve aktivite algılama için isteğe bağlı',
      icon: Icons.sensors,
      isRequired: false,
      systemPermission: Permission.sensors,
    ),
    PermissionInfo(
      permission: AppPermission.activityRecognition,
      name: 'Aktivite Tanıma',
      description: 'Otomatik ulaşım türü algılama için isteğe bağlı',
      icon: Icons.directions_run,
      isRequired: false,
      systemPermission: Permission.activityRecognition,
    ),
  ];

  // Getters
  bool get isInitialized => _isInitialized;
  Map<AppPermission, PermissionStatus> get permissionStatuses => _permissionStatuses;
  List<PermissionInfo> get allPermissions => _permissionInfos;
  List<PermissionInfo> get requiredPermissions => _permissionInfos.where((p) => p.isRequired).toList();
  List<PermissionInfo> get optionalPermissions => _permissionInfos.where((p) => !p.isRequired).toList();
  Set<AppPermission> get requestedPermissions => _requestedPermissions;

  /// Initialize permission service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadRequestedPermissions();
    await _checkAllPermissions();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Check all permissions status
  Future<void> _checkAllPermissions() async {
    for (final permissionInfo in _permissionInfos) {
      final status = await permissionInfo.systemPermission.status;
      _permissionStatuses[permissionInfo.permission] = status;
    }
  }

  /// Request all required permissions
  Future<Map<AppPermission, PermissionStatus>> requestRequiredPermissions() async {
    final results = <AppPermission, PermissionStatus>{};
    
    for (final permissionInfo in requiredPermissions) {
      final status = await requestPermission(permissionInfo.permission);
      results[permissionInfo.permission] = status;
    }
    
    return results;
  }

  /// Request specific permission
  Future<PermissionStatus> requestPermission(AppPermission permission) async {
    final permissionInfo = _getPermissionInfo(permission);
    if (permissionInfo == null) return PermissionStatus.denied;

    // Check current status first
    PermissionStatus status = await permissionInfo.systemPermission.status;
    
    // If already granted, return immediately
    if (status == PermissionStatus.granted) {
      _permissionStatuses[permission] = status;
      return status;
    }

    // If permanently denied, guide user to settings
    if (status == PermissionStatus.permanentlyDenied) {
      _permissionStatuses[permission] = status;
      notifyListeners();
      return status;
    }

    // Request permission
    try {
      status = await permissionInfo.systemPermission.request();
      _permissionStatuses[permission] = status;
      
      // Track that we've requested this permission
      _requestedPermissions.add(permission);
      await _saveRequestedPermissions();
      
      notifyListeners();
      return status;
    } catch (e) {
      debugPrint('Error requesting permission $permission: $e');
      status = PermissionStatus.denied;
      _permissionStatuses[permission] = status;
      notifyListeners();
      return status;
    }
  }

  /// Check if permission is granted
  bool isPermissionGranted(AppPermission permission) {
    final status = _permissionStatuses[permission];
    return status == PermissionStatus.granted;
  }

  /// Check if permission is denied
  bool isPermissionDenied(AppPermission permission) {
    final status = _permissionStatuses[permission];
    return status == PermissionStatus.denied;
  }

  /// Check if permission is permanently denied
  bool isPermissionPermanentlyDenied(AppPermission permission) {
    final status = _permissionStatuses[permission];
    return status == PermissionStatus.permanentlyDenied;
  }

  /// Check if all required permissions are granted
  bool areRequiredPermissionsGranted() {
    return requiredPermissions.every((permissionInfo) => 
        isPermissionGranted(permissionInfo.permission));
  }

  /// Get permissions that need to be requested
  List<PermissionInfo> getPermissionsToRequest() {
    return _permissionInfos.where((permissionInfo) {
      final status = _permissionStatuses[permissionInfo.permission];
      return status == null || 
             status == PermissionStatus.denied || 
             status == PermissionStatus.restricted;
    }).toList();
  }

  /// Get denied permissions
  List<PermissionInfo> getDeniedPermissions() {
    return _permissionInfos.where((permissionInfo) {
      final status = _permissionStatuses[permissionInfo.permission];
      return status == PermissionStatus.denied || 
             status == PermissionStatus.permanentlyDenied;
    }).toList();
  }

  /// Open app settings  
  Future<bool> openSettings() async {
    try {
      return await permission_handler.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Get permission status text
  String getPermissionStatusText(AppPermission permission, BuildContext context) {
    final status = _permissionStatuses[permission];
    
    switch (status) {
      case PermissionStatus.granted:
        return 'Verildi';
      case PermissionStatus.denied:
        return 'Reddedildi';
      case PermissionStatus.permanentlyDenied:
        return 'Kalıcı Olarak Reddedildi';
      case PermissionStatus.restricted:
        return 'Kısıtlı';
      case PermissionStatus.limited:
        return 'Sınırlı';
      default:
        return 'Bilinmiyor';
    }
  }

  /// Get permission status color
  Color getPermissionStatusColor(AppPermission permission) {
    final status = _permissionStatuses[permission];
    
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.grey;
      case PermissionStatus.limited:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Show permission rationale dialog
  Future<bool> showPermissionRationaleDialog(
    BuildContext context,
    PermissionInfo permissionInfo,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(permissionInfo.icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(permissionInfo.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(permissionInfo.description),
            const SizedBox(height: 16),
            if (permissionInfo.isRequired)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu izin uygulamanın düzgün çalışması için gereklidir.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show permissions overview screen
  Future<void> showPermissionsOverview(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uygulama İzinleri'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bu uygulama aşağıdaki izinleri kullanmaktadır:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _permissionInfos.length,
                  itemBuilder: (context, index) {
                    final permissionInfo = _permissionInfos[index];
                    final status = _permissionStatuses[permissionInfo.permission];
                    
                    return ListTile(
                      leading: Icon(
                        permissionInfo.icon,
                        color: getPermissionStatusColor(permissionInfo.permission),
                      ),
                      title: Text(permissionInfo.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(permissionInfo.description, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: permissionInfo.isRequired ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  permissionInfo.isRequired ? 'Gerekli' : 'İsteğe Bağlı',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: permissionInfo.isRequired ? Colors.red : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                getPermissionStatusText(permissionInfo.permission, context),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: getPermissionStatusColor(permissionInfo.permission),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: !isPermissionGranted(permissionInfo.permission)
                          ? IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () async {
                                if (isPermissionPermanentlyDenied(permissionInfo.permission)) {
                                  await openSettings();
                                } else {
                                  await requestPermission(permissionInfo.permission);
                                }
                              },
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
          if (!areRequiredPermissionsGranted())
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await requestRequiredPermissions();
              },
              child: const Text('Gerekli İzinleri Ver'),
            ),
        ],
      ),
    );
  }

  /// Get permission info by permission type
  PermissionInfo? _getPermissionInfo(AppPermission permission) {
    try {
      return _permissionInfos.firstWhere((info) => info.permission == permission);
    } catch (e) {
      return null;
    }
  }

  /// Load requested permissions from storage
  Future<void> _loadRequestedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestedList = prefs.getStringList('requested_permissions') ?? [];
      _requestedPermissions = requestedList.map((name) => 
          AppPermission.values.firstWhere((p) => p.name == name)).toSet();
    } catch (e) {
      debugPrint('Error loading requested permissions: $e');
    }
  }

  /// Save requested permissions to storage
  Future<void> _saveRequestedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestedList = _requestedPermissions.map((p) => p.name).toList();
      await prefs.setStringList('requested_permissions', requestedList);
    } catch (e) {
      debugPrint('Error saving requested permissions: $e');
    }
  }

  /// Refresh all permission statuses
  Future<void> refreshPermissionStatuses() async {
    await _checkAllPermissions();
    notifyListeners();
  }

  /// Check if this is the first time requesting permissions
  bool isFirstTimeSetup() {
    return _requestedPermissions.isEmpty;
  }

  /// Show first-time permission setup flow
  Future<bool> showFirstTimePermissionSetup(BuildContext context) async {
    if (!isFirstTimeSetup()) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🌱 Carbon Tracker\'a Hoş Geldiniz!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Karbon ayak izinizi etkili bir şekilde takip edebilmek için bazı izinlere ihtiyacımız var.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              '• Konum: Otomatik yolculuk takibi\n'
              '• Mikrofon: Sesli komutlar\n'
              '• Bildirimler: Günlük hatırlatmalar',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Daha Sonra'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İzinleri Ver'),
          ),
        ],
      ),
    );

    if (result == true) {
      await requestRequiredPermissions();
      return areRequiredPermissionsGranted();
    }

    return false;
  }

  // Convenience methods for permission screen
  Future<bool> hasLocationPermission() async {
    return isPermissionGranted(AppPermission.location);
  }

  Future<bool> hasCameraPermission() async {
    return isPermissionGranted(AppPermission.camera);
  }

  Future<bool> hasNotificationPermission() async {
    return isPermissionGranted(AppPermission.notification);
  }

  Future<bool> hasStoragePermission() async {
    return isPermissionGranted(AppPermission.storage);
  }

  Future<bool> requestLocationPermission() async {
    final status = await requestPermission(AppPermission.location);
    return status == PermissionStatus.granted;
  }

  Future<bool> requestCameraPermission() async {
    final status = await requestPermission(AppPermission.camera);
    return status == PermissionStatus.granted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await requestPermission(AppPermission.notification);
    return status == PermissionStatus.granted;
  }

  Future<bool> requestStoragePermission() async {
    final status = await requestPermission(AppPermission.storage);
    return status == PermissionStatus.granted;
  }

  Future<bool> openAppSettings() async {
    return await openSettings();
  }
}