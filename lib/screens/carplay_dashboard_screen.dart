import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/carplay_service.dart';
import '../services/carplay_siri_service.dart';
import '../services/language_service.dart';
import '../services/database_service.dart';

/// CarPlay Dashboard Screen - Main interface for CarPlay
class CarPlayDashboardScreen extends StatefulWidget {
  const CarPlayDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CarPlayDashboardScreen> createState() => _CarPlayDashboardScreenState();
}

class _CarPlayDashboardScreenState extends State<CarPlayDashboardScreen>
    with TickerProviderStateMixin {
  final CarPlayService _carPlayService = CarPlayService.instance;
  final CarPlaySiriService _siriService = CarPlaySiriService.instance;
  final LanguageService _languageService = LanguageService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = true;
  String? _error;
  double _todayCO2 = 0.0;
  int _todayActivities = 0;
  double _todayDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _setupListeners();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  void _setupListeners() {
    _carPlayService.addListener(_onCarPlayStateChanged);
  }

  void _onCarPlayStateChanged() {
    if (mounted) {
      setState(() {});
      _siriService.setupContextualShortcuts();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final activities = await _databaseService.getActivitiesInDateRange(
        startOfDay,
        today.add(const Duration(days: 1)),
      );

      final co2 = activities.fold<double>(
        0.0,
        (sum, activity) => sum + activity.co2EmissionKg,
      );

      final distance = activities.fold<double>(
        0.0,
        (sum, activity) => sum + activity.distanceKm,
      );

      setState(() {
        _todayCO2 = co2;
        _todayActivities = activities.length;
        _todayDistance = distance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _carPlayService.removeListener(_onCarPlayStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = _languageService.isEnglish;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.eco,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isEnglish ? 'Carbon Tracker' : 'Karbon Takipçisi',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _carPlayService.isTripActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _carPlayService.isTripActive ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _carPlayService.isTripActive 
                        ? (isEnglish ? 'LIVE' : 'CANLI')
                        : (isEnglish ? 'IDLE' : 'BEKLEMEDE'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(isEnglish)
          : _error != null
              ? _buildErrorView(isEnglish)
              : _buildMainContent(isEnglish),
    );
  }

  Widget _buildLoadingView(bool isEnglish) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 16),
          Text(
            isEnglish ? 'Loading your data...' : 'Verileriniz yükleniyor...',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isEnglish) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            isEnglish ? 'Failed to load data' : 'Veri yüklenemedi',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isEnglish ? 'Retry' : 'Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isEnglish) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(isEnglish),
          const SizedBox(height: 24),
          _buildTripControls(isEnglish),
          const SizedBox(height: 24),
          _buildQuickActions(isEnglish),
          const SizedBox(height: 24),
          _buildCurrentTripInfo(isEnglish),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isEnglish) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.co2,
            title: isEnglish ? 'Today CO₂' : 'Bugün CO₂',
            value: '${_todayCO2.toStringAsFixed(1)} kg',
            color: _getCO2Color(_todayCO2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.route,
            title: isEnglish ? 'Distance' : 'Mesafe',
            value: '${_todayDistance.toStringAsFixed(1)} km',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.list,
            title: isEnglish ? 'Trips' : 'Seyahat',
            value: _todayActivities.toString(),
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCO2Color(double co2) {
    if (co2 < 5.0) return Colors.green;
    if (co2 < 15.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTripControls(bool isEnglish) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: _carPlayService.isTripActive ? Icons.stop : Icons.play_arrow,
            title: _carPlayService.isTripActive 
                ? (isEnglish ? 'End Trip' : 'Seyahat Bitir')
                : (isEnglish ? 'Start Trip' : 'Seyahat Başlat'),
            color: _carPlayService.isTripActive ? Colors.red : Colors.green,
            onTap: _carPlayService.isTripActive ? _endTrip : _startTrip,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.add,
            title: isEnglish ? 'Add Trip' : 'Seyahat Ekle',
            color: Colors.blue,
            onTap: _showAddTripDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEnglish ? 'Voice Commands' : 'Ses Komutları',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildVoiceCommandChip(
              isEnglish ? '"Start trip"' : '"Seyahat başlat"',
              Icons.play_arrow,
            ),
            _buildVoiceCommandChip(
              isEnglish ? '"Check CO₂"' : '"CO₂ kontrol et"',
              Icons.eco,
            ),
            _buildVoiceCommandChip(
              isEnglish ? '"Quick status"' : '"Hızlı durum"',
              Icons.info,
            ),
            _buildVoiceCommandChip(
              isEnglish ? '"Eco route"' : '"Çevreci rota"',
              Icons.map,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceCommandChip(String command, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            command,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTripInfo(bool isEnglish) {
    if (!_carPlayService.isTripActive) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEnglish 
                    ? 'No active trip. Use voice commands or buttons to start tracking.'
                    : 'Aktif seyahat yok. Takip başlatmak için ses komutlarını veya butonları kullanın.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final distance = _carPlayService.currentTripDistance;
    final duration = _carPlayService.currentTripDuration;
    final estimatedCO2 = distance * 0.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[900]?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: const Icon(
                      Icons.radio_button_checked,
                      color: Colors.red,
                      size: 16,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'Current Trip' : 'Mevcut Seyahat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTripStat(
                isEnglish ? 'Distance' : 'Mesafe',
                '${distance.toStringAsFixed(1)} km',
                Icons.route,
              ),
              const SizedBox(width: 24),
              _buildTripStat(
                isEnglish ? 'Time' : 'Süre',
                '$duration ${isEnglish ? 'min' : 'dk'}',
                Icons.access_time,
              ),
              const SizedBox(width: 24),
              _buildTripStat(
                'CO₂',
                '${estimatedCO2.toStringAsFixed(1)} kg',
                Icons.co2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTrip() async {
    try {
      await _carPlayService.startTrip();
      HapticFeedback.lightImpact();
      _siriService.setupContextualShortcuts();
    } catch (e) {
      _showErrorSnackBar('Failed to start trip: $e');
    }
  }

  Future<void> _endTrip() async {
    try {
      await _carPlayService.endTrip();
      HapticFeedback.lightImpact();
      _siriService.setupContextualShortcuts();
      await _loadData(); // Refresh stats
    } catch (e) {
      _showErrorSnackBar('Failed to end trip: $e');
    }
  }

  void _showAddTripDialog() {
    final isEnglish = _languageService.isEnglish;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          isEnglish ? 'Voice Command' : 'Ses Komutu',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isEnglish 
              ? 'Say "Add a [distance] kilometer trip" to add a manual trip via voice command.'
              : 'Manuel seyahat eklemek için "10 kilometrelik bir seyahat ekle" gibi söyleyin.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isEnglish ? 'OK' : 'Tamam',
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}