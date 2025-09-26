import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/gdpr_service.dart';
import '../utils/app_colors.dart';

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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final language = languageProvider.currentLanguage;
        
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
                  language == 'tr' 
                    ? 'Gizlilik ve İzinler' 
                    : 'Privacy & Consent',
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
                      language == 'tr'
                        ? 'Verilerinizi nasıl kullandığımızı kontrol edin. Bu izinleri istediğiniz zaman değiştirebilirsiniz.'
                        : 'Control how we use your data. You can change these permissions at any time.',
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
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              language == 'tr' 
                                ? 'Tümünü Kabul Et' 
                                : 'Accept All',
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
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Individual consent options
                    ..._buildConsentOptions(language),
                    
                    const SizedBox(height: 16),
                    
                    // Legal notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        language == 'tr'
                          ? 'Temel uygulama işlevleri için gerekli olan veriler, izniniz olmadan da işlenir (yasal gereklilik).'
                          : 'Essential data for app functionality is processed without consent (legal requirement).',
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
              onPressed: () => _showDetailedInfo(context, language),
              icon: const Icon(Icons.info_outline, size: 16),
              label: Text(
                language == 'tr' ? 'Detaylar' : 'Learn More',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            
            // Action buttons
            if (!widget.isFirstTime) ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  language == 'tr' ? 'İptal' : 'Cancel',
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
                language == 'tr' ? 'Kaydet' : 'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildConsentOptions(String language) {
    final consentOptions = _getConsentOptions(language);
    
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
              ? AppColors.primary.withOpacity(0.3)
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
                  activeColor: AppColors.primary,
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

  List<Map<String, dynamic>> _getConsentOptions(String language) {
    if (language == 'tr') {
      return [
        {
          'key': GDPRService.consentAnalytics,
          'icon': Icons.analytics,
          'title': 'Analitik ve Performans',
          'description': 'Uygulama performansını ölçmek ve iyileştirmek için anonim kullanım verileri toplamamıza izin verin.',
        },
        {
          'key': GDPRService.consentCrashReporting,
          'icon': Icons.bug_report,
          'title': 'Hata Raporlama',
          'description': 'Uygulama hatalarını tespit etmek ve düzeltmek için otomatik hata raporları göndermeyi etkinleştirin.',
        },
        {
          'key': GDPRService.consentDataSync,
          'icon': Icons.sync,
          'title': 'Bulut Senkronizasyonu',
          'description': 'Verilerinizi cihazlar arası senkronize etmek için bulut depolamayı kullanın.',
        },
        {
          'key': GDPRService.consentLocationTracking,
          'icon': Icons.location_on,
          'title': 'Konum Takibi',
          'description': 'Daha doğru karbon ayak izi hesaplamaları için konum verilerinizi kullanın (isteğe bağlı).',
        },
        {
          'key': GDPRService.consentMarketing,
          'icon': Icons.campaign,
          'title': 'Pazarlama İletişimi',
          'description': 'Yeni özellikler ve ipuçları hakkında kişiselleştirilmiş bildirimler alın.',
        },
      ];
    }
    
    return [
      {
        'key': GDPRService.consentAnalytics,
        'icon': Icons.analytics,
        'title': 'Analytics & Performance',
        'description': 'Allow us to collect anonymous usage data to measure and improve app performance.',
      },
      {
        'key': GDPRService.consentCrashReporting,
        'icon': Icons.bug_report,
        'title': 'Crash Reporting',
        'description': 'Enable automatic crash reports to help us identify and fix app issues.',
      },
      {
        'key': GDPRService.consentDataSync,
        'icon': Icons.sync,
        'title': 'Cloud Synchronization',
        'description': 'Use cloud storage to synchronize your data across devices.',
      },
      {
        'key': GDPRService.consentLocationTracking,
        'icon': Icons.location_on,
        'title': 'Location Tracking',
        'description': 'Use your location data for more accurate carbon footprint calculations (optional).',
      },
      {
        'key': GDPRService.consentMarketing,
        'icon': Icons.campaign,
        'title': 'Marketing Communications',
        'description': 'Receive personalized notifications about new features and tips.',
      },
    ];
  }

  void _updateAcceptAll() {
    _acceptAll = _consents.values.every((consent) => consent);
  }

  void _showDetailedInfo(BuildContext context, String language) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          language == 'tr' 
            ? 'Veri Kullanımı Detayları' 
            : 'Data Usage Details',
        ),
        content: SingleChildScrollView(
          child: Text(
            language == 'tr'
              ? '''Gizliliğiniz bizim için önemlidir. İşte verilerinizi nasıl kullandığımız:

• Temel İşlevler: Uygulama çalıştırmak için gerekli veriler (karbon aktiviteleri, hesap bilgileri)

• Analitik: Anonim kullanım istatistikleri (hangi özellikler kullanılıyor, performans metrikleri)

• Hata Raporları: Uygulama çökmelerini tespit etmek için teknik veriler

• Bulut Sync: Firebase üzerinden şifrelenmiş veri yedekleme

• Konum: GPS verisi sadece aktivite kaydı sırasında kullanılır

• Pazarlama: Sadece uygulama içi bildirimler, hiçbir üçüncü tarafla paylaşılmaz

Tüm veriler GDPR uyumludur ve dilediğiniz zaman silebilirsiniz.'''
              : '''Your privacy is important to us. Here's how we use your data:

• Essential Functions: Data required to run the app (carbon activities, account info)

• Analytics: Anonymous usage statistics (which features are used, performance metrics)

• Crash Reports: Technical data to identify app crashes

• Cloud Sync: Encrypted data backup via Firebase

• Location: GPS data only used during activity recording

• Marketing: Only in-app notifications, never shared with third parties

All data is GDPR compliant and you can delete it anytime.''',
            style: const TextStyle(fontSize: 14),
          ),
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
              context.read<LanguageProvider>().currentLanguage == 'tr'
                ? 'İzin ayarlarınız kaydedildi'
                : 'Your consent preferences have been saved',
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
              context.read<LanguageProvider>().currentLanguage == 'tr'
                ? 'Ayarlar kaydedilemedi: ${e.toString()}'
                : 'Failed to save settings: ${e.toString()}',
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final language = languageProvider.currentLanguage;
        
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
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
                      language == 'tr' 
                        ? 'Gizliliğiniz Önemli' 
                        : 'Your Privacy Matters',
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
                language == 'tr'
                  ? 'Verilerinizi nasıl kullandığımızı kontrol edin. GDPR uyumlu gizlilik seçeneklerinizi yönetin.'
                  : 'Control how we use your data. Manage your GDPR-compliant privacy options.',
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
                        language == 'tr' 
                          ? 'İzinleri Yönet' 
                          : 'Manage Consent',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ConsentDialog(),
    );
  }
}