import 'package:flutter/material.dart';
import '../models/transport_model.dart';

/// Carbon footprint calculation service for Turkey
class CarbonCalculatorService {
  
  /// Türkiye elektrik şebekesi CO₂ faktörü (kg CO₂/kWh)
  /// Kaynak: TEİAŞ 2023 verileri
  static const double turkeyElectricityFactor = 0.486;

  /// Doğal gaz CO₂ faktörü (kg CO₂/m³)
  static const double naturalGasFactor = 2.0;

  /// Basit CO₂ hesaplama (mevcut sistem)
  static double calculateSimple(TransportType transportType, double distanceKm) {
    return transportType.co2FactorPerKm * distanceKm;
  }

  /// Elektrik tüketimi CO₂ hesaplama
  static double calculateElectricityEmission(double kWh) {
    return kWh * turkeyElectricityFactor;
  }

  /// Doğal gaz CO₂ hesaplama
  static double calculateNaturalGasEmission(double cubicMeters) {
    return cubicMeters * naturalGasFactor;
  }

  /// Yemek kategorisi CO₂ hesaplama (gram CO₂ per gram food)
  static double calculateFoodEmission(String foodType, double grams) {
    const Map<String, double> foodFactors = {
      'beef': 60.0,      // kg CO₂ per kg
      'lamb': 39.0,
      'pork': 12.0,
      'chicken': 9.0,
      'fish': 6.0,
      'cheese': 13.5,
      'eggs': 4.2,
      'rice': 2.7,
      'vegetables': 2.0,
      'fruits': 1.1,
    };

    final factor = foodFactors[foodType] ?? 2.0;
    return (factor * grams) / 1000; // Convert to kg CO₂
  }

  /// Karbon ayak izi karşılaştırması
  static CarbonComparison compareWithAverage(double userWeeklyCO2) {
    // Türkiye ortalaması (tahmini)
    const double turkeyWeeklyAverage = 35.0; // kg CO₂/hafta
    const double worldWeeklyAverage = 30.0;   // kg CO₂/hafta
    const double parisAgreementTarget = 20.0; // kg CO₂/hafta (2030 hedefi)

    return CarbonComparison(
      userValue: userWeeklyCO2,
      turkeyAverage: turkeyWeeklyAverage,
      worldAverage: worldWeeklyAverage,
      parisTarget: parisAgreementTarget,
      performanceLevel: _getPerformanceLevel(userWeeklyCO2, parisAgreementTarget),
    );
  }

  static PerformanceLevel _getPerformanceLevel(double userCO2, double target) {
    final ratio = userCO2 / target;
    
    if (ratio <= 0.8) return PerformanceLevel.excellent;
    if (ratio <= 1.0) return PerformanceLevel.good;
    if (ratio <= 1.5) return PerformanceLevel.average;
    if (ratio <= 2.0) return PerformanceLevel.poor;
    return PerformanceLevel.critical;
  }

  /// Hedef belirleme algoritması
  static CarbonTarget calculatePersonalTarget({
    required double currentWeeklyAverage,
    required TargetType targetType,
  }) {
    double reductionPercentage;
    String description;
    Duration timeframe;

    switch (targetType) {
      case TargetType.conservative:
        reductionPercentage = 0.1; // 10% azaltma
        description = 'Muhafazakar hedef - %10 azaltma';
        timeframe = const Duration(days: 30);
        break;
      case TargetType.moderate:
        reductionPercentage = 0.2; // 20% azaltma
        description = 'Orta düzey hedef - %20 azaltma';
        timeframe = const Duration(days: 60);
        break;
      case TargetType.ambitious:
        reductionPercentage = 0.3; // 30% azaltma
        description = 'Iddialı hedef - %30 azaltma';
        timeframe = const Duration(days: 90);
        break;
    }

    final targetWeekly = currentWeeklyAverage * (1 - reductionPercentage);
    final targetMonthly = targetWeekly * 4.33; // Ortalama ay = 4.33 hafta

    return CarbonTarget(
      weeklyTarget: targetWeekly,
      monthlyTarget: targetMonthly,
      reductionPercentage: reductionPercentage,
      description: description,
      timeframe: timeframe,
      createdAt: DateTime.now(),
    );
  }

  /// CO₂ tasarrufu önerileri
  static List<CarbonSavingTip> generateTips(double transportEmission) {
    final tips = <CarbonSavingTip>[];
    
    if (transportEmission > 50) {
      tips.add(CarbonSavingTip(
        category: 'Ulaşım',
        tip: 'Mümkün olduğunda toplu taşıma kullanmayı tercih edin.',
        potentialSaving: transportEmission * 0.6,
        difficulty: DifficultyLevel.easy,
      ));
    }
    
    if (transportEmission > 30) {
      tips.add(CarbonSavingTip(
        category: 'Ulaşım',
        tip: 'Kısa mesafeler için bisiklet veya yürüyüş yapın.',
        potentialSaving: transportEmission * 0.2,
        difficulty: DifficultyLevel.easy,
      ));
    }

    if (transportEmission > 40) {
      tips.add(CarbonSavingTip(
        category: 'Ulaşım',
        tip: 'Araç paylaşımını (car sharing) düşünün.',
        potentialSaving: transportEmission * 0.5,
        difficulty: DifficultyLevel.medium,
      ));
    }

    tips.add(CarbonSavingTip(
      category: 'Genel',
      tip: 'LED ampuller kullanarak enerji tasarrufu yapın.',
      potentialSaving: 2.5,
      difficulty: DifficultyLevel.easy,
    ));

    return tips;
  }
}

/// Hedef türleri
enum TargetType {
  conservative,
  moderate,
  ambitious,
}

/// Performans seviyesi
enum PerformanceLevel {
  excellent,
  good,
  average,
  poor,
  critical,
}

/// Zorluk seviyesi
enum DifficultyLevel {
  easy,
  medium,
  hard,
}

/// Karbon hedefi sınıfı
class CarbonTarget {
  final double weeklyTarget;
  final double monthlyTarget;
  final double reductionPercentage;
  final String description;
  final Duration timeframe;
  final DateTime createdAt;

  CarbonTarget({
    required this.weeklyTarget,
    required this.monthlyTarget,
    required this.reductionPercentage,
    required this.description,
    required this.timeframe,
    required this.createdAt,
  });
}

/// Karbon karşılaştırması sınıfı
class CarbonComparison {
  final double userValue;
  final double turkeyAverage;
  final double worldAverage;
  final double parisTarget;
  final PerformanceLevel performanceLevel;

  CarbonComparison({
    required this.userValue,
    required this.turkeyAverage,
    required this.worldAverage,
    required this.parisTarget,
    required this.performanceLevel,
  });

  String get performanceText {
    switch (performanceLevel) {
      case PerformanceLevel.excellent:
        return 'Mükemmel 🌟';
      case PerformanceLevel.good:
        return 'İyi 👍';
      case PerformanceLevel.average:
        return 'Ortalama 😐';
      case PerformanceLevel.poor:
        return 'Kötü 😟';
      case PerformanceLevel.critical:
        return 'Kritik ⚠️';
    }
  }

  Color get performanceColor {
    switch (performanceLevel) {
      case PerformanceLevel.excellent:
        return const Color(0xFF4CAF50); // Green
      case PerformanceLevel.good:
        return const Color(0xFF8BC34A); // Light Green
      case PerformanceLevel.average:
        return const Color(0xFFFF9800); // Orange
      case PerformanceLevel.poor:
        return const Color(0xFFFF5722); // Deep Orange
      case PerformanceLevel.critical:
        return const Color(0xFFF44336); // Red
    }
  }
}

/// Tasarruf önerisi sınıfı
class CarbonSavingTip {
  final String category;
  final String tip;
  final double potentialSaving;
  final DifficultyLevel difficulty;

  CarbonSavingTip({
    required this.category,
    required this.tip,
    required this.potentialSaving,
    required this.difficulty,
  });

  String get difficultyText {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return 'Kolay 😊';
      case DifficultyLevel.medium:
        return 'Orta 🤔';
      case DifficultyLevel.hard:
        return 'Zor 😤';
    }
  }

  Color get difficultyColor {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.medium:
        return const Color(0xFFFF9800);
      case DifficultyLevel.hard:
        return const Color(0xFFF44336);
    }
  }
}

