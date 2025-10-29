import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/voice_command_widget.dart';
import 'transport_screen.dart';
import 'energy_screen.dart';
import 'food_screen.dart';
import 'shopping_screen.dart';
import 'add_activity_screen.dart';

class ActivitiesHubScreen extends StatefulWidget {
  const ActivitiesHubScreen({super.key});

  @override
  State<ActivitiesHubScreen> createState() => _ActivitiesHubScreenState();
}

class _ActivitiesHubScreenState extends State<ActivitiesHubScreen> {
  final LanguageService _languageService = LanguageService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions Header
            Text(
              AppLocalizations.of(context)!.translate('ui.quickActions'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Add Button
            _buildQuickActionCard(
              title: AppLocalizations.of(context)!.translate('ui.addActivity'),
              subtitle: AppLocalizations.of(context)!.translate('ui.quickLogAnyActivity'),
              icon: Icons.add_circle,
              color: Colors.green,
              onTap: () async {
                await HapticHelper.trigger(HapticType.selection);
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const AddActivityScreen(),
                  ),
                );
                
                // Eğer aktivite eklendiyse, haptic feedback ver
                if (result == true) {
                  await HapticHelper.trigger(HapticType.success);
                }
              },
            ),
            const SizedBox(height: 24),

            // Categories Header
            Text(
              AppLocalizations.of(context)!.dashboardCategories,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Category Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildCategoryCard(
                  title: AppLocalizations.of(context)!.transportTitle,
                  subtitle: AppLocalizations.of(context)!.transportSubtitle,
                  icon: Icons.directions_car,
                  color: Colors.blue,
                  onTap: () => _navigateToScreen(const TransportScreen()),
                ),
                _buildCategoryCard(
                  title: AppLocalizations.of(context)!.energyTitle,
                  subtitle: AppLocalizations.of(context)!.energySubtitle,
                  icon: Icons.flash_on,
                  color: Colors.orange,
                  onTap: () => _navigateToScreen(const EnergyScreen()),
                ),
                _buildCategoryCard(
                  title: AppLocalizations.of(context)!.navFood,
                  subtitle: AppLocalizations.of(context)!.translate('smartHome.optimizations'),
                  icon: Icons.restaurant,
                  color: Colors.green,
                  onTap: () => _navigateToScreen(const FoodScreen()),
                ),
                _buildCategoryCard(
                  title: AppLocalizations.of(context)!.navShopping,
                  subtitle: AppLocalizations.of(context)!.translate('tips.reduceWaste'),
                  icon: Icons.shopping_bag,
                  color: Colors.purple,
                  onTap: () => _navigateToScreen(const ShoppingScreen()),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Voice Commands Section
            Text(
              AppLocalizations.of(context)!.voiceTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const VoiceCommandWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MicroCard(
      onTap: onTap,
      hapticType: HapticType.light,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MicroCard(
      onTap: onTap,
      hapticType: HapticType.light,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
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
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _navigateToScreen(Widget screen) async {
    await HapticHelper.trigger(HapticType.selection);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}