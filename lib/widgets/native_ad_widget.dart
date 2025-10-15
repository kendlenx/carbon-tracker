import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// 🥇 Native Ad Widget - Highest Revenue Strategy
/// 
/// CPM: $15-80 (Highest revenue potential)
/// Integration: Seamlessly blends with app content
/// Best placement: In content streams, lists, feeds
class NativeAdWidget extends StatefulWidget {
  final String placement;
  final double? width;
  final double? height;
  
  const NativeAdWidget({
    super.key,
    this.placement = 'content_stream',
    this.width,
    this.height,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = AdMobService.instance.createNativeAd(
      onAdLoaded: (ad) {
        setState(() {
          _isAdLoaded = true;
        });
        debugPrint('🎯 Native ad loaded successfully - Placement: ${widget.placement}');
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        setState(() {
          _isAdLoaded = false;
        });
        debugPrint('❌ Native ad failed to load: $error');
      },
    );
    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 120,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            '📱 Native Reklam Yükleniyor...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 120,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            AdWidget(ad: _nativeAd!),
            // Revenue optimization badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎯 Native Ad List Item - For ListView integration
class NativeAdListItem extends StatelessWidget {
  final String placement;
  
  const NativeAdListItem({
    super.key,
    this.placement = 'list_item',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: NativeAdWidget(
        placement: placement,
        height: 100,
      ),
    );
  }
}