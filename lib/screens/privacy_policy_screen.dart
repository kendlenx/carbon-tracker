import 'package:flutter/material.dart';
import '../data/privacy_policy_content.dart';
import '../services/gdpr_service.dart';
import '../l10n/app_localizations.dart';
import './permissions_screen.dart';
import '../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();
  final GDPRService _gdprService = GDPRService();
  String? _selectedSection;

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final policyLanguage = code == 'tr' ? 'tr' : 'en';
    final policyContent = PrivacyPolicyContent.getPrivacyPolicy(policyLanguage);
    final sectionTitles = PrivacyPolicyContent.getSectionTitles(policyLanguage);
        
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
              IconButton(
                onPressed: () => _showTableOfContents(context, sectionTitles),
                icon: const Icon(Icons.list),
                tooltip: AppLocalizations.of(context)!.translate('ui.tableOfContents'),
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
                      AppLocalizations.of(context)!.translate('permissions.about.title'),
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
                            AppLocalizations.of(context)!.translate('settings.export.title'),
                            Icons.download,
                            () => _handleDataExport(),
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            AppLocalizations.of(context)!.translate('profile.deleteAccount'),
                            Icons.delete_forever,
                            () => _handleAccountDeletion(),
                            isDestructive: true,
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            AppLocalizations.of(context)!.translate('consent.manage'),
                            Icons.security,
                            () => _handleConsentManagement(),
                          ),
                          const SizedBox(width: 8),
                          _buildDataRightChip(
                            AppLocalizations.of(context)!.translate('ui.support'),
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
                      }),
                      
                      const SizedBox(height: 32),
                      
                      // Footer with contact and actions
                      _buildFooter(),
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

  Widget _buildFooter() {
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
            AppLocalizations.of(context)!.translate('consent.bannerTitle'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('consent.bannerBody'),
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
                AppLocalizations.of(context)!.translate('ui.support'),
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
              AppLocalizations.of(context)!.translate('ui.tableOfContents'),
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
    final l = AppLocalizations.of(context)!;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
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
              l.translate('settings.export.success'),
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
              '${l.translate('settings.export.failed')}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAccountDeletion() async {
    final l = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.translate('profile.deleteAccount')),
        content: Text(l.translate('profile.deleteConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.translate('common.delete')),
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
                const SizedBox.shrink(),
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
                l.translate('profile.deleteSuccess'),
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
                '${l.translate('common.error')}: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleConsentManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PermissionsScreen()),
    );
  }

  void _handleContactSupport() {
    final l = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l.translate('ui.support'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.translate('consent.title')),
            const SizedBox(height: 8),
            const SelectableText('privacy@carbontracker.app'),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Text('Data Protection Officer:'),
            const SizedBox(height: 8),
            const SelectableText('dpo@carbontracker.app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.translate('common.ok')),
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