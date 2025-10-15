import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// 💰 Banner Ad Widget - Consistent Revenue Stream
/// 
/// CPM: $0.50-3.00 (Low but consistent)
/// Placement: Bottom of main screen for maximum visibility
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // Load banner ad through AdMobService
    AdMobService.instance.loadBannerAd();
    
    // Wait a moment for the ad to load, then check again
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _bannerAd = AdMobService.instance.bannerAd;
          _isAdLoaded = _bannerAd != null;
        });
      }
    });
  }

  @override
  void dispose() {
    // Don't dispose here - AdMobService manages lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container if ad not loaded
    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        width: double.infinity,
        height: 60,
        color: Colors.grey.shade100,
        child: const Center(
          child: Text(
            '📱 Banner Reklam Yükleniyor...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Small "Ad" label for transparency
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ad',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Banner ad container
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🎯 Smart Banner Ad Widget with Auto-Refresh
/// Enhanced version with better revenue optimization
class SmartBannerAdWidget extends StatefulWidget {
  final String placement;
  
  const SmartBannerAdWidget({
    super.key,
    this.placement = 'main_screen',
  });

  @override
  State<SmartBannerAdWidget> createState() => _SmartBannerAdWidgetState();
}

class _SmartBannerAdWidgetState extends State<SmartBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _setupAutoRefresh();
  }

  void _loadBannerAd() {
    AdMobService.instance.loadBannerAd();
    
    setState(() {
      _bannerAd = AdMobService.instance.bannerAd;
      _isAdLoaded = _bannerAd != null;
    });
  }

  void _setupAutoRefresh() {
    // Refresh banner ad every 60 seconds for better fill rate
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        _loadBannerAd();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // Revenue optimization indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 10,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Supporting Carbon Tracker',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ad',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Banner ad container with better styling
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}