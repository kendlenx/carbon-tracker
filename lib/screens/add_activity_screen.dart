import 'package:flutter/material.dart';
import '../screens/transport_screen.dart';

class AddActivityScreen extends StatelessWidget {
  const AddActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('➕ Yeni Aktivite'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hangi kategoride aktivite eklemek istiyorsunuz?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildCategoryTile(
                    context: context,
                    title: 'Ulaşım',
                    subtitle: 'Araç, metro, yürüme',
                    icon: Icons.directions_car,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const TransportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: 'Enerji',
                    subtitle: 'Elektrik, doğal gaz',
                    icon: Icons.flash_on,
                    color: Colors.orange,
                    onTap: () {
                      _showComingSoon(context, 'Enerji');
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: 'Yemek',
                    subtitle: 'Beslenme alışkanlıkları',
                    icon: Icons.restaurant,
                    color: Colors.green,
                    onTap: () {
                      _showComingSoon(context, 'Yemek');
                    },
                  ),
                  _buildCategoryTile(
                    context: context,
                    title: 'Alışveriş',
                    subtitle: 'Tüketim malları',
                    icon: Icons.shopping_bag,
                    color: Colors.purple,
                    onTap: () {
                      _showComingSoon(context, 'Alışveriş');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Hızlı ekleme seçenekleri
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ Hızlı Ekleme',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAddChip(
                          context: context,
                          label: '🚗 Araba (5 km)',
                          onTap: () => _quickAddTransport(context, 'car_gasoline', 5.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚇 Metro (10 km)',
                          onTap: () => _quickAddTransport(context, 'metro', 10.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚶 Yürüyüş (2 km)',
                          onTap: () => _quickAddTransport(context, 'walking', 2.0),
                        ),
                        _buildQuickAddChip(
                          context: context,
                          label: '🚴 Bisiklet (8 km)',
                          onTap: () => _quickAddTransport(context, 'bicycle', 8.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddChip({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      elevation: 2,
    );
  }

  void _showComingSoon(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🚧 $category Kategorisi'),
        content: Text(
          '$category kategorisi henüz geliştirme aşamasında. Yakında kullanıma sunulacak!\\n\\nŞu anda sadece Ulaşım kategorisi aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _quickAddTransport(BuildContext context, String transportTypeId, double distance) async {
    // Import gerekli olduğu için burada sadece mesaj gösterelim
    // Gerçek implementasyon için DatabaseService'i import etmemiz lazım
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚡ Hızlı Ekleme'),
        content: Text(
          'Hızlı ekleme özelliği yakında aktif olacak!\\n\\nŞimdilik kategori sayfalarından aktivite ekleyebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}