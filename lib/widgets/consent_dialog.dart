import 'package:flutter/material.dart';
import '../services/gdpr_service.dart';
import '../utils/app_colors.dart';
import '../l10n/app_localizations.dart';

class ConsentDialog extends StatefulWidget {
  final bool isFirstTime;
  
  const ConsentDialog({
    super.key,
    this.isFirstTime = false,
  });

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  final GDPRService _gdprService = GDPRService();
  Map<String, bool> _consents = {};
  bool _isLoading = true;
  bool _acceptAll = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConsents();
  }

  Future<void> _loadCurrentConsents() async {
    try {
      final consents = await _gdprService.getAllConsents();
      setState(() {
        _consents = consents;
        _acceptAll = consents.values.every((consent) => consent);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    
    return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.privacy_tip,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.translate('consent.title'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: _isLoading 
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Introduction text
                    Text(
                      l.translate('consent.intro'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Accept all toggle
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.translate('consent.acceptAll'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Switch(
                            value: _acceptAll,
                            onChanged: (value) {
                              setState(() {
                                _acceptAll = value;
                                for (final key in _consents.keys) {
                                  _consents[key] = value;
                                }
                              });
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Individual consent options
                    ..._buildConsentOptions(l),
                    
                    const SizedBox(height: 16),
                    
                    // Legal notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.translate('consent.legalNote'),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          actions: [
            // Learn more button
            TextButton.icon(
              onPressed: () => _showDetailedInfo(context, l),
              icon: const Icon(Icons.info_outline, size: 16),
              label: Text(
                l.translate('consent.learnMore'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            
            // Action buttons
            if (!widget.isFirstTime) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l.translate('common.cancel'),
                ),
              ),
            ],
            
            ElevatedButton(
              onPressed: _saveConsents,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                AppLocalizations.of(context)!.translate('common.save'),
              ),
            ),
          ],
        );
  }

  List<Widget> _buildConsentOptions(AppLocalizations l) {
    final consentOptions = _getConsentOptions(l);
    
    return consentOptions.map((option) {
      final key = option['key'] as String;
      final isGranted = _consents[key] ?? false;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isGranted 
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  option['icon'] as IconData,
                  size: 20,
                  color: isGranted ? AppColors.primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: isGranted,
                  onChanged: (value) {
                    setState(() {
                      _consents[key] = value;
                      _updateAcceptAll();
                    });
                  },
                  activeThumbColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              option['description'] as String,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getConsentOptions(AppLocalizations l) {
    return [
      {
        'key': GDPRService.consentAnalytics,
        'icon': Icons.analytics,
'title': l.translate('consent.options.analytics.title'),
'description': l.translate('consent.options.analytics.description'),
      },
      {
        'key': GDPRService.consentCrashReporting,
        'icon': Icons.bug_report,
'title': l.translate('consent.options.crash.title'),
'description': l.translate('consent.options.crash.description'),
      },
      {
        'key': GDPRService.consentDataSync,
        'icon': Icons.sync,
'title': l.translate('consent.options.dataSync.title'),
'description': l.translate('consent.options.dataSync.description'),
      },
      {
        'key': GDPRService.consentLocationTracking,
        'icon': Icons.location_on,
'title': l.translate('consent.options.location.title'),
'description': l.translate('consent.options.location.description'),
      },
      {
        'key': GDPRService.consentMarketing,
        'icon': Icons.campaign,
'title': l.translate('consent.options.marketing.title'),
'description': l.translate('consent.options.marketing.description'),
      },
    ];
  }

  void _updateAcceptAll() {
    _acceptAll = _consents.values.every((consent) => consent);
  }

  void _showDetailedInfo(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l.translate('consent.detailsTitle'),
        ),
        content: SingleChildScrollView(
          child: Text(
            l.translate('consent.detailsBody'),
            style: const TextStyle(fontSize: 14),
          ),
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

  Future<void> _saveConsents() async {
    try {
      // Save each consent
      for (final entry in _consents.entries) {
        await _gdprService.setConsent(entry.key, entry.value);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate('consent.saveSuccess'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.translate('consent.saveFailed')}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Simplified consent banner for first-time users
class ConsentBanner extends StatelessWidget {
  const ConsentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    
    return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.translate('consent.bannerTitle'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.translate('consent.bannerBody'),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showConsentDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        l.translate('consent.manage'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ConsentDialog(),
    );
  }
}