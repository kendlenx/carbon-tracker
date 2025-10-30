import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';
import '../l10n/app_localizations.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('permissions.title')),
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
                    title: l10n.translate('permissions.sections.essentialTitle'),
                    subtitle: l10n.translate('permissions.sections.essentialSubtitle'),
                    permissions: [
                      PermissionItem(
                        key: 'storage',
                        titleKey: 'permissions.storage',
                        descriptionKey: 'permissions.descriptions.storage',
                        icon: Icons.storage,
                        color: Colors.blue,
                        isRequired: true,
                      ),
                      PermissionItem(
                        key: 'notifications',
                        titleKey: 'permissions.notifications',
                        descriptionKey: 'permissions.descriptions.notifications',
                        icon: Icons.notifications,
                        color: Colors.green,
                        isRequired: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Enhanced Features
                  _buildPermissionSection(
                    title: l10n.translate('permissions.sections.enhancedTitle'),
                    subtitle: l10n.translate('permissions.sections.enhancedSubtitle'),
                    permissions: [
                      PermissionItem(
                        key: 'location',
                        titleKey: 'permissions.location',
                        descriptionKey: 'permissions.descriptions.location',
                        icon: Icons.location_on,
                        color: Colors.red,
                        isRequired: false,
                      ),
                      PermissionItem(
                        key: 'camera',
                        titleKey: 'permissions.camera',
                        descriptionKey: 'permissions.descriptions.camera',
                        icon: Icons.camera_alt,
                        color: Colors.purple,
                        isRequired: false,
                      ),
                      PermissionItem(
                        key: 'microphone',
                        titleKey: 'permissions.microphone',
                        descriptionKey: 'permissions.descriptions.microphone',
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.security, color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            Text(
              l10n.translate('permissions.infoTitle'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('permissions.infoBody'),
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
                      Expanded(
                        child: Text(
                          permission.getTitle(AppLocalizations.of(context)!),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            AppLocalizations.of(context)!.translate('permissions.required'),
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
                    permission.getDescription(AppLocalizations.of(context)!),
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
                          ? AppLocalizations.of(context)!.translate('permissions.granted')
                          : AppLocalizations.of(context)!.translate('permissions.denied'),
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.translate('ui.securityPrivacy'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildPrivacyItem(
              icon: Icons.local_shipping,
              titleKey: 'permissions.dataStaysOnDevice',
              descriptionKey: 'permissions.dataStaysOnDeviceDesc',
            ),
            
            const SizedBox(height: 16),
            
            _buildPrivacyItem(
              icon: Icons.no_accounts,
              titleKey: 'permissions.noTrackingProfiling',
              descriptionKey: 'permissions.noTrackingProfilingDesc',
            ),
            
            const SizedBox(height: 16),
            
            _buildPrivacyItem(
              icon: Icons.verified_user,
              titleKey: 'permissions.transparentPermissions',
              descriptionKey: 'permissions.transparentPermissionsDesc',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String titleKey,
    required String descriptionKey,
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
                AppLocalizations.of(context)!.translate(titleKey),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.translate(descriptionKey),
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
          AppLocalizations.of(context)!.translate('permissions.openSettings'),
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
            AppLocalizations.of(context)!.translate('permissions.granted'),
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
        title: Text(AppLocalizations.of(context)!.translate('permissions.about.title')),
        content: Text(
          AppLocalizations.of(context)!.translate('permissions.about.body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.ok')),
          ),
        ],
      ),
    );
  }
}

class _PermissionDetailSheet extends StatelessWidget {
  final PermissionItem permission;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionDetailSheet({
    required this.permission,
    required this.isGranted,
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
            permission.getTitle(AppLocalizations.of(context)!),
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
                ? AppLocalizations.of(context)!.translate('permissions.granted')
                : AppLocalizations.of(context)!.translate('permissions.denied'),
              style: TextStyle(
                color: isGranted ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            permission.getDescription(AppLocalizations.of(context)!),
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
                  AppLocalizations.of(context)!.translate('permissions.requestPermission'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Text(
              AppLocalizations.of(context)!.translate('permissions.manageInSystemSettings'),
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
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final Color color;
  final bool isRequired;

  PermissionItem({
    required this.key,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    required this.isRequired,
  });

  String getTitle(AppLocalizations l10n) => l10n.translate(titleKey);
  String getDescription(AppLocalizations l10n) => l10n.translate(descriptionKey);
}
