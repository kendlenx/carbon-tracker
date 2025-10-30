import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // TODO: Enable after Firebase setup
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/security_service.dart';
import '../widgets/liquid_pull_refresh.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  // final LanguageService _languageService = LanguageService.instance;
  final SecurityService _securityService = SecurityService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // User? _currentUser; // TODO: Enable after Firebase setup
  dynamic _currentUser;
  Map<String, dynamic> _userProfile = {};
  Map<String, dynamic> _userStats = {};
  String? _profileImagePath;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserData();
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

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      _currentUser = _firebaseService.currentUser;
      if (_currentUser != null) {
        _nameController.text = _currentUser!.displayName ?? '';
        _emailController.text = _currentUser!.email ?? '';
        
        // Load user profile data from Firestore
        final backupStatus = await _firebaseService.getBackupStatus();
        setState(() {
          _userProfile = {
            'displayName': _currentUser!.displayName ?? 'Carbon Step User',
            'email': _currentUser!.email ?? '',
            'photoURL': _currentUser!.photoURL,
            'emailVerified': _currentUser!.emailVerified,
            'createdAt': _currentUser!.metadata.creationTime,
            'lastSignInAt': _currentUser!.metadata.lastSignInTime,
          };
          _userStats = backupStatus;
        });

        // Load profile image from secure storage if exists
        final savedImagePath = await _securityService.readSecureData('profile_image_path');
        if (savedImagePath != null) {
          setState(() {
            _profileImagePath = savedImagePath;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('${AppLocalizations.of(context)!.translate('common.error')}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar(AppLocalizations.of(context)!.translate('profile.nameEmpty'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update display name in Firebase Auth
      await _currentUser!.updateDisplayName(_nameController.text.trim());
      
      // Reload user to get updated data
      await _currentUser!.reload();
      
      await _loadUserData();
      
      setState(() {
        _isEditing = false;
      });

      _showSuccessSnackBar(
        AppLocalizations.of(context)!.translate('profile.profileUpdated')
      );
    } catch (e) {
      _showErrorSnackBar(
        '${AppLocalizations.of(context)!.translate('profile.profileUpdateFailed')}: $e'
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      _showErrorSnackBar(AppLocalizations.of(context)!.translate('profile.fillAllPasswordFields'));
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar(
        AppLocalizations.of(context)!.translate('profile.passwordMinLen')
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Re-authenticate user
      // TODO: Enable after Firebase setup
      // final credential = EmailAuthProvider.credential(
      //   email: _currentUser!.email!,
      //   password: _currentPasswordController.text,
      // );
      
      // TODO: Enable after Firebase setup
      // await _currentUser!.reauthenticateWithCredential(credential);
      // 
      // // Update password
      // await _currentUser!.updatePassword(_newPasswordController.text);
      
      _currentPasswordController.clear();
      _newPasswordController.clear();
      
      setState(() {
        _isChangingPassword = false;
      });

      _showSuccessSnackBar(
        AppLocalizations.of(context)!.translate('profile.passwordChanged')
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('wrong-password')) {
        errorMessage = AppLocalizations.of(context)!.translate('profile.currentPasswordIncorrect');
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        // Save image path securely
        await _securityService.storeSecureData('profile_image_path', image.path);
        
        setState(() {
          _profileImagePath = image.path;
        });

        _showSuccessSnackBar(
          AppLocalizations.of(context)!.translate('profile.pictureUpdated')
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        AppLocalizations.of(context)!.translate('profile.pictureUpdateFailed')
      );
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await _currentUser!.sendEmailVerification();
      _showSuccessSnackBar(
        AppLocalizations.of(context)!.translate('profile.verificationEmailSent')
      );
    } catch (e) {
      _showErrorSnackBar(
        AppLocalizations.of(context)!.translate('profile.verificationEmailFailed')
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showDeleteConfirmDialog();
    if (confirmed != true) return;

    // Ask for password confirmation
    final password = await _showPasswordConfirmDialog();
    if (password == null || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Re-authenticate user
      // TODO: Enable after Firebase setup
      // final credential = EmailAuthProvider.credential(
      //   email: _currentUser!.email!,
      //   password: password,
      // );
      // 
      // await _currentUser!.reauthenticateWithCredential(credential);
      
      // Delete account and all data from Firebase
      await _firebaseService.deleteAccount();
      
      // Clear local secure storage
      await _securityService.clearSecureStorage();
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSuccessSnackBar(
          AppLocalizations.of(context)!.translate('profile.deleteSuccess')
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('wrong-password')) {
        errorMessage = AppLocalizations.of(context)!.translate('profile.passwordIncorrect');
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.translate('profile.deleteAccount')),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.translate('profile.deleteConfirmMessage')
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppLocalizations.of(context)!.translate('profile.deleteAccount'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordConfirmDialog() {
    final passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('profile.confirmPasswordTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('profile.confirmPasswordBody')
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.translate('auth.password'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: Text(
              AppLocalizations.of(context)!.translate('common.confirm'),
              style: const TextStyle(color: Colors.white),
            ),
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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return AppLocalizations.of(context)!.translate('common.unknown');
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    // Use localized date formatting to avoid missing relative strings
    return MaterialLocalizations.of(context).formatMediumDate(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.translate('profile.title')),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.translate('profile.signInToView'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate('profile.title')),
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: AppLocalizations.of(context)!.translate('profile.editProfile'),
            ),
        ],
      ),
      body: LiquidPullRefresh(
        onRefresh: _loadUserData,
        color: Colors.blue,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildProfileForm(),
                    const SizedBox(height: 24),
                    _buildSecuritySection(),
                    const SizedBox(height: 24),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildDangerZone(),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  String _getDisplayName() {
    final name = (_userProfile['displayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return AppLocalizations.of(context)!.translate('profile.user');
  }

  String _getProfileInitial() {
    final name = (_userProfile['displayName'] as String?)?.trim();
    final fallback = AppLocalizations.of(context)!.translate('profile.userInitial');
    final source = (name != null && name.isNotEmpty) ? name : fallback;
    return source.isNotEmpty ? source.substring(0, 1).toUpperCase() : 'U';
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickProfileImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    backgroundImage: (() {
                      try {
                        if (_profileImagePath != null && File(_profileImagePath!).existsSync()) {
                          return FileImage(File(_profileImagePath!));
                        }
                      } catch (_) {}
                      return null;
                    })(),
                    child: ((_profileImagePath == null) || !( (){ try { return File(_profileImagePath!).existsSync(); } catch (_) { return false; } }() ))
                      ? Text(
                          _getProfileInitial(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getDisplayName(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _userProfile['emailVerified'] == true
                    ? Icons.verified
                    : Icons.warning,
                  color: _userProfile['emailVerified'] == true
                    ? Colors.green
                    : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _userProfile['email'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (_userProfile['emailVerified'] != true) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _sendEmailVerification,
                icon: const Icon(Icons.email, size: 16),
                label: Text(
                  AppLocalizations.of(context)!.translate('profile.verifyEmail'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('profile.infoTitle'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.translate('profile.fullName'),
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _emailController,
              enabled: false, // Email cannot be changed
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.translate('profile.emailAddress'),
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
                helperText: AppLocalizations.of(context)!.translate('profile.emailImmutable'),
              ),
            ),
            
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _nameController.text = _getDisplayName();
                        });
                      },
                      child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      child: Text(AppLocalizations.of(context)!.translate('common.save')),
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

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('profile.securityTitle'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_isChangingPassword) ...[
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(AppLocalizations.of(context)!.translate('profile.changePassword')),
                subtitle: Text(AppLocalizations.of(context)!.translate('profile.updatePasswordSubtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _isChangingPassword = true),
              ),
            ] else ...[
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate('profile.currentPassword'),
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.translate('profile.newPassword'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  helperText: AppLocalizations.of(context)!.translate('profile.passwordHint'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isChangingPassword = false;
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                        });
                      },
                      child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      child: Text(AppLocalizations.of(context)!.translate('profile.changePassword')),
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

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('profile.statsTitle'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.list_alt,
                    title: AppLocalizations.of(context)!.translate('ui.totalActivities'),
                    value: (_userStats['totalActivities'] ?? 0).toString(),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.cloud,
                    title: AppLocalizations.of(context)!.translate('ui.totalCO2'),
                    value: '${(_userStats['totalCO2'] ?? 0.0).toStringAsFixed(1)} kg',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              AppLocalizations.of(context)!.translate('profile.memberSince'),
              _formatDateTime(_userProfile['createdAt']),
              Icons.calendar_today,
            ),
            
            const SizedBox(height: 8),
            
            _buildInfoRow(
              AppLocalizations.of(context)!.translate('profile.lastSignIn'),
              _formatDateTime(_userProfile['lastSignInAt']),
              Icons.login,
            ),
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
            fontSize: 20,
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

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: Colors.red.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.translate('profile.dangerZone'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                AppLocalizations.of(context)!.translate('profile.deleteAccount'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.translate('profile.deleteAccountSubtitle'),
              ),
              onTap: _deleteAccount,
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}