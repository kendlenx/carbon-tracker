import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 💎 Premium Subscription Service
/// 
/// Revenue Strategy: $2.99/month, $19.99/year
/// Premium Features: Ad-free experience, advanced analytics, unlimited goals
class PremiumService {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  static PremiumService get instance => _instance;

  static const String _premiumKey = 'is_premium_user';
  static const String _premiumExpiryKey = 'premium_expiry_date';

  // Premium subscription prices
  static const double monthlyPrice = 2.99;
  static const double yearlyPrice = 19.99;

  bool _isPremium = false;
  DateTime? _premiumExpiry;

  /// Check if user has premium subscription
  bool get isPremium => _isPremium && (_premiumExpiry?.isAfter(DateTime.now()) ?? false);

  /// Get premium expiry date
  DateTime? get premiumExpiry => _premiumExpiry;

  /// Initialize premium service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    
    final expiryTimestamp = prefs.getInt(_premiumExpiryKey);
    if (expiryTimestamp != null) {
      _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
    }

    debugPrint('💎 Premium Service initialized - Premium: $isPremium');
  }

  /// Purchase premium subscription
  Future<bool> purchasePremium({required PremiumPlan plan}) async {
    try {
      // Simulate purchase flow (integrate with Google Play Billing later)
      final success = await _simulatePurchase(plan);
      
      if (success) {
        await _activatePremium(plan);
        debugPrint('💎 Premium subscription activated: ${plan.name}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Premium purchase failed: $e');
      return false;
    }
  }

  /// Activate premium subscription
  Future<void> _activatePremium(PremiumPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    
    _isPremium = true;
    _premiumExpiry = DateTime.now().add(plan.duration);
    
    await prefs.setBool(_premiumKey, true);
    await prefs.setInt(_premiumExpiryKey, _premiumExpiry!.millisecondsSinceEpoch);
  }

  /// Simulate purchase (replace with actual billing integration)
  Future<bool> _simulatePurchase(PremiumPlan plan) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // For testing, always return success
    // In production, integrate with Google Play Billing
    return true;
  }

  /// Restore premium subscription
  Future<bool> restorePurchases() async {
    try {
      // Integrate with Google Play Billing to restore purchases
      // For now, just check if premium was previously purchased
      final prefs = await SharedPreferences.getInstance();
      final wasPremium = prefs.getBool(_premiumKey) ?? false;
      
      if (wasPremium && _premiumExpiry?.isAfter(DateTime.now()) == true) {
        debugPrint('💎 Premium subscription restored');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Failed to restore purchases: $e');
      return false;
    }
  }

  /// Check premium features access
  bool hasFeature(PremiumFeature feature) {
    if (!isPremium) return false;
    
    switch (feature) {
      case PremiumFeature.adFree:
      case PremiumFeature.advancedAnalytics:
      case PremiumFeature.unlimitedGoals:
      case PremiumFeature.exportData:
      case PremiumFeature.prioritySupport:
        return true;
    }
  }

  /// Get premium features list
  List<String> get premiumFeatures => [
    '🚫 Ad-free experience',
    '📊 Advanced analytics & insights',
    '🎯 Unlimited carbon goals',
    '📤 Export your data (PDF, CSV)',
    '🎨 Premium themes & customization',
    '💬 Priority customer support',
    '🔄 Real-time data sync',
    '🏆 Exclusive achievements',
  ];

  /// Get subscription plans
  List<PremiumPlan> get subscriptionPlans => [
    PremiumPlan.monthly,
    PremiumPlan.yearly,
  ];

  /// Cancel premium subscription
  Future<void> cancelSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    
    _isPremium = false;
    _premiumExpiry = null;
    
    await prefs.setBool(_premiumKey, false);
    await prefs.remove(_premiumExpiryKey);
    
    debugPrint('💎 Premium subscription cancelled');
  }
}

/// Premium subscription plans
class PremiumPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final Duration duration;
  final String displayPrice;
  final double savings;

  const PremiumPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.displayPrice,
    this.savings = 0,
  });

  static const monthly = PremiumPlan(
    id: 'premium_monthly',
    name: 'Monthly Premium',
    description: 'All premium features for 1 month',
    price: 2.99,
    duration: Duration(days: 30),
    displayPrice: '\$2.99/month',
  );

  static const yearly = PremiumPlan(
    id: 'premium_yearly',
    name: 'Yearly Premium',
    description: 'All premium features for 1 year (Save 44%!)',
    price: 19.99,
    duration: Duration(days: 365),
    displayPrice: '\$19.99/year',
    savings: 44,
  );
}

/// Premium features enum
enum PremiumFeature {
  adFree,
  advancedAnalytics,
  unlimitedGoals,
  exportData,
  prioritySupport,
}