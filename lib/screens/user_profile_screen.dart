import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // TODO: Enable after Firebase setup
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../services/language_service.dart';
import '../services/security_service.dart';
import '../widgets/liquid_pull_refresh.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final LanguageService _languageService = LanguageService.instance;
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
      _showErrorSnackBar('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar(_languageService.isEnglish ? 'Name cannot be empty' : 'İsim boş olamaz');
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
        _languageService.isEnglish 
          ? 'Profile updated successfully!' 
          : 'Profil başarıyla güncellendi!'
      );
    } catch (e) {
      _showErrorSnackBar(
        _languageService.isEnglish 
          ? 'Failed to update profile: $e' 
          : 'Profil güncellenemedi: $e'
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      _showErrorSnackBar(
        _languageService.isEnglish 
          ? 'Please fill all password fields' 
          : 'Lütfen tüm şifre alanlarını doldurun'
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar(
        _languageService.isEnglish 
          ? 'New password must be at least 6 characters' 
          : 'Yeni şifre en az 6 karakter olmalı'
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
        _languageService.isEnglish 
          ? 'Password changed successfully!' 
          : 'Şifre başarıyla değiştirildi!'
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('wrong-password')) {
        errorMessage = _languageService.isEnglish 
          ? 'Current password is incorrect' 
          : 'Mevcut şifre yanlış';
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
          _languageService.isEnglish 
            ? 'Profile picture updated!' 
            : 'Profil resmi güncellendi!'
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        _languageService.isEnglish 
          ? 'Failed to update profile picture' 
          : 'Profil resmi güncellenemedi'
      );
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await _currentUser!.sendEmailVerification();
      _showSuccessSnackBar(
        _languageService.isEnglish 
          ? 'Verification email sent!' 
          : 'Doğrulama e-postası gönderildi!'
      );
    } catch (e) {
      _showErrorSnackBar(
        _languageService.isEnglish 
          ? 'Failed to send verification email' 
          : 'Doğrulama e-postası gönderilemedi'
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
          _languageService.isEnglish 
            ? 'Account deleted successfully' 
            : 'Hesap başarıyla silindi'
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('wrong-password')) {
        errorMessage = _languageService.isEnglish 
          ? 'Password is incorrect' 
          : 'Şifre yanlış';
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
            Text(_languageService.isEnglish ? 'Delete Account' : 'Hesabı Sil'),
          ],
        ),
        content: Text(
          _languageService.isEnglish 
            ? 'This will permanently delete your account and all data. This action cannot be undone. Are you sure?'
            : 'Bu işlem hesabınızı ve tüm verilerinizi kalıcı olarak silecektir. Bu işlem geri alınamaz. Emin misiniz?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _languageService.isEnglish ? 'Delete Account' : 'Hesabı Sil',
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
        title: Text(_languageService.isEnglish ? 'Confirm Password' : 'Şifreyi Onayla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _languageService.isEnglish 
                ? 'Please enter your password to confirm account deletion:'
                : 'Hesap silme işlemini onaylamak için şifrenizi girin:'
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _languageService.isEnglish ? 'Password' : 'Şifre',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: Text(
              _languageService.isEnglish ? 'Confirm' : 'Onayla',
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
    if (dateTime == null) return _languageService.isEnglish ? 'Unknown' : 'Bilinmiyor';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return _languageService.isEnglish 
        ? '${difference.inDays} days ago'
        : '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return _languageService.isEnglish
        ? '${difference.inHours} hours ago'
        : '${difference.inHours} saat önce';
    } else {
      return _languageService.isEnglish ? 'Just now' : 'Şimdi';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_languageService.isEnglish ? 'Profile' : 'Profil'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _languageService.isEnglish ? 'Please sign in to view profile' : 'Profili görüntülemek için giriş yapın',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Profile' : 'Profil'),
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        foregroundColor: Colors.blue,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: _languageService.isEnglish ? 'Edit Profile' : 'Profili Düzenle',
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
                    backgroundImage: _profileImagePath != null
                      ? FileImage(File(_profileImagePath!))
                      : null,
                    child: _profileImagePath == null
                      ? Text(
                          (_userProfile['displayName'] as String? ?? 'U')[0].toUpperCase(),
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
              _userProfile['displayName'] ?? 'User',
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
                  _languageService.isEnglish 
                    ? 'Verify Email' 
                    : 'E-postayı Doğrula',
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
              _languageService.isEnglish ? 'Profile Information' : 'Profil Bilgileri',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: _languageService.isEnglish ? 'Full Name' : 'Ad Soyad',
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _emailController,
              enabled: false, // Email cannot be changed
              decoration: InputDecoration(
                labelText: _languageService.isEnglish ? 'Email Address' : 'E-posta Adresi',
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
                helperText: _languageService.isEnglish 
                  ? 'Email cannot be changed' 
                  : 'E-posta değiştirilemez',
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
                          _nameController.text = _userProfile['displayName'] ?? '';
                        });
                      },
                      child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      child: Text(_languageService.isEnglish ? 'Save Changes' : 'Değişiklikleri Kaydet'),
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
              _languageService.isEnglish ? 'Security' : 'Güvenlik',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_isChangingPassword) ...[
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(_languageService.isEnglish ? 'Change Password' : 'Şifre Değiştir'),
                subtitle: Text(_languageService.isEnglish ? 'Update your account password' : 'Hesap şifrenizi güncelleyin'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _isChangingPassword = true),
              ),
            ] else ...[
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _languageService.isEnglish ? 'Current Password' : 'Mevcut Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _languageService.isEnglish ? 'New Password' : 'Yeni Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  helperText: _languageService.isEnglish 
                    ? 'At least 6 characters' 
                    : 'En az 6 karakter',
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
                      child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      child: Text(_languageService.isEnglish ? 'Change Password' : 'Şifre Değiştir'),
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
              _languageService.isEnglish ? 'Account Statistics' : 'Hesap İstatistikleri',
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
                    title: _languageService.isEnglish ? 'Total Activities' : 'Toplam Aktivite',
                    value: (_userStats['totalActivities'] ?? 0).toString(),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.cloud,
                    title: _languageService.isEnglish ? 'CO₂ Tracked' : 'Takip Edilen CO₂',
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
              _languageService.isEnglish ? 'Member Since' : 'Üye Olma Tarihi',
              _formatDateTime(_userProfile['createdAt']),
              Icons.calendar_today,
            ),
            
            const SizedBox(height: 8),
            
            _buildInfoRow(
              _languageService.isEnglish ? 'Last Sign In' : 'Son Giriş',
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
                  _languageService.isEnglish ? 'Danger Zone' : 'Tehlikeli Alan',
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
                _languageService.isEnglish ? 'Delete Account' : 'Hesabı Sil',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _languageService.isEnglish 
                  ? 'Permanently delete your account and all data'
                  : 'Hesabınızı ve tüm verilerinizi kalıcı olarak silin',
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