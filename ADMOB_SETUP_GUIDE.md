# 🚀 AdMob Uygulama Oluşturma ve Yapılandırma Rehberi

## 📱 Adım 1: AdMob Hesabı Oluşturma

### 1.1 AdMob Console'a Giriş
1. [AdMob Console](https://apps.admob.com/) adresine gidin
2. Google hesabınızla giriş yapın
3. Hesap oluşturma formunu doldurun:
   - **Ülke/Bölge**: Türkiye
   - **Para Birimi**: USD (Türk Lirası da seçilebilir)
   - **Ödeme bilgilerinizi** ekleyin

### 1.2 AdSense Hesabı Bağlantısı
- AdMob otomatik olarak AdSense hesabı oluşturacak
- Bu işlem 24-48 saat sürebilir
- Onay beklerken test reklamlarıyla devam edebilirsiniz

## 📱 Adım 2: Uygulama Ekleme

### 2.1 Yeni Uygulama Ekleme
```bash
# AdMob Console'da:
1. "Apps" sekmesine tıklayın
2. "Add app" butonuna tıklayın
3. Platform seçin: "Android"
4. Uygulama durumunu seçin: "No" (henüz yayınlanmamış)
5. App name: "Carbon Step"
6. "ADD APP" butonuna tıklayın
```

### 2.2 Uygulama Bilgileri
- **Uygulama Adı**: Carbon Step
- **Kategori**: Tools & Utilities
- **İçerik Derecelendirmesi**: Everyone
- **Konum**: Türkiye

## 📱 Adım 3: Reklam Üniteleri Oluşturma

### 3.1 Banner Reklam Ünitesi
```bash
# AdMob Console'da:
1. Uygulamanızı seçin
2. "Ad units" sekmesine tıklayın
3. "Add ad unit" -> "Banner"
4. Ad unit name: "Carbon Step Banner"
5. CREATE AD UNIT
6. Ad Unit ID'yi kaydedin: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
```

### 3.2 Interstitial Reklam Ünitesi
```bash
1. "Add ad unit" -> "Interstitial"
2. Ad unit name: "Carbon Step Interstitial"
3. CREATE AD UNIT
4. Ad Unit ID'yi kaydedin: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
```

### 3.3 Rewarded Video Reklam Ünitesi
```bash
1. "Add ad unit" -> "Rewarded"
2. Ad unit name: "Carbon Step Rewarded"
3. Reward settings:
   - Reward item: "Premium Features"
   - Reward amount: 1
4. CREATE AD UNIT
5. Ad Unit ID'yi kaydedin: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
```

### 3.4 Native Reklam Ünitesi
```bash
1. "Add ad unit" -> "Native advanced"
2. Ad unit name: "Carbon Step Native"
3. CREATE AD UNIT
4. Ad Unit ID'yi kaydedin: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
```

## 📱 Adım 4: App ID'yi Almak

### 4.1 App ID Lokasyonu
```bash
# AdMob Console'da:
1. "App settings" sekmesine tıklayın
2. "App ID" bölümünde ID'yi kopyalayın
3. Format: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
```

### 4.2 App ID'yi Android Manifest'e Ekleme
Dosya: `android/app/src/main/AndroidManifest.xml`
```xml
<application>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
</application>
```

## 📱 Adım 5: Reklam ID'lerini Kodda Güncelleme

### 5.1 AdMob Service'i Güncelleme
Dosya: `lib/services/admob_service.dart`
```dart
// GERÇEK REKLAM ID'LERİNİZİ BURAYA EKLEYİN
static String get _bannerAdUnitId => kDebugMode
    ? 'ca-app-pub-3940256099942544/6300978111' // Test ID
    : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // SİZİN BANNER ID'NİZ

static String get _interstitialAdUnitId => kDebugMode
    ? 'ca-app-pub-3940256099942544/1033173712' // Test ID
    : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // SİZİN INTERSTITIAL ID'NİZ

static String get _rewardedAdUnitId => kDebugMode
    ? 'ca-app-pub-3940256099942544/5224354917' // Test ID
    : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // SİZİN REWARDED ID'NİZ

static String get _nativeAdUnitId => kDebugMode
    ? 'ca-app-pub-3940256099942544/2247696110' // Test ID
    : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // SİZİN NATIVE ID'NİZ
```

## 📱 Adım 6: Test Cihazı Ekleme

### 6.1 Test Device ID'yi Almak
```bash
# Android Logcat'te şu satırı arayın:
I/Ads: Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"))
```

### 6.2 Test Device ID'yi Eklemek
```dart
await MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(
    testDeviceIds: ['XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'], // SİZİN CİHAZ ID'NİZ
  ),
);
```

## 📱 Adım 7: AdMob Politikaları

### 7.1 Önemli Kurallar
- ❌ Kendi reklamlarınıza tıklamayın
- ❌ Kullanıcıları reklam tıklamaya zorlayamayın
- ❌ Reklamları gizleyemez veya değiştiremezsiniz
- ✅ Reklam yükleme hatalarını doğru handle edin
- ✅ Kullanıcı deneyimini önceliklendirin

### 7.2 İçerik Politikaları
- ✅ Çevre dostu içerik (Carbon Step için uygun)
- ✅ Eğitici içerik
- ❌ Şiddet, nefret söylemi yasak
- ❌ Yetişkin içerik yasak

## 📱 Adım 8: Gelir Optimizasyonu

### 8.1 Reklam Yerleşimi Stratejisi
```
🥇 Rewarded Video: En yüksek CPM ($15-50)
   - Premium özellik açma
   - Ekstra ipuçlar alma
   - Achievement detayları

🥈 Native Ads: Yüksek CPM ($8-30)
   - Ana sayfa içeriği arasında
   - Ayarlar sayfasında

🥉 Interstitial: Orta CPM ($3-12)
   - Sayfa geçişlerinde
   - Uygulama başlangıcında

🥉 Banner: Düşük ama sabit CPM ($0.5-3)
   - Ana sayfa altında
   - Sürekli görünür
```

### 8.2 CPM Artırma İpuçları
- **Coğrafya**: ABD/Avrupa kullanıcıları yüksek CPM
- **Kategori**: Finance/Shopping yüksek CPM
- **Format**: Native > Rewarded > Interstitial > Banner
- **Timing**: Akşam saatleri daha yüksek CPM

## 📱 Adım 9: Ödeme Ayarları

### 9.1 Minimum Ödeme Tutarları
- **AdSense PIN**: İlk $10 gelirde PIN gönderilir
- **İlk Ödeme**: $100 minimum
- **Sonraki Ödemeler**: $100 minimum

### 9.2 Ödeme Yöntemleri
- **Banka Havalesi**: Türkiye'de mevcut
- **Western Union**: Alternatif yöntem
- **Çek**: Mevcut ancak tavsiye edilmez

### 9.3 Vergi Bilgileri
- ABD vergi formu doldurulmalı (W-8BEN)
- Türkiye vatandaşları için %30 vergi kesintisi
- Çifte vergilendirme anlaşması var

## 📱 Adım 10: Performans Takibi

### 10.1 Önemli Metrikler
- **eCPM**: Her 1000 gösterim başına gelir
- **Fill Rate**: Reklam gösterim oranı  
- **CTR**: Tıklama oranı
- **Impression**: Reklam görüntüleme sayısı

### 10.2 Optimizasyon
- **A/B Testing**: Farklı reklam formatları test edin
- **Placement Testing**: Farklı konumlar test edin
- **Timing Analysis**: En iyi saatleri bulun
- **User Segmentation**: Kullanıcı türlerine göre optimize edin

## 📱 Adım 11: Sorun Giderme

### 11.1 Yaygın Hatalar
```
❌ "Ad failed to load" hatası:
   - İnternet bağlantısını kontrol edin
   - Test Device ID'yi kontrol edin
   - Ad Unit ID'lerini kontrol edin

❌ "No fill" hatası:
   - AdMob'da yeterli reklam yok
   - Coğrafi kısıtlama olabilir
   - Kategori uyumsuzluğu olabilir

❌ "Invalid request" hatası:  
   - App ID yanlış
   - Manifest yapılandırması yanlış
   - Test Device ID eksik
```

### 11.2 Debug İpuçları
```dart
// AdMob debug logging açın
MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
    tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
    testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
  ),
);
```

## 📱 Sonuç

Bu rehberi takip ederek AdMob'u Carbon Step uygulamanızda başarıyla yapılandırabilirsiniz. Test reklamları çalıştıktan sonra gerçek reklam ID'lerini kullanarak uygulamayı Play Store'da yayınlayabilirsiniz.

### Önemli Hatırlatmalar:
1. **İlk 1-2 gün test reklamları kullanın**
2. **Gerçek reklam ID'lerini sadece production'da kullanın**
3. **AdMob politikalarına uygun hareket edin**
4. **Kullanıcı deneyimini önceliklendirin**
5. **Gelir optimizasyonu için sürekli test edin**

---
📧 Sorularınız için: [AdMob Help Center](https://support.google.com/admob/)