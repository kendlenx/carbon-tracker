<div align="center">

# 🌱 **Carbon Step**

*Karbon Ayak İzinizi Takip Edin, Etkilerinizi Dönüştürün*

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![MIT License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](https://choosealicense.com/licenses/mit/)

**Çevresel etkilerinizi izlemek ve daha yeşil bir gezegene katkıda bulunmak için kapsamlı bir mobil uygulama**

</div>

---

## 🎯 **Carbon Step Hakkında**

Carbon Step, Türk kullanıcıların karbon ayak izlerini izlemek, analiz etmek ve azaltmak için özel olarak tasarlanmış **premium kalitede bir mobil uygulamadır**. **Gelişmiş AI benzeri öneriler**, **oyunlaştırma öğeleri** ve **çarpıcı animasyonlar** ile çevresel farkındalığı ilgi çekici bir günlük alışkanlığa dönüştürür.

> 🌍 **Daha temiz bir gezegene doğru atılan her adım önemlidir!**

---

## ✨ **Premium Özellikler**

### 🚗 **Akıllı Ulaşım Takibi**
- **9 Ulaşım Türü**: Araba, otobüs, metro, minibüs, taksi, bisiklet, yürüme, motosiklet ve daha fazlası
- **Gerçek Zamanlı CO₂ Hesaplamaları**: Mesafe ve ulaşım türüne dayalı anlık emisyon hesapları
- **Türkiye'ye Özel Emisyon Faktörleri**: Doğru sonuçlar için yerelлеştirilmiş hesaplamalar
- **Yakıt Tüketim Analizi**: Benzin ve dizel kullanımı için detaylı bilgiler

### ⚡ **Enerji İzleme**
- **Elektrik Tüketimi**: Günlük CO₂ dökümü ile aylık kullanımı takip edin
- **Doğal Gaz Takibi**: Isıtma ve sıcak su çevresel etkisini izleyin
- **Türkiye Enerji Karışımı**: Ulusal enerji üretim kaynaklarına dayalı hesaplamalar

### 🏆 **Başarı ve Oyunlaştırma Sistemi**
- **Rozet Koleksiyonu**: Çevre dostu davranışlar için başarıları açın
- **XP ve Seviye Atlama**: Deneyim puanları kazanın ve seviye atlayın
- **Süreklilik Takibi**: Tutarlı çevresel alışkanlıkları koru
- **Kutlama Animasyonları**: Tatmin edici açılış deneyimleri

### 🧠 **AI-Powered Smart Features**
- **🎤 Voice Commands**: Turkish voice recognition for hands-free activity logging
- **📍 GPS Auto-tracking**: Automatic transport detection and trip logging
- **🔔 Smart Notifications**: Context-aware reminders and achievement alerts
- **🏠 Smart Home Integration**: IoT device monitoring and energy optimization
- **⌚ Wearable Support**: Apple Watch and Wear OS integration
- **📱 Device Sync**: CarPlay, Android Auto, and multi-device support
- **Daily Recommendations**: Personalized CO₂ reduction suggestions
- **Habit Tracking**: Build sustainable routines with progress monitoring
- **Performance Insights**: Advanced analytics with trend analysis

### 🎨 **Premium UI/UX**
- **Hero Dashboard**: Animated circular progress rings with real-time counters
- **Liquid Pull Refresh**: Physics-based refresh animations with wave effects
- **Morphing FAB**: Context-aware floating action buttons
- **Custom Page Transitions**: 12+ transition types including ripple, flip, and morphing
- **Micro-interactions**: Haptic feedback and smooth button animations
- **Glassmorphism Design**: Modern UI with backdrop blur effects

### 📊 **Advanced Analytics**
- **Interactive Charts**: Rich visualizations with FL Chart integration
- **Weekly/Monthly Trends**: Track progress over time
- **Category Analysis**: Identify high-emission activities
- **Comparison Tools**: Compare with Turkey averages and Paris Agreement targets

---

## 🎬 **App Showcase**

<div align="center">

### 🌟 **Hero Dashboard**
![Hero Dashboard](screenshots/hero_dashboard.gif)

### 💧 **Liquid Refresh Animation**
![Liquid Refresh](screenshots/liquid_refresh.gif)

### 🏆 **Achievement System**
![Achievement System](screenshots/achievements.gif)

### ✨ **Page Transitions**
![Page Transitions](screenshots/page_transitions.gif)

</div>

---

## 🚀 **Quick Start**

### Prerequisites
```bash
✅ Flutter SDK (≥3.10.0)
✅ Dart SDK (≥3.0.0)  
✅ Android Studio / VS Code
✅ Android SDK (API Level 21+)
✅ iOS 11.0+ (for iOS development)
```

### Installation
```bash
# Clone the repository
git clone https://github.com/kendlenx/carbon-tracker.git

# Navigate to project directory
cd carbon-tracker

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## 🏗️ **Architecture**

Carbon Tracker follows **clean architecture principles** with a **service-oriented design**:

```
🌱 Carbon Step
├── 📱 Presentation Layer
│   ├── 🖼️  Screens (Home, Transport, Energy, Statistics, Achievements)
│   ├── 🧩 Widgets (Hero Dashboard, Modern UI Components)
│   └── 🎨 Themes (Dark/Light with Premium Animations)
│
├── 🔧 Business Logic Layer  
│   ├── 📊 Services (Database, Carbon Calculator, AI Recommendations)
│   ├── 🏆 Achievement System (Badge Management, XP Tracking)
│   └── 🧠 Smart Features (Habit Tracking, Goal Setting)
│
└── 💾 Data Layer
    ├── 🗄️  SQLite Database (Transport & Energy Activities)
    ├── 🔄 State Management (Provider Pattern)
    └── 📦 Local Storage (SharedPreferences)
```

---

## 🔬 **CO₂ Calculation Methodology**

Our calculations are based on **scientific standards** and **localized data**:

### 🚗 **Transport Emissions**
| Transport Type | CO₂ Factor | Source |
|:---:|:---:|:---:|
| 🚗 Personal Car (Petrol) | 0.21 kg CO₂/km | Turkish Statistical Institute |
| 🚗 Personal Car (Diesel) | 0.17 kg CO₂/km | Energy Market Regulatory Authority |
| 🚌 Bus | 0.089 kg CO₂/km | IETT Environmental Reports |
| 🚇 Metro | 0.041 kg CO₂/km | Istanbul Metro Sustainability Data |
| 🚶 Walking/🚲 Cycling | 0 kg CO₂/km | Zero Emission |

### ⚡ **Energy Emissions**
| Energy Source | CO₂ Factor | Basis |
|:---:|:---:|:---:|
| ⚡ Electricity | 0.49 kg CO₂/kWh | Turkey's Energy Mix 2024 |
| 🔥 Natural Gas | 0.202 kg CO₂/kWh | IPCC Guidelines |

---

## 🎯 **Roadmap**

### ✅ **Recently Added (v1.0.0)**
- 🌍 **Multi-language Support**: Turkish (default) and English
- 📱 **Widget Support**: iOS/Android home screen widgets ✅
- 🎤 **Voice Commands**: Turkish speech recognition and TTS ✅
- 📍 **GPS Integration**: Auto transport detection ✅
- 🔔 **Smart Notifications**: Intelligent reminders system ✅
- 🏠 **Smart Home**: IoT device integration ✅
- ⌚ **Device Integration**: Watch, CarPlay, shortcuts ✅
- 🎯 **Goal System**: Adaptive goals and progress tracking ✅
- 🏆 **Advanced Badges**: Level-based achievement system ✅

### 🔜 **Coming Soon**
- 🍽️ **Food Category**: Nutrition habit carbon impact tracking
- 🛍️ **Shopping Tracker**: Consumer goods environmental impact
- 🌐 **Cloud Sync**: Multi-device synchronization
- 📈 **Data Export**: CSV/JSON format data export capabilities

### 🚀 **Future Vision**
- 👥 **Social Features**: Friend comparisons and sharing
- 🤖 **Advanced AI**: Machine learning personalized recommendations  
- 🏢 **Corporate Version**: Enterprise carbon footprint management
- 🤖 **Predictive Analytics**: AI-powered carbon forecasting

---

## 🤝 **Contributing**

We welcome contributions! Here's how you can help:

1. 🍴 **Fork** the repository
2. 🌿 **Create** your feature branch (`git checkout -b feature/amazing-feature`)
3. 💻 **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. 📤 **Push** to the branch (`git push origin feature/amazing-feature`)
5. 🔄 **Open** a Pull Request

---

## 📄 **License**

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 **Developer**

<div align="center">

**Mert**  
*Full Stack Developer*

[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/kendlenx)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](#)

</div>

---

## 🙏 **Acknowledgments**

- 🎨 **Flutter Team** - For the amazing framework
- 📊 **FL Chart** - For beautiful chart visualizations  
- 🗄️ **SQLite** - For reliable local data storage
- 🎯 **Material Design** - For design system guidelines
- 🌍 **Turkish Statistical Institute** - For local emission data

---

<div align="center">

### 🌍 **Together for a Greener Tomorrow** 🌱

*Made with 💚 for the environment*

**Star ⭐ this repo if you find it helpful!**

</div>