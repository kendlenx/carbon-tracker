import 'package:flutter/material.dart';
import '../services/device_integration_framework.dart';
import '../services/language_service.dart';
import '../integrations/tesla_integration.dart';
import '../integrations/healthkit_integration.dart';
import '../integrations/smart_home_integration.dart';
import '../widgets/micro_interactions.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  
  final DeviceIntegrationService _deviceService = DeviceIntegrationService.instance;
  final LanguageService _languageService = LanguageService.instance;
  
  List<DeviceIntegration> _connectedDevices = [];
  Map<String, DeviceHealthInfo> _deviceHealth = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _tabController = TabController(length: 3, vsync: this);
    
    _registerIntegrations();
    _loadDevices();
    _setupEventListeners();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _registerIntegrations() {
    // Register all available integrations
    registerTeslaIntegration();
    registerHealthKitIntegration();
    registerSmartHomeIntegrations();
  }

  void _setupEventListeners() {
    _deviceService.events.listen((event) {
      if (mounted) {
        _handleDeviceEvent(event);
      }
    });
  }

  void _handleDeviceEvent(DeviceEvent event) {
    switch (event.type) {
      case DeviceEventType.deviceConnected:
        _showSnackBar(
          _languageService.isEnglish
              ? 'Device connected: ${event.data['deviceName']}'
              : 'Cihaz bağlandı: ${event.data['deviceName']}',
          Colors.green,
        );
        _loadDevices();
        break;
      case DeviceEventType.deviceDisconnected:
        _showSnackBar(
          _languageService.isEnglish
              ? 'Device disconnected: ${event.data['deviceName']}'
              : 'Cihaz bağlantısı kesildi: ${event.data['deviceName']}',
          Colors.orange,
        );
        _loadDevices();
        break;
      case DeviceEventType.deviceError:
        _showSnackBar(
          _languageService.isEnglish
              ? 'Device error: ${event.data['error']}'
              : 'Cihaz hatası: ${event.data['error']}',
          Colors.red,
        );
        break;
      case DeviceEventType.syncCompleted:
        _showSnackBar(
          _languageService.isEnglish
              ? '${event.data['dataPointsCount']} data points synced'
              : '${event.data['dataPointsCount']} veri noktası senkronize edildi',
          Colors.blue,
        );
        break;
      default:
        break;
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devices = _deviceService.connectedDevices;
      final healthMap = await _deviceService.checkAllDevicesHealth();
      
      setState(() {
        _connectedDevices = devices;
        _deviceHealth = healthMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        _languageService.isEnglish
            ? 'Failed to load devices: $e'
            : 'Cihazlar yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Device Manager' : 'Cihaz Yöneticisi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.devices),
              text: isEnglish ? 'Connected' : 'Bağlı',
            ),
            Tab(
              icon: const Icon(Icons.add_circle_outline),
              text: isEnglish ? 'Add Device' : 'Cihaz Ekle',
            ),
            Tab(
              icon: const Icon(Icons.settings),
              text: isEnglish ? 'Settings' : 'Ayarlar',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectedDevicesTab(),
          _buildAddDeviceTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildConnectedDevicesTab() {
    final isEnglish = _languageService.isEnglish;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_connectedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isEnglish
                  ? 'No devices connected\nAdd devices to start tracking'
                  : 'Bağlı cihaz yok\nTakip başlatmak için cihaz ekleyin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.add),
              label: Text(isEnglish ? 'Add Device' : 'Cihaz Ekle'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _connectedDevices.length,
        itemBuilder: (context, index) {
          final device = _connectedDevices[index];
          final health = _deviceHealth[device.deviceId];
          
          return _buildDeviceCard(device, health);
        },
      ),
    );
  }

  Widget _buildDeviceCard(DeviceIntegration device, DeviceHealthInfo? health) {
    final isEnglish = _languageService.isEnglish;
    final statusColor = _getStatusColor(device.connectionStatus);
    final deviceIcon = _getDeviceIcon(device.deviceType);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MicroCard(
        onTap: () => _showDeviceDetails(device, health),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      deviceIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.manufacturerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(device.connectionStatus),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Health indicators
              if (health != null) ...[
                Row(
                  children: [
                    Icon(
                      health.isHealthy ? Icons.check_circle : Icons.warning,
                      color: health.isHealthy ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      health.isHealthy
                          ? (isEnglish ? 'Healthy' : 'Sağlıklı')
                          : (isEnglish ? 'Issues detected' : 'Sorun tespit edildi'),
                      style: TextStyle(
                        fontSize: 12,
                        color: health.isHealthy ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (device.lastSyncTime != null)
                      Text(
                        '${isEnglish ? 'Last sync:' : 'Son senkron:'} ${_formatLastSync(device.lastSyncTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                
                if (health.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...health.warnings.take(2).map((warning) => Row(
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ],
              
              const SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _syncDevice(device),
                    icon: const Icon(Icons.sync, size: 16),
                    label: Text(isEnglish ? 'Sync' : 'Senkron'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _configureDevice(device),
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(isEnglish ? 'Configure' : 'Yapılandır'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _removeDevice(device),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DeviceConnectionStatus status) {
    final isEnglish = _languageService.isEnglish;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status, isEnglish);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildAddDeviceTab() {
    final isEnglish = _languageService.isEnglish;
    final availableTypes = _deviceService.getAvailableDeviceTypes();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isEnglish ? 'Available Device Types' : 'Kullanılabilir Cihaz Türleri',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...availableTypes.map((deviceType) => 
          _buildDeviceTypeCard(deviceType)
        ),
      ],
    );
  }

  Widget _buildDeviceTypeCard(DeviceType deviceType) {
    final isEnglish = _languageService.isEnglish;
    final deviceInfo = _getDeviceTypeInfo(deviceType, isEnglish);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MicroCard(
        onTap: () => _addDevice(deviceType),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: deviceInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  deviceInfo['icon'],
                  color: deviceInfo['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceInfo['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deviceInfo['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final isEnglish = _languageService.isEnglish;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isEnglish ? 'Privacy Settings' : 'Gizlilik Ayarları',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildPrivacyLevelCard(),
        
        const SizedBox(height: 24),
        
        Text(
          isEnglish ? 'Sync Settings' : 'Senkron Ayarları',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSyncSettingsCard(),
      ],
    );
  }

  Widget _buildPrivacyLevelCard() {
    final isEnglish = _languageService.isEnglish;
    final currentLevel = _deviceService.privacyLevel;
    
    return MicroCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish ? 'Data Collection Level' : 'Veri Toplama Düzeyi',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...PrivacyLevel.values.map((level) => RadioListTile<PrivacyLevel>(
              title: Text(_getPrivacyLevelTitle(level, isEnglish)),
              subtitle: Text(_getPrivacyLevelDescription(level, isEnglish)),
              value: level,
              groupValue: currentLevel,
              onChanged: (value) {
                if (value != null) {
                  _updatePrivacyLevel(value);
                }
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettingsCard() {
    final isEnglish = _languageService.isEnglish;
    
    return MicroCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish ? 'Synchronization' : 'Senkronizasyon',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(isEnglish ? 'Sync All Devices' : 'Tüm Cihazları Senkronize Et'),
              subtitle: Text(isEnglish ? 'Update data from all connected devices' : 'Tüm bağlı cihazlardan veri güncelle'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              contentPadding: EdgeInsets.zero,
              onTap: _syncAllDevices,
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.health_and_safety),
              title: Text(isEnglish ? 'Device Health Check' : 'Cihaz Sağlık Kontrolü'),
              subtitle: Text(isEnglish ? 'Check status of all devices' : 'Tüm cihazların durumunu kontrol et'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              contentPadding: EdgeInsets.zero,
              onTap: _checkDeviceHealth,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods

  Color _getStatusColor(DeviceConnectionStatus status) {
    switch (status) {
      case DeviceConnectionStatus.connected:
        return Colors.green;
      case DeviceConnectionStatus.connecting:
      case DeviceConnectionStatus.syncing:
        return Colors.blue;
      case DeviceConnectionStatus.disconnected:
        return Colors.grey;
      case DeviceConnectionStatus.error:
      case DeviceConnectionStatus.unauthorized:
        return Colors.red;
    }
  }

  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.smartVehicle:
        return Icons.directions_car;
      case DeviceType.fitnessTracker:
        return Icons.fitness_center;
      case DeviceType.smartThermostat:
        return Icons.thermostat;
      case DeviceType.smartPlug:
        return Icons.electrical_services;
      case DeviceType.energyMonitor:
        return Icons.electric_meter;
      case DeviceType.publicTransport:
        return Icons.train;
      case DeviceType.ridesharing:
        return Icons.local_taxi;
      case DeviceType.navigationApp:
        return Icons.navigation;
    }
  }

  String _getStatusText(DeviceConnectionStatus status, bool isEnglish) {
    switch (status) {
      case DeviceConnectionStatus.connected:
        return isEnglish ? 'Connected' : 'Bağlı';
      case DeviceConnectionStatus.connecting:
        return isEnglish ? 'Connecting' : 'Bağlanıyor';
      case DeviceConnectionStatus.syncing:
        return isEnglish ? 'Syncing' : 'Senkronize Ediliyor';
      case DeviceConnectionStatus.disconnected:
        return isEnglish ? 'Disconnected' : 'Bağlantı Kesildi';
      case DeviceConnectionStatus.error:
        return isEnglish ? 'Error' : 'Hata';
      case DeviceConnectionStatus.unauthorized:
        return isEnglish ? 'Unauthorized' : 'Yetkisiz';
    }
  }

  Map<String, dynamic> _getDeviceTypeInfo(DeviceType deviceType, bool isEnglish) {
    switch (deviceType) {
      case DeviceType.smartVehicle:
        return {
          'title': isEnglish ? 'Smart Vehicle' : 'Akıllı Araç',
          'description': isEnglish 
              ? 'Tesla, BMW, or OBD-II compatible vehicles'
              : 'Tesla, BMW veya OBD-II uyumlu araçlar',
          'icon': Icons.directions_car,
          'color': Colors.blue,
        };
      case DeviceType.fitnessTracker:
        return {
          'title': isEnglish ? 'Fitness Tracker' : 'Fitness Takipçisi',
          'description': isEnglish 
              ? 'Apple HealthKit, Google Fit, Fitbit'
              : 'Apple HealthKit, Google Fit, Fitbit',
          'icon': Icons.fitness_center,
          'color': Colors.orange,
        };
      case DeviceType.smartThermostat:
        return {
          'title': isEnglish ? 'Smart Thermostat' : 'Akıllı Termostat',
          'description': isEnglish 
              ? 'Nest, Ecobee, and other smart thermostats'
              : 'Nest, Ecobee ve diğer akıllı termostatlar',
          'icon': Icons.thermostat,
          'color': Colors.green,
        };
      case DeviceType.smartPlug:
        return {
          'title': isEnglish ? 'Smart Plug' : 'Akıllı Priz',
          'description': isEnglish 
              ? 'TP-Link, Amazon, and other smart plugs'
              : 'TP-Link, Amazon ve diğer akıllı prizler',
          'icon': Icons.electrical_services,
          'color': Colors.purple,
        };
      default:
        return {
          'title': deviceType.toString(),
          'description': isEnglish ? 'Generic device' : 'Genel cihaz',
          'icon': Icons.device_unknown,
          'color': Colors.grey,
        };
    }
  }

  String _getPrivacyLevelTitle(PrivacyLevel level, bool isEnglish) {
    switch (level) {
      case PrivacyLevel.minimal:
        return isEnglish ? 'Minimal' : 'Minimal';
      case PrivacyLevel.balanced:
        return isEnglish ? 'Balanced' : 'Dengeli';
      case PrivacyLevel.comprehensive:
        return isEnglish ? 'Comprehensive' : 'Kapsamlı';
    }
  }

  String _getPrivacyLevelDescription(PrivacyLevel level, bool isEnglish) {
    switch (level) {
      case PrivacyLevel.minimal:
        return isEnglish 
            ? 'Only essential data for basic tracking'
            : 'Sadece temel takip için gerekli veriler';
      case PrivacyLevel.balanced:
        return isEnglish 
            ? 'Standard data collection for insights'
            : 'Öngörüler için standart veri toplama';
      case PrivacyLevel.comprehensive:
        return isEnglish 
            ? 'Full data collection for detailed analysis'
            : 'Detaylı analiz için tam veri toplama';
    }
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return _languageService.isEnglish ? 'Just now' : 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  // Action methods

  void _showDeviceDetails(DeviceIntegration device, DeviceHealthInfo? health) {
    showDialog(
      context: context,
      builder: (context) => DeviceDetailsDialog(
        device: device,
        health: health,
      ),
    );
  }

  Future<void> _syncDevice(DeviceIntegration device) async {
    try {
      await _deviceService.syncDevice(device.deviceId);
    } catch (e) {
      _showSnackBar(
        _languageService.isEnglish
            ? 'Sync failed: $e'
            : 'Senkron başarısız: $e',
        Colors.red,
      );
    }
  }

  void _configureDevice(DeviceIntegration device) {
    showDialog(
      context: context,
      builder: (context) => DeviceConfigDialog(
        device: device,
        onConfigUpdated: _loadDevices,
      ),
    );
  }

  Future<void> _removeDevice(DeviceIntegration device) async {
    final isEnglish = _languageService.isEnglish;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Remove Device' : 'Cihazı Kaldır'),
        content: Text(
          isEnglish
              ? 'Are you sure you want to remove "${device.deviceName}"?'
              : '"${device.deviceName}" cihazını kaldırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEnglish ? 'Cancel' : 'İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isEnglish ? 'Remove' : 'Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deviceService.removeDevice(device.deviceId);
      _loadDevices();
    }
  }

  void _addDevice(DeviceType deviceType) {
    showDialog(
      context: context,
      builder: (context) => AddDeviceDialog(
        deviceType: deviceType,
        onDeviceAdded: _loadDevices,
      ),
    );
  }

  Future<void> _updatePrivacyLevel(PrivacyLevel level) async {
    await _deviceService.setPrivacyLevel(level);
    setState(() {}); // Refresh UI
  }

  Future<void> _syncAllDevices() async {
    _showSnackBar(
      _languageService.isEnglish
          ? 'Syncing all devices...'
          : 'Tüm cihazlar senkronize ediliyor...',
      Colors.blue,
    );
    
    try {
      await _deviceService.syncAllDevices();
    } catch (e) {
      _showSnackBar(
        _languageService.isEnglish
            ? 'Sync failed: $e'
            : 'Senkron başarısız: $e',
        Colors.red,
      );
    }
  }

  Future<void> _checkDeviceHealth() async {
    await _loadDevices(); // This also checks device health
    _showSnackBar(
      _languageService.isEnglish
          ? 'Device health check completed'
          : 'Cihaz sağlık kontrolü tamamlandı',
      Colors.green,
    );
  }
}

// Additional dialog widgets would be implemented here
class DeviceDetailsDialog extends StatelessWidget {
  final DeviceIntegration device;
  final DeviceHealthInfo? health;

  const DeviceDetailsDialog({
    super.key,
    required this.device,
    this.health,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation for device details dialog
    return AlertDialog(
      title: Text(device.deviceName),
      content: Text('Device details would be shown here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class DeviceConfigDialog extends StatelessWidget {
  final DeviceIntegration device;
  final VoidCallback onConfigUpdated;

  const DeviceConfigDialog({
    super.key,
    required this.device,
    required this.onConfigUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation for device configuration dialog
    return AlertDialog(
      title: Text('Configure ${device.deviceName}'),
      content: const Text('Device configuration would be shown here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfigUpdated();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AddDeviceDialog extends StatelessWidget {
  final DeviceType deviceType;
  final VoidCallback onDeviceAdded;

  const AddDeviceDialog({
    super.key,
    required this.deviceType,
    required this.onDeviceAdded,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation for add device dialog
    return AlertDialog(
      title: Text('Add ${deviceType.toString()}'),
      content: const Text('Device addition form would be shown here'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDeviceAdded();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}