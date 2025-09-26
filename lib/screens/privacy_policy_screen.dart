import 'package:flutter/material.dart';
import '../data/privacy_policy_content.dart';
import '../services/gdpr_service.dart';
import '../services/language_service.dart';
import '../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();
  final GDPRService _gdprService = GDPRService();
  final LanguageService _languageService = LanguageService.instance;
  String? _selectedSection;

  @override
  Widget build(BuildContext context) {
    final language = _languageService.isEnglish ? 'en' : 'tr';
    final policyContent = PrivacyPolicyContent.getPrivacyPolicy(language);
    final sectionTitles = PrivacyPolicyContent.getSectionTitles(language);
        
    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              policyContent['title']!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Language toggle
              IconButton(
                onPressed: () => _showLanguageDialog(),
                icon: const Icon(Icons.language),
                tooltip: language == 'tr' ? 'Dil Değiştir' : 'Change Language',
              ),
              // Table of contents
              IconButton(
                onPressed: () => _showTableOfContents(context, sectionTitles),
                icon: const Icon(Icons.list),
                tooltip: language == 'tr' ? 'İçindekiler' : 'Table of Contents',
              ),
            ],
          ),
          body: Column(
            children: [
              // Data rights quick actions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language == 'tr' 
                        ? 'GDPR Haklarınız' 
                        : 'Your GDPR Rights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDataRightChip(
                            language == 'tr' ? 'Veri İndir' : 'Export Data',
                            Icons.download,
                            () => _handleDataExport(),
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            language == 'tr' ? 'Hesabı Sil' : 'Delete Account',
                            Icons.delete_forever,
                            () => _handleAccountDeletion(),
                            isDestructive: true,
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            language == 'tr' ? 'İzin Yönetimi' : 'Manage Consent',
                            Icons.security,
                            () => _handleConsentManagement(),
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            language == 'tr' ? 'Destek' : 'Support',
                            Icons.support_agent,
                            () => _handleContactSupport(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Privacy policy content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Last updated
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          policyContent['lastUpdated']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Policy sections
                      ...PrivacyPolicyContent.getSectionKeys().map((sectionKey) {
                        return _buildPolicySection(
                          sectionTitles[sectionKey]!,
                          policyContent[sectionKey]!,
                          sectionKey,
                        );
                      }).toList(),
                      
                      const SizedBox(height: 32),
                      
                      // Footer with contact and actions
                      _buildFooter(language),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }


  Widget _buildDataRightChip(
    String label, 
    IconData icon, 
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDestructive 
            ? Colors.red.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive 
              ? Colors.red.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive ? Colors.red : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDestructive ? Colors.red : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content, String sectionKey) {
    final isSelected = _selectedSection == sectionKey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
            ? AppColors.primary 
            : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          
          // Section content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(String language) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.privacy_tip,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            language == 'tr'
              ? 'Gizliliğiniz bizim için önemlidir'
              : 'Your privacy matters to us',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            language == 'tr'
              ? 'Sorularınız için destek ekibimizle iletişime geçin'
              : 'Contact our support team for any questions',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleContactSupport,
              icon: const Icon(Icons.email),
              label: Text(
                language == 'tr' 
                  ? 'Bizimle İletişime Geçin' 
                  : 'Contact Us',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageService.isEnglish 
            ? 'Select Language' 
            : 'Dil Seçin',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: _languageService.isEnglish 
                ? const Icon(Icons.check, color: Colors.green) 
                : null,
              onTap: () {
                _languageService.setLanguage('en');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Text('🇹🇷', style: TextStyle(fontSize: 24)),
              title: const Text('Türkçe'),
              trailing: !_languageService.isEnglish 
                ? const Icon(Icons.check, color: Colors.green) 
                : null,
              onTap: () {
                _languageService.setLanguage('tr');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTableOfContents(BuildContext context, Map<String, String> sectionTitles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish
                ? 'Table of Contents'
                : 'İçindekiler',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: PrivacyPolicyContent.getSectionKeys().map((sectionKey) {
                    return ListTile(
                      title: Text(sectionTitles[sectionKey]!),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        setState(() {
                          _selectedSection = sectionKey;
                        });
                        Navigator.of(context).pop();
                        // Scroll to section (simplified - could be improved with proper anchoring)
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDataExport() async {
    final language = _languageService.isEnglish ? 'en' : 'tr';
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  language == 'tr'
                    ? 'Verileriniz hazırlanıyor...'
                    : 'Preparing your data...',
                ),
              ),
            ],
          ),
        ),
      );

      await _gdprService.exportUserData();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'tr'
                ? 'Verileriniz başarıyla dışa aktarıldı'
                : 'Your data has been successfully exported',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'tr'
                ? 'Veri dışa aktarma başarısız: ${e.toString()}'
                : 'Data export failed: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAccountDeletion() async {
    final language = _languageService.isEnglish ? 'en' : 'tr';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language == 'tr' 
            ? 'Hesabı Sil' 
            : 'Delete Account',
        ),
        content: Text(
          language == 'tr'
            ? 'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecektir. Devam etmek istediğinizden emin misiniz?'
            : 'This action cannot be undone. All your data will be permanently deleted. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              language == 'tr' ? 'İptal' : 'Cancel',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              language == 'tr' ? 'Sil' : 'Delete',
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    language == 'tr'
                      ? 'Hesabınız siliniyor...'
                      : 'Deleting your account...',
                  ),
                ),
              ],
            ),
          ),
        );

        await _gdprService.deleteUserAccount();
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.of(context).pop(); // Close privacy policy screen
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                language == 'tr'
                  ? 'Hesabınız başarıyla silindi'
                  : 'Your account has been successfully deleted',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                language == 'tr'
                  ? 'Hesap silme başarısız: ${e.toString()}'
                  : 'Account deletion failed: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleConsentManagement() {
    // This will be implemented in the consent management system
    final language = _languageService.isEnglish ? 'en' : 'tr';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language == 'tr' 
            ? 'İzin Yönetimi' 
            : 'Consent Management',
        ),
        content: Text(
          language == 'tr'
            ? 'İzin yönetimi özelliği yakında eklenecek.'
            : 'Consent management feature will be added soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleContactSupport() {
    final language = _languageService.isEnglish ? 'en' : 'tr';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language == 'tr' 
            ? 'Destek İletişimi' 
            : 'Contact Support',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language == 'tr'
                ? 'Gizlilik ile ilgili sorularınız için:'
                : 'For privacy-related questions:',
            ),
            const SizedBox(height: 8),
            const SelectableText('privacy@carbontracker.app'),
            const SizedBox(height: 12),
            Text(
              language == 'tr'
                ? 'Veri koruma sorumlusu:'
                : 'Data Protection Officer:',
            ),
            const SizedBox(height: 8),
            const SelectableText('dpo@carbontracker.app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}