import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 💰 AdMob Service - Maximum Revenue Strategy
/// 
/// Revenue Hierarchy:
/// 1. Rewarded Video Ads: $10-50 CPM (Highest)
/// 2. Interstitial Ads: $5-15 CPM (Medium) 
/// 3. Banner Ads: $0.50-3 CPM (Low but consistent)
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  static AdMobService get instance => _instance;

  // Ad Unit IDs - Production IDs
  static String get _bannerAdUnitId => kDebugMode
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Test banner Android
          : 'ca-app-pub-3940256099942544/2934735716') // Test banner iOS
      : (Platform.isAndroid
          ? 'ca-app-pub-8523472394185227/5986288065' // Production banner Android
          : 'ca-app-pub-8523472394185227/5986288065'); // Production banner iOS

  static String get _interstitialAdUnitId => kDebugMode
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Test interstitial Android
          : 'ca-app-pub-3940256099942544/4411468910') // Test interstitial iOS
      : (Platform.isAndroid
          ? 'ca-app-pub-8523472394185227/1204734672' // Production interstitial Android
          : 'ca-app-pub-8523472394185227/1204734672'); // Production interstitial iOS

  static String get _rewardedAdUnitId => kDebugMode
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917' // Test rewarded Android
          : 'ca-app-pub-3940256099942544/1712485313') // Test rewarded iOS
      : (Platform.isAndroid
          ? 'ca-app-pub-8523472394185227/7566963048' // Production rewarded Android
          : 'ca-app-pub-8523472394185227/7566963048'); // Production rewarded iOS

  static String get _nativeAdUnitId => kDebugMode
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110' // Test native Android
          : 'ca-app-pub-3940256099942544/3986624511') // Test native iOS
      : (Platform.isAndroid
          ? 'ca-app-pub-8523472394185227/9486565289' // Production native Android
          : 'ca-app-pub-8523472394185227/9486565289'); // Production native iOS

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Ad states
  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;

  // Revenue tracking
  int _bannerImpressions = 0;
  int _interstitialImpressions = 0;
  int _rewardedImpressions = 0;
  int _nativeImpressions = 0;

  /// Initialize AdMob SDK
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
          testDeviceIds: kDebugMode ? [
            'kGooglePlayServicesTestDeviceId', // Emulator for testing
            '33BE2250B43518CCDA7DE426D04EE232' // Add your device ID here
          ] : [],
        ),
      );
      debugPrint('🎯 AdMob initialized successfully');
      
      // Preload high-value ads immediately
      _loadRewardedAd();
      _loadInterstitialAd();
    } catch (e) {
      debugPrint('❌ AdMob initialization failed: $e');
    }
  }

  // 🥇 BANNER ADS - Low value but consistent revenue
  void loadBannerAd() {
    // Use a cross-platform banner size to avoid Android-only assertions on iOS
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerAdReady = true;
          debugPrint('🎯 Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          _isBannerAdReady = false;
          ad.dispose();
          debugPrint('❌ Banner ad failed to load: $error');
        },
        onAdImpression: (_) {
          _bannerImpressions++;
          debugPrint('📊 Banner impression #$_bannerImpressions');
        },
      ),
    );
    _bannerAd?.load();
  }

  BannerAd? get bannerAd => _isBannerAdReady ? _bannerAd : null;

  // 🥈 INTERSTITIAL ADS - Medium value, strategic placement
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('🎯 Interstitial ad loaded successfully');

          // Set full screen content callback
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (_) {
              _interstitialImpressions++;
              debugPrint('📊 Interstitial impression #$_interstitialImpressions');
            },
            onAdDismissedFullScreenContent: (_) {
              _interstitialAd?.dispose();
              _isInterstitialAdReady = false;
              // Preload next interstitial ad
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              debugPrint('❌ Interstitial ad failed to show: $error');
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          debugPrint('❌ Interstitial ad failed to load: $error');
          // Retry after delay
          Future.delayed(const Duration(minutes: 1), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Show interstitial ad - optimal for page transitions
  Future<void> showInterstitialAd({String? context}) async {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      debugPrint('🚀 Showing interstitial ad - Context: $context');
      await _interstitialAd?.show();
    } else {
      debugPrint('⏳ Interstitial ad not ready, loading...');
      _loadInterstitialAd();
    }
  }

  // 🥇 REWARDED VIDEO ADS - Highest value, best CPM
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('🎯 Rewarded video ad loaded successfully');

          // Set full screen content callback
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (_) {
              _rewardedImpressions++;
              debugPrint('📊 Rewarded video impression #$_rewardedImpressions');
            },
            onAdDismissedFullScreenContent: (_) {
              _rewardedAd?.dispose();
              _isRewardedAdReady = false;
              // Preload next rewarded ad
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedAdReady = false;
              debugPrint('❌ Rewarded video ad failed to show: $error');
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          debugPrint('❌ Rewarded video ad failed to load: $error');
          // Retry after delay
          Future.delayed(const Duration(minutes: 2), _loadRewardedAd);
        },
      ),
    );
  }

  /// Show rewarded video ad - highest revenue potential
  Future<bool> showRewardedVideoAd({
    String? context,
    required Function(AdWithoutView ad, RewardItem reward) onUserEarnedReward,
  }) async {
    if (_isRewardedAdReady && _rewardedAd != null) {
      debugPrint('🚀 Showing rewarded video ad - Context: $context');
      
      bool rewardEarned = false;
      _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        onUserEarnedReward(ad, reward);
        debugPrint('💰 User earned reward: ${reward.amount} ${reward.type}');
      });
      
      return rewardEarned;
    } else {
      debugPrint('⏳ Rewarded video ad not ready, loading...');
      _loadRewardedAd();
      return false;
    }
  }

  /// Check if rewarded video ad is available
  bool get isRewardedAdReady => _isRewardedAdReady;

  // 🥇 NATIVE ADS - Highest value, seamless integration
  /// Create native ad - highest revenue potential
  NativeAd createNativeAd({
    required Function(Ad ad) onAdLoaded,
    required Function(Ad ad, LoadAdError error) onAdFailedToLoad,
  }) {
    // Native template styles are Android-only; avoid asserting on iOS
    if (Platform.isAndroid) {
      return NativeAd(
        adUnitId: _nativeAdUnitId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            _nativeImpressions++;
            debugPrint('🎯 Native ad loaded successfully - Impression #$_nativeImpressions');
            onAdLoaded(ad);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Native ad failed to load: $error');
            onAdFailedToLoad(ad, error);
          },
          onAdImpression: (ad) {
            debugPrint('📊 Native ad impression logged');
          },
          onAdClicked: (ad) {
            debugPrint('👆 Native ad clicked');
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.white,
          cornerRadius: 12.0,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: Colors.green.shade600,
            style: NativeTemplateFontStyle.bold,
            size: 14.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.black87,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.black54,
            style: NativeTemplateFontStyle.normal,
            size: 14.0,
          ),
        ),
      );
    } else {
      return NativeAd(
        adUnitId: _nativeAdUnitId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            _nativeImpressions++;
            debugPrint('🎯 Native ad loaded (iOS) - Impression #$_nativeImpressions');
            onAdLoaded(ad);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Native ad failed to load (iOS): $error');
            onAdFailedToLoad(ad, error);
          },
        ),
        request: const AdRequest(),
      );
    }
  }

  /// Get revenue statistics
  Map<String, dynamic> getRevenueStats() {
    return {
      'banner_impressions': _bannerImpressions,
      'interstitial_impressions': _interstitialImpressions,
      'rewarded_impressions': _rewardedImpressions,
      'native_impressions': _nativeImpressions,
      'total_impressions': _bannerImpressions + _interstitialImpressions + _rewardedImpressions + _nativeImpressions,
      'estimated_revenue': _calculateEstimatedRevenue(),
    };
  }

  /// Calculate estimated revenue based on CPM averages
  double _calculateEstimatedRevenue() {
    // Conservative CPM estimates
    const double bannerCPM = 1.5; // $1.50 per 1000 impressions
    const double interstitialCPM = 8.0; // $8.00 per 1000 impressions  
    const double rewardedCPM = 25.0; // $25.00 per 1000 impressions
    const double nativeCPM = 45.0; // $45.00 per 1000 impressions (highest CPM)

    final double bannerRevenue = (_bannerImpressions / 1000) * bannerCPM;
    final double interstitialRevenue = (_interstitialImpressions / 1000) * interstitialCPM;
    final double rewardedRevenue = (_rewardedImpressions / 1000) * rewardedCPM;
    final double nativeRevenue = (_nativeImpressions / 1000) * nativeCPM;

    return bannerRevenue + interstitialRevenue + rewardedRevenue + nativeRevenue;
  }

  /// Dispose of all ads
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

/// 🎯 Strategic Ad Placement Helper
class AdPlacementHelper {
  /// Should show interstitial ad based on user journey
  static bool shouldShowInterstitial({
    required int sessionDuration,
    required int screenChanges,
    required DateTime lastInterstitialShow,
  }) {
    // Don't show if user just opened app (< 30 seconds)
    if (sessionDuration < 30) return false;
    
    // Don't show too frequently (minimum 2 minutes gap)
    if (DateTime.now().difference(lastInterstitialShow).inMinutes < 2) return false;
    
    // Show after user has navigated 3+ times
    return screenChanges >= 3;
  }

  /// Get rewarded video context messages
  static Map<String, String> getRewardedVideoContexts() {
    return {
      'achievement_unlock': '🎯 Watch video to unlock premium achievement details',
      'extra_tips': '💡 Watch video for personalized carbon reduction tips',
      'advanced_stats': '📊 Watch video to access detailed analytics',
      'double_rewards': '⭐ Watch video to double your achievement points',
      'premium_themes': '🎨 Watch video to unlock premium themes',
    };
  }
}