# 🌱 Carbon Tracker

**Kişisel karbon ayak izinizi takip edin, çevre için fark yaratın!**

Carbon Tracker, günlük aktivitelerinizin çevresel etkisini ölçen ve azaltmanıza yardımcı olan modern bir mobil uygulamadır. Türkiye'ye özel CO₂ emisyon faktörleri ile doğru hesaplamalar yapar ve kişiselleştirilmiş önerilerle sürdürülebilir yaşama geçişinizi destekler.

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.29.0-blue?style=for-the-badge&logo=flutter" alt="Flutter Version">
  <img src="https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=android" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Status-Ready%20for%20Play%20Store-success?style=for-the-badge" alt="Status">
</div>

## 📱 Özellikler

### 🚗 **Akıllı Ulaşım Takibi**
- 9 farklı ulaşım türü desteği (araba, otobüs, metro, bisiklet, vb.)
- Türkiye'ye özel CO₂ emisyon faktörleri
- Gerçek zamanlı emisyon hesaplama
- Mesafe girişi ve detaylı notlar

### 📊 **Görsel İstatistikler**
- Haftalık ve aylık trend grafikleri
- Kategori bazlı pasta grafikler
- Performans karşılaştırmaları
- Renkli analiz raporları

### 🎯 **Kişiselleştirilmiş Öneriler**
- Türkiye ortalaması ile karşılaştırma
- Paris İklim Anlaşması hedefleri
- Akıllı tasarruf önerileri
- Zorluk seviyeli eylem planları

### 💾 **Güvenli Veri Yönetimi**
- SQLite ile offline veri saklama
- Günlük, haftalık, aylık istatistikler
- Aktivite geçmişi
- Veri yedekleme sistemi

### 🎨 **Modern Tasarım**
- Material Design 3 uyumlu arayüz
- Karanlık/aydınlık tema desteği
- Kullanıcı dostu navigasyon
- Responsive tasarım

## 🚀 Kurulum

### Gereksinimler
- Flutter 3.29.0 veya üstü
- Dart 3.7.0 veya üstü
- Android SDK (API 21+)
- Git

### Adımlar

1. **Repository'yi klonlayın:**
```bash
git clone https://github.com/kendlenx/carbon-tracker.git
cd carbon-tracker
```

2. **Bağımlılıkları yükleyin:**
```bash
flutter pub get
```

3. **Uygulamayı çalıştırın:**
```bash
flutter run
```

## 📦 Kullanılan Paketler

| Paket | Versiyon | Açıklama |
|-------|----------|----------|
| `sqflite` | ^2.3.0 | SQLite veritabanı yönetimi |
| `fl_chart` | ^0.66.0 | Grafik ve chart görselleştirme |
| `intl` | ^0.19.0 | Tarih ve sayı formatlama |
| `path` | ^1.8.3 | Dosya yolu yönetimi |

## 🏗️ Proje Yapısı

```
lib/
├── models/                 # Veri modelleri
│   └── transport_model.dart
├── screens/               # Sayfa widget'ları
│   ├── transport_screen.dart
│   ├── add_activity_screen.dart
│   └── statistics_screen.dart
├── services/              # İş mantığı servisleri
│   ├── database_service.dart
│   └── carbon_calculator_service.dart
└── main.dart             # Ana uygulama dosyası
```

## 🌍 Teknik Detaylar

### CO₂ Emisyon Faktörleri
- **Benzinli Araba**: 0.21 kg CO₂/km
- **Dizel Araba**: 0.18 kg CO₂/km
- **Metro/Tramvay**: 0.04 kg CO₂/km
- **Şehir Otobüsü**: 0.08 kg CO₂/km
- **Bisiklet/Yürüyüş**: 0.0 kg CO₂/km

*Kaynak: EU Environment Agency, IPCC Guidelines, TEİAŞ 2023 verileri*

### Veritabanı Şeması
```sql
CREATE TABLE transport_activities (
  id TEXT PRIMARY KEY,
  transport_type_id TEXT NOT NULL,
  distance_km REAL NOT NULL,
  co2_emission REAL NOT NULL,
  created_at INTEGER NOT NULL,
  notes TEXT
);
```

## 📸 Ekran Görüntüleri

<div align="center">
  <img src="screenshots/home_screen.png" width="250" alt="Ana Sayfa">
  <img src="screenshots/transport_screen.png" width="250" alt="Ulaşım Sayfası">
  <img src="screenshots/statistics_screen.png" width="250" alt="İstatistik Sayfası">
</div>

## 🔄 Geliştirme Süreci

### Tamamlanan Özellikler ✅
- [x] Ulaşım kategorisi detay sayfası
- [x] SQLite veri saklama yapısı
- [x] Aktivite ekleme sayfası
- [x] İstatistik grafikleri
- [x] Gelişmiş karbon hesaplama algoritmaları
- [x] Performans karşılaştırması
- [x] Kişiselleştirilmiş öneriler

### Gelecek Güncellemeler 🚀
- [ ] Enerji kategorisi (elektrik, doğal gaz)
- [ ] Yemek kategorisi (beslenme alışkanlıkları)
- [ ] Alışveriş kategorisi (tüketim malları)
- [ ] Sosyal paylaşım özellikleri
- [ ] Çoklu kullanıcı desteği
- [ ] Cloud sync
- [ ] Widget desteği

## 🤝 Katkıda Bulunma

1. Bu repository'yi fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add: amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 👨‍💻 Geliştirici

**Mert** - [@kendlenx](https://github.com/kendlenx)

---

<div align="center">
  <p><strong>🌱 Çevre için küçük adımlar, büyük değişiklikler! 🌍</strong></p>
  <p>⭐ Beğendiyseniz yıldız vermeyi unutmayın!</p>
</div>
