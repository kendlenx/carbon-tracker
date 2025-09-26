class PrivacyPolicyContent {
  static Map<String, String> getPrivacyPolicy(String language) {
    if (language == 'tr') {
      return _turkishPrivacyPolicy;
    }
    return _englishPrivacyPolicy;
  }

  static final Map<String, String> _englishPrivacyPolicy = {
    'title': 'Privacy Policy',
    'lastUpdated': 'Last updated: December 26, 2024',
    'introduction': '''Carbon Tracker ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.''',
    
    'dataCollection': '''Data We Collect

Personal Information:
• Email address (for account creation and authentication)
• Profile information (name, profile picture - optional)
• Authentication data (encrypted passwords, biometric templates stored locally)

Usage Data:
• Carbon footprint activities and measurements
• Transportation preferences and history
• App usage statistics and performance metrics
• Device information (model, operating system, app version)

Location Data:
• Approximate location for regional carbon factor calculations (optional)
• Trip tracking for transportation carbon calculations (with your consent)

Technical Data:
• App crashes and error logs (anonymized)
• Performance metrics and analytics data''',

    'dataUsage': '''How We Use Your Data

We use collected information to:
• Provide and maintain our carbon tracking services
• Calculate accurate carbon footprint measurements
• Sync your data across devices (with cloud backup enabled)
• Improve app performance and user experience
• Send important updates and notifications
• Comply with legal obligations
• Provide customer support

We DO NOT:
• Sell your personal data to third parties
• Use your data for advertising purposes
• Share your individual carbon data publicly
• Access your biometric data (stored locally only)''',

    'dataSharing': '''Data Sharing and Disclosure

We may share your information only in these limited circumstances:
• With your explicit consent
• To comply with legal obligations or court orders
• To protect our rights, property, or safety
• In case of business merger or acquisition (with prior notice)
• With service providers bound by confidentiality agreements

Third-party Services:
• Firebase (Google) for authentication and cloud storage
• Analytics services for app improvement (anonymized data only)''',

    'dataStorage': '''Data Storage and Security

Security Measures:
• End-to-end encryption for sensitive data
• Local biometric authentication
• Secure cloud storage with Firebase
• Regular security audits and updates
• Data minimization principles

Data Retention:
• Account data: Until account deletion
• Usage analytics: Maximum 2 years
• Crash logs: Maximum 1 year
• Deleted data: Permanently removed within 30 days''',

    'userRights': '''Your Rights (GDPR Compliance)

You have the right to:
• Access your personal data
• Correct inaccurate information
• Delete your account and data
• Export your data in a portable format
• Withdraw consent for data processing
• Object to automated decision-making
• Lodge complaints with supervisory authorities

To exercise these rights, contact us at privacy@carbontracker.app''',

    'cookiesTracking': '''Cookies and Tracking

We use minimal tracking technologies:
• Essential cookies for app functionality
• Analytics cookies (with consent) for app improvement
• No advertising or marketing cookies
• Local storage for app preferences and settings

You can manage cookie preferences in app settings.''',

    'childrenPrivacy': '''Children's Privacy

Our app is not intended for users under 13 years old. We do not knowingly collect personal information from children. If we discover such collection, we will delete the information immediately.''',

    'internationalTransfers': '''International Data Transfers

Your data may be transferred to and processed in countries outside your residence. We ensure adequate protection through:
• Standard Contractual Clauses
• Adequacy decisions by relevant authorities
• Appropriate safeguards and security measures''',

    'changes': '''Policy Changes

We may update this Privacy Policy periodically. We will notify you of significant changes through:
• In-app notifications
• Email notifications (if provided)
• App store update notes

Continued use after changes constitutes acceptance of the updated policy.''',

    'contact': '''Contact Information

For privacy-related questions or concerns:

Email: privacy@carbontracker.app
Data Protection Officer: dpo@carbontracker.app

Response time: Within 30 days for GDPR requests
Emergency contact: Available through app support''',
  };

  static final Map<String, String> _turkishPrivacyPolicy = {
    'title': 'Gizlilik Politikası',
    'lastUpdated': 'Son güncelleme: 26 Aralık 2024',
    'introduction': '''Carbon Tracker ("biz", "bizim" veya "uygulamamız"), gizliliğinizi korumayı taahhüt eder. Bu Gizlilik Politikası, mobil uygulamamızı kullandığınızda bilgilerinizi nasıl topladığımızı, kullandığımızı, paylaştığımızı ve koruduğumuzu açıklar.''',
    
    'dataCollection': '''Topladığımız Veriler

Kişisel Bilgiler:
• E-posta adresi (hesap oluşturma ve doğrulama için)
• Profil bilgileri (ad, profil resmi - isteğe bağlı)
• Kimlik doğrulama verileri (şifrelenmiş parolalar, yerel olarak saklanan biyometrik şablonlar)

Kullanım Verileri:
• Karbon ayak izi aktiviteleri ve ölçümleri
• Ulaşım tercihleri ve geçmişi
• Uygulama kullanım istatistikleri ve performans metrikleri
• Cihaz bilgileri (model, işletim sistemi, uygulama sürümü)

Konum Verileri:
• Bölgesel karbon faktörü hesaplamaları için yaklaşık konum (isteğe bağlı)
• Ulaşım karbon hesaplamaları için seyahat takibi (izninizle)

Teknik Veriler:
• Uygulama çökmeleri ve hata günlükleri (anonimleştirilmiş)
• Performans metrikleri ve analitik verileri''',

    'dataUsage': '''Verilerinizi Nasıl Kullanırız

Toplanan bilgileri şunlar için kullanırız:
• Karbon izleme hizmetlerimizi sağlamak ve sürdürmek
• Doğru karbon ayak izi ölçümleri hesaplamak
• Verilerinizi cihazlar arası senkronize etmek (bulut yedekleme etkinse)
• Uygulama performansını ve kullanıcı deneyimini iyileştirmek
• Önemli güncellemeler ve bildirimler göndermek
• Yasal yükümlülüklere uymak
• Müşteri desteği sağlamak

YAPMADIKLARIMIZ:
• Kişisel verilerinizi üçüncü taraflara satmak
• Verilerinizi reklam amaçları için kullanmak
• Bireysel karbon verilerinizi halka açık olarak paylaşmak
• Biyometrik verilerinize erişmek (yalnızca yerel olarak saklanır)''',

    'dataSharing': '''Veri Paylaşımı ve Açıklama

Bilgilerinizi yalnızca şu sınırlı durumlarda paylaşabiliriz:
• Açık izninizle
• Yasal yükümlülüklere veya mahkeme kararlarına uymak için
• Haklarımızı, mülkümüzü veya güvenliğimizi korumak için
• İş birleşmesi veya devralma durumunda (önceden bildirimle)
• Gizlilik anlaşmalarıyla bağlı hizmet sağlayıcılarla

Üçüncü Taraf Hizmetleri:
• Firebase (Google) kimlik doğrulama ve bulut depolama için
• Uygulama iyileştirmesi için analitik hizmetleri (yalnızca anonimleştirilmiş veriler)''',

    'dataStorage': '''Veri Depolama ve Güvenlik

Güvenlik Önlemleri:
• Hassas veriler için uçtan uca şifreleme
• Yerel biyometrik kimlik doğrulama
• Firebase ile güvenli bulut depolama
• Düzenli güvenlik denetimleri ve güncellemeleri
• Veri minimizasyonu ilkeleri

Veri Saklama:
• Hesap verileri: Hesap silinene kadar
• Kullanım analitikleri: Maksimum 2 yıl
• Çökme günlükleri: Maksimum 1 yıl
• Silinen veriler: 30 gün içinde kalıcı olarak kaldırılır''',

    'userRights': '''Haklarınız (GDPR Uyumluluğu)

Şu haklara sahipsiniz:
• Kişisel verilerinize erişim
• Yanlış bilgileri düzeltme
• Hesabınızı ve verilerinizi silme
• Verilerinizi taşınabilir formatta dışa aktarma
• Veri işleme izninizi geri çekme
• Otomatik karar vermeye itiraz etme
• Denetim otoritelerine şikayette bulunma

Bu hakları kullanmak için bize privacy@carbontracker.app adresinden ulaşın''',

    'cookiesTracking': '''Çerezler ve İzleme

Minimum izleme teknolojileri kullanırız:
• Uygulama işlevselliği için gerekli çerezler
• Uygulama iyileştirmesi için analitik çerezler (izinle)
• Reklam veya pazarlama çerezi yok
• Uygulama tercihleri ve ayarları için yerel depolama

Çerez tercihlerini uygulama ayarlarından yönetebilirsiniz.''',

    'childrenPrivacy': '''Çocukların Gizliliği

Uygulamamız 13 yaşından küçük kullanıcılar için tasarlanmamıştır. Çocuklardan bilerek kişisel bilgi toplamayız. Böyle bir toplama durumu keşfedersek, bilgileri derhal sileriz.''',

    'internationalTransfers': '''Uluslararası Veri Transferleri

Verileriniz, ikamet ettiğiniz ülke dışındaki ülkelere aktarılabilir ve işlenebilir. Şunlar aracılığıyla yeterli koruma sağlarız:
• Standart Sözleşme Hükümleri
• İlgili otoritelerin yeterlilik kararları
• Uygun güvenlik önlemleri ve güvenlik tedbirleri''',

    'changes': '''Politika Değişiklikleri

Bu Gizlilik Politikasını periyodik olarak güncelleyebiliriz. Önemli değişiklikleri şu yollarla bildireceğiz:
• Uygulama içi bildirimler
• E-posta bildirimleri (sağlanmışsa)
• App store güncelleme notları

Değişikliklerden sonra kullanımınızı sürdürmeniz, güncellenmiş politikanın kabulü anlamına gelir.''',

    'contact': '''İletişim Bilgileri

Gizlilik ile ilgili sorular veya endişeler için:

E-posta: privacy@carbontracker.app
Veri Koruma Sorumlusu: dpo@carbontracker.app

Yanıt süresi: GDPR talepleri için 30 gün içinde
Acil durum iletişimi: Uygulama desteği üzerinden mevcut''',
  };

  // Helper method to get section keys in order
  static List<String> getSectionKeys() {
    return [
      'introduction',
      'dataCollection',
      'dataUsage',
      'dataSharing',
      'dataStorage',
      'userRights',
      'cookiesTracking',
      'childrenPrivacy',
      'internationalTransfers',
      'changes',
      'contact',
    ];
  }

  // Get section titles for navigation
  static Map<String, String> getSectionTitles(String language) {
    if (language == 'tr') {
      return {
        'introduction': 'Giriş',
        'dataCollection': 'Veri Toplama',
        'dataUsage': 'Veri Kullanımı',
        'dataSharing': 'Veri Paylaşımı',
        'dataStorage': 'Veri Depolama',
        'userRights': 'Haklarınız',
        'cookiesTracking': 'Çerezler',
        'childrenPrivacy': 'Çocuk Gizliliği',
        'internationalTransfers': 'Uluslararası Transfer',
        'changes': 'Değişiklikler',
        'contact': 'İletişim',
      };
    }
    return {
      'introduction': 'Introduction',
      'dataCollection': 'Data Collection',
      'dataUsage': 'Data Usage',
      'dataSharing': 'Data Sharing',
      'dataStorage': 'Data Storage',
      'userRights': 'Your Rights',
      'cookiesTracking': 'Cookies & Tracking',
      'childrenPrivacy': 'Children\'s Privacy',
      'internationalTransfers': 'International Transfers',
      'changes': 'Policy Changes',
      'contact': 'Contact Us',
    };
  }
}