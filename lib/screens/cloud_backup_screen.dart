import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
// removed LanguageService import – using AppLocalizations exclusively
import '../l10n/app_localizations.dart';
import '../widgets/liquid_pull_refresh.dart';
import 'auth_screen.dart';
import 'dart:async';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<bool>? _syncSubscription;

  bool _isLoading = false;
  bool _isSyncing = false;
  Map<String, dynamic> _backupStatus = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupListeners();
    _loadData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  void _setupListeners() {
    _authSubscription = _firebaseService.authStateChanges.listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user != null) {
          _loadBackupStatus();
        }
      }
    });

    _syncSubscription = _firebaseService.syncStatusStream.listen((bool syncing) {
      if (mounted) {
        setState(() {
          _isSyncing = syncing;
        });
        if (!syncing) {
          _loadBackupStatus();
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _authSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _currentUser = _firebaseService.currentUser;
      await _loadBackupStatus();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBackupStatus() async {
    if (!_firebaseService.isUserSignedIn) {
      setState(() {
        _backupStatus = {'hasBackup': false};
      });
      return;
    }

    try {
      final status = await _firebaseService.getBackupStatus();
      if (mounted) {
        setState(() {
          _backupStatus = status;
        });
      }
    } catch (e) {
      debugPrint('Error loading backup status: $e');
    }
  }

  Future<void> _signIn() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => const AuthScreen(isSignUp: false),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _signUp() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => const AuthScreen(isSignUp: true),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _syncToCloud() async {
    try {
      await _firebaseService.syncDataToCloud();
      _showSuccessSnackBar(
        AppLocalizations.of(context)!.translate('cloud.syncSuccess'),
      );
    } catch (e) {
      _showErrorSnackBar(
        '${AppLocalizations.of(context)!.translate('cloud.syncFailed')}: $e',
      );
    }
  }

  Future<void> _restoreFromCloud() async {
    final confirmed = await _showConfirmDialog(
      title: AppLocalizations.of(context)!.translate('cloud.restoreTitle'),
      content: AppLocalizations.of(context)!.translate('cloud.restoreConfirm'),
    );

    if (confirmed != true) return;

    try {
      await _firebaseService.syncDataFromCloud();
      _showSuccessSnackBar(
        AppLocalizations.of(context)!.translate('cloud.restoreSuccess'),
      );
    } catch (e) {
      _showErrorSnackBar(
        '${AppLocalizations.of(context)!.translate('cloud.restoreFailed')}: $e',
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _showConfirmDialog(
      title: AppLocalizations.of(context)!.translate('cloud.signOutTitle'),
      content: AppLocalizations.of(context)!.translate('cloud.signOutConfirm'),
    );

    if (confirmed == true) {
      await _firebaseService.signOut();
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.translate('common.confirm')),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    final l = AppLocalizations.of(context)!;
    if (timestamp == null) return l.translate('common.never');
    
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        // Firestore Timestamp
        date = timestamp.toDate();
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} ${l.translate('common.daysAgo')}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${l.translate('common.hoursAgo')}';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${l.translate('common.minutesAgo')}';
      } else {
        return l.translate('common.justNow');
      }
    } catch (e) {
      return l.translate('common.unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate('cloud.title')),
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue,
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: AppLocalizations.of(context)!.translate('cloud.signOut'),
            ),
        ],
      ),
      body: LiquidPullRefresh(
        onRefresh: _loadData,
        color: Colors.blue,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_currentUser == null)
                  _buildSignInPrompt()
                else ...[
                  _buildUserInfo(),
                  const SizedBox(height: 24),
                  _buildBackupStatus(),
                  const SizedBox(height: 24),
                  _buildSyncControls(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 24),
              
              Text(
                AppLocalizations.of(context)!.translate('cloud.signInTitle'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                AppLocalizations.of(context)!.translate('cloud.signInSubtitle'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _signIn,
                      icon: const Icon(Icons.login),
                      label: Text(AppLocalizations.of(context)!.translate('auth.signIn')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _signUp,
                      icon: const Icon(Icons.person_add),
                      label: Text(AppLocalizations.of(context)!.translate('auth.signUp')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildFeatureList(),
      ],
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {
        'icon': Icons.cloud_upload,
'title': AppLocalizations.of(context)!.translate('cloud.features.autoBackupTitle'),
'subtitle': AppLocalizations.of(context)!.translate('cloud.features.autoBackupSubtitle'),
      },
      {
        'icon': Icons.devices,
'title': AppLocalizations.of(context)!.translate('cloud.features.multiDeviceTitle'),
'subtitle': AppLocalizations.of(context)!.translate('cloud.features.multiDeviceSubtitle'),
      },
      {
        'icon': Icons.security,
'title': AppLocalizations.of(context)!.translate('cloud.features.encryptedTitle'),
'subtitle': AppLocalizations.of(context)!.translate('cloud.features.encryptedSubtitle'),
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('cloud.featuresTitle'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          feature['subtitle'] as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _getUserInitial() {
    final dn = _currentUser?.displayName?.trim();
    final email = _currentUser?.email?.trim();
    final source = (dn != null && dn.isNotEmpty)
        ? dn
        : (email != null && email.isNotEmpty ? email : 'U');
    return source.isNotEmpty ? source.substring(0, 1).toUpperCase() : 'U';
  }

  String _getDisplayName() {
    final dn = _currentUser?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    return AppLocalizations.of(context)!.translate('profile.user');
  }

  Widget _buildUserInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Text(
                    _getUserInitial(),
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
                        _getDisplayName(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentUser!.email ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.translate('cloud.signedInBadge'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupStatus() {
    final hasBackup = _backupStatus['hasBackup'] == true;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasBackup ? Icons.cloud_done : Icons.cloud_off,
                  color: hasBackup ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('cloud.statusTitle'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        hasBackup 
                          ? AppLocalizations.of(context)!.translate('cloud.hasBackup')
                          : AppLocalizations.of(context)!.translate('cloud.noBackup'),
                        style: TextStyle(
                          color: hasBackup ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSyncing)
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
              ],
            ),
            
            if (hasBackup) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.list_alt,
                      title: AppLocalizations.of(context)!.translate('ui.totalActivities'),
                      value: (_backupStatus['totalActivities'] ?? 0).toString(),
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.cloud,
                      title: AppLocalizations.of(context)!.translate('ui.totalCO2'),
                      value: '${(_backupStatus['totalCO2'] ?? 0.0).toStringAsFixed(1)} kg',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.of(context)!.translate('cloud.lastSync')} ${_formatDateTime(_backupStatus['lastSyncAt'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
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
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSyncControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('cloud.syncControls'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncToCloud,
                    icon: _isSyncing 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                    label: Text(
                      _isSyncing
                        ? AppLocalizations.of(context)!.translate('cloud.syncing')
                        : AppLocalizations.of(context)!.translate('cloud.backupToCloud'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _restoreFromCloud,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(AppLocalizations.of(context)!.translate('cloud.restoreFromCloud')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}