import 'package:flutter/material.dart';
import '../screens/transport_screen.dart';
import '../screens/energy_screen.dart';
import '../screens/food_screen.dart';
import '../screens/shopping_screen.dart';
import '../services/language_service.dart';
import '../widgets/micro_interactions.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final LanguageService _languageService = LanguageService.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.isEnglish ? '➕ New Activity' : '➕ Yeni Aktivite',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _languageService.isEnglish 
                                ? 'Add New Activity' 
                                : 'Yeni Aktivite Ekle',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _languageService.isEnglish
                                ? 'Choose a category to start tracking'
                                : 'Takip etmek için bir kategori seçin',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Categories section
              Text(
                _languageService.isEnglish ? 'Categories' : 'Kategoriler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  _buildCategoryTile(
                    context: context,
                    title: _languageService.isEnglish ? 'Transport' : 'Ulaşım',
                    subtitle: _languageService.isEnglish 
                        ? 'Car, metro, walking' 
                        : 'Araç, metro, yürüme',
                    icon: Icons.directions_car,
                    color: Colors.blue,
                    isAvailable: true,
                    onTap: () async {
                      await HapticHelper.trigger(HapticType.selection);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const TransportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: _languageService.isEnglish ? 'Energy' : 'Enerji',
                    subtitle: _languageService.isEnglish 
                        ? 'Electricity, gas' 
                        : 'Elektrik, doğal gaz',
                    icon: Icons.flash_on,
                    color: Colors.orange,
                    isAvailable: true,
                    onTap: () async {
                      await HapticHelper.trigger(HapticType.selection);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const EnergyScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: _languageService.isEnglish ? 'Food' : 'Yemek',
                    subtitle: _languageService.isEnglish 
                        ? 'Nutrition habits' 
                        : 'Beslenme alışkanlıkları',
                    icon: Icons.restaurant,
                    color: Colors.green,
                    isAvailable: true,
                    onTap: () async {
                      await HapticHelper.trigger(HapticType.selection);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FoodScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: _languageService.isEnglish ? 'Shopping' : 'Alışveriş',
                    subtitle: _languageService.isEnglish 
                        ? 'Consumer goods' 
                        : 'Tüketim malları',
                    icon: Icons.shopping_bag,
                    color: Colors.purple,
                    isAvailable: true,
                    onTap: () async {
                      await HapticHelper.trigger(HapticType.selection);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ShoppingScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Quick actions section
              Text(
                _languageService.isEnglish ? 'Quick Actions' : 'Hızlı İşlemler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _languageService.isEnglish ? 'Quick Add' : 'Hızlı Ekle',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _languageService.isEnglish
                          ? 'Common activities for quick logging'
                          : 'Hızlı kayıt için yaygın aktiviteler',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAddChip(
                          context: context,
                          label: _languageService.isEnglish ? '🚗 Car (5 km)' : '🚗 Araba (5 km)',
                          onTap: () => _quickAddTransport(context, 'car_gasoline', 5.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: _languageService.isEnglish ? '🚇 Metro (10 km)' : '🚇 Metro (10 km)',
                          onTap: () => _quickAddTransport(context, 'metro', 10.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: _languageService.isEnglish ? '🚶 Walk (2 km)' : '🚶 Yürüyüş (2 km)',
                          onTap: () => _quickAddTransport(context, 'walking', 2.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: _languageService.isEnglish ? '🚴 Bike (8 km)' : '🚴 Bisiklet (8 km)',
                          onTap: () => _quickAddTransport(context, 'bicycle', 8.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    return MicroCard(
      onTap: onTap,
      hapticType: HapticType.light,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isAvailable) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddChip({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return MicroCard(
      onTap: onTap,
      hapticType: HapticType.light,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🚧 $category ${_languageService.isEnglish ? 'Category' : 'Kategorisi'}'),
        content: Text(
          _languageService.isEnglish
              ? '$category category is under development. Coming soon!\n\nCurrently only Transport and Energy categories are active.'
              : '$category kategorisi henüz geliştirme aşamasında. Yakında kullanıma sunulacak!\n\nŞu anda sadece Ulaşım ve Enerji kategorileri aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'OK' : 'Tamam'),
          ),
        ],
      ),
    );
  }

  void _quickAddTransport(BuildContext context, String transportTypeId, double distance) async {
    await HapticHelper.trigger(HapticType.selection);
    
    // Transport screen'e gidip doğrudan parametrelerle aktivite ekle
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TransportScreen(
          preSelectedTransportType: transportTypeId,
          preSelectedDistance: distance,
          isQuickAdd: true,
        ),
      ),
    );
    
    // Eğer aktivite başarıyla eklendiyse, başarı mesajı göster ve geri dön
    if (result == true) {
      await HapticHelper.trigger(HapticType.success);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService.isEnglish 
                ? '✅ Activity added successfully!'
                : '✅ Aktivite başarıyla eklendi!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Ana sayfaya geri dön
        Navigator.of(context).pop(true);
      }
    }
  }
}