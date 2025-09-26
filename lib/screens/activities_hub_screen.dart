import 'package:flutter/material.dart';
import '../services/language_service.dart';
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
        title: Text(_languageService.isEnglish ? 'Activities' : 'Aktiviteler'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions Header
            Text(
              _languageService.isEnglish ? 'Quick Actions' : 'Hızlı İşlemler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Add Button
            _buildQuickActionCard(
              title: _languageService.isEnglish ? 'Add Activity' : 'Aktivite Ekle',
              subtitle: _languageService.isEnglish 
                  ? 'Quickly log any activity' 
                  : 'Herhangi bir aktiviteyi hızlıca kaydet',
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
              _languageService.isEnglish ? 'Categories' : 'Kategoriler',
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
                  title: _languageService.isEnglish ? 'Transport' : 'Ulaşım',
                  subtitle: _languageService.isEnglish 
                      ? 'Car, metro, walking' 
                      : 'Araç, metro, yürüme',
                  icon: Icons.directions_car,
                  color: Colors.blue,
                  onTap: () => _navigateToScreen(const TransportScreen()),
                ),
                _buildCategoryCard(
                  title: _languageService.isEnglish ? 'Energy' : 'Enerji',
                  subtitle: _languageService.isEnglish 
                      ? 'Electricity, gas' 
                      : 'Elektrik, doğal gaz',
                  icon: Icons.flash_on,
                  color: Colors.orange,
                  onTap: () => _navigateToScreen(const EnergyScreen()),
                ),
                _buildCategoryCard(
                  title: _languageService.isEnglish ? 'Food' : 'Yemek',
                  subtitle: _languageService.isEnglish 
                      ? 'Nutrition habits' 
                      : 'Beslenme alışkanlıkları',
                  icon: Icons.restaurant,
                  color: Colors.green,
                  onTap: () => _navigateToScreen(const FoodScreen()),
                ),
                _buildCategoryCard(
                  title: _languageService.isEnglish ? 'Shopping' : 'Alışveriş',
                  subtitle: _languageService.isEnglish 
                      ? 'Consumer goods' 
                      : 'Tüketim malları',
                  icon: Icons.shopping_bag,
                  color: Colors.purple,
                  onTap: () => _navigateToScreen(const ShoppingScreen()),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Voice Commands Section
            Text(
              _languageService.isEnglish ? 'Voice Commands' : 'Sesli Komutlar',
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
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
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