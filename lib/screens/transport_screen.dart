import 'package:flutter/material.dart';
import '../models/transport_model.dart';
import '../services/database_service.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  TransportType? selectedTransportType;
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  
  double calculatedCO2 = 0.0;
  bool showResult = false;

  @override
  void initState() {
    super.initState();
    distanceController.addListener(_calculateCO2);
  }

  @override
  void dispose() {
    distanceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _calculateCO2() {
    if (selectedTransportType != null && distanceController.text.isNotEmpty) {
      final distance = double.tryParse(distanceController.text);
      if (distance != null && distance > 0) {
        setState(() {
          calculatedCO2 = selectedTransportType!.co2FactorPerKm * distance;
          showResult = true;
        });
      }
    } else {
      setState(() {
        showResult = false;
        calculatedCO2 = 0.0;
      });
    }
  }

  void _selectTransportType(TransportType type) {
    setState(() {
      selectedTransportType = type;
      _calculateCO2();
    });
  }

  void _saveActivity() async {
    if (selectedTransportType == null || distanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen ulaşım türü ve mesafe seçin')),
      );
      return;
    }

    final distance = double.tryParse(distanceController.text);
    if (distance == null || distance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir mesafe girin')),
      );
      return;
    }

    try {
      final activity = TransportActivity.create(
        transportType: selectedTransportType!,
        distanceKm: distance,
        notes: notesController.text.isEmpty ? null : notesController.text,
      );

      // Aktiviteyi veritabanına kaydet
      await DatabaseService.instance.insertTransportActivity(activity);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Ulaşım aktivitesi kaydedildi! ${activity.co2Emission.toStringAsFixed(2)} kg CO₂',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Formu temizle
        setState(() {
          selectedTransportType = null;
          distanceController.clear();
          notesController.clear();
          showResult = false;
          calculatedCO2 = 0.0;
        });

        // Ana sayfaya dön
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true); // true değeri ana sayfayı yenilemek için
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: Aktivite kaydedilemedi. $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚗 Ulaşım'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Text(
              'Ulaşım Türü Seçin',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Ulaşım türü grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: TransportData.transportTypes.length,
              itemBuilder: (context, index) {
                final transportType = TransportData.transportTypes[index];
                final isSelected = selectedTransportType?.id == transportType.id;
                
                return Card(
                  elevation: isSelected ? 8 : 2,
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                  child: InkWell(
                    onTap: () => _selectTransportType(transportType),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            transportType.icon,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            transportType.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected 
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : null,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${transportType.co2FactorPerKm.toStringAsFixed(2)} kg CO₂/km',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected 
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Mesafe girişi
            Text(
              'Mesafe (km)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Örn: 15.5',
                suffixText: 'km',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notlar (opsiyonel)
            Text(
              'Notlar (İsteğe bağlı)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Örn: Evden işe gidiş',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // CO2 hesaplaması sonucu
            if (showResult) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tahmini CO₂ Emisyonu',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            selectedTransportType?.name ?? '',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${calculatedCO2.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'kg CO₂',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: showResult ? _saveActivity : null,
                icon: const Icon(Icons.save),
                label: const Text('Aktiviteyi Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}