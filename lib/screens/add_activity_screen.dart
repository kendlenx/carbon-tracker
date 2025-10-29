import 'package:flutter/material.dart';
import '../screens/transport_screen.dart';
import '../screens/energy_screen.dart';
import '../screens/food_screen.dart';
import '../screens/shopping_screen.dart';
import '../widgets/micro_interactions.dart';
import '../l10n/app_localizations.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
          '${AppLocalizations.of(context)!.translate('ui.addActivity')}',
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
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
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
                            AppLocalizations.of(context)!.translate('ui.addActivity'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.translate('ui.chooseCategory'),
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
                AppLocalizations.of(context)!.dashboardCategories,
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
                    title: AppLocalizations.of(context)!.navTransport,
                    subtitle: AppLocalizations.of(context)!.transportSubtitle,
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
                    title: AppLocalizations.of(context)!.energyTitle,
                    subtitle: AppLocalizations.of(context)!.energySubtitle,
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
                    title: AppLocalizations.of(context)!.translate('navigation.food'),
                    subtitle: AppLocalizations.of(context)!.translate('food.subtitle'),
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
                    title: AppLocalizations.of(context)!.translate('navigation.shopping'),
                    subtitle: AppLocalizations.of(context)!.translate('shopping.subtitle'),
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
                AppLocalizations.of(context)!.uiQuickActions,
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
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
                          AppLocalizations.of(context)!.translate('ui.quickAdd'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.translate('ui.quickAddCommon'),
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
                          label: '🚗 ${AppLocalizations.of(context)!.transportCar} (5 ${AppLocalizations.of(context)!.transportKm})',
                          onTap: () => _quickAddTransport(context, 'car_gasoline', 5.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚇 ${AppLocalizations.of(context)!.translate('transport.publicTransport')} (10 ${AppLocalizations.of(context)!.transportKm})',
                          onTap: () => _quickAddTransport(context, 'metro', 10.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚶 ${AppLocalizations.of(context)!.transportWalking} (2 ${AppLocalizations.of(context)!.transportKm})',
                          onTap: () => _quickAddTransport(context, 'walking', 2.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚴 ${AppLocalizations.of(context)!.transportCycling} (8 ${AppLocalizations.of(context)!.transportKm})',
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
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
              AppLocalizations.of(context)!.translate('common.success'),
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