import 'package:flutter/material.dart';
import '../services/carbon_calculator_service.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final LanguageService _languageService = LanguageService.instance;
  
  // Elektrik formu
  final TextEditingController _electricityController = TextEditingController();
  final TextEditingController _electricityNotesController = TextEditingController();
  double _electricityEmission = 0.0;
  
  // Doğal gaz formu
  final TextEditingController _gasController = TextEditingController();
  final TextEditingController _gasNotesController = TextEditingController();
  double _gasEmission = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _electricityController.addListener(_calculateElectricityEmission);
    _gasController.addListener(_calculateGasEmission);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _electricityController.dispose();
    _electricityNotesController.dispose();
    _gasController.dispose();
    _gasNotesController.dispose();
    super.dispose();
  }

  void _calculateElectricityEmission() {
    final kWh = double.tryParse(_electricityController.text);
    if (kWh != null && kWh > 0) {
      setState(() {
        _electricityEmission = CarbonCalculatorService.calculateElectricityEmission(kWh);
      });
    } else {
      setState(() {
        _electricityEmission = 0.0;
      });
    }
  }

  void _calculateGasEmission() {
    final cubicMeters = double.tryParse(_gasController.text);
    if (cubicMeters != null && cubicMeters > 0) {
      setState(() {
        _gasEmission = CarbonCalculatorService.calculateNaturalGasEmission(cubicMeters);
      });
    } else {
      setState(() {
        _gasEmission = 0.0;
      });
    }
  }

  Future<void> _saveElectricity() async {
    if (_electricityController.text.isEmpty || _electricityEmission <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageService.isEnglish ? 'Please enter a valid kWh value' : 'Lütfen geçerli bir kWh değeri girin')),
      );
      return;
    }

    try {
      await DatabaseService.instance.insertActivity({
        'category': 'energy',
        'subcategory': 'electricity',
        'description': '${_electricityController.text} kWh ${_languageService.isEnglish ? 'electricity consumption' : 'elektrik tüketimi'}',
        'co2_amount': _electricityEmission,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'kwh': double.parse(_electricityController.text),
          'notes': _electricityNotesController.text,
          'co2_factor': 0.486,
        }
      });
      
      _showSuccessMessage(_languageService.isEnglish ? 'Electricity' : 'Elektrik', _electricityEmission);
      _clearElectricityForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageService.isEnglish ? 'Error saving electricity data' : 'Elektrik verisi kaydedilirken hata oluştu')),
      );
    }
  }

  Future<void> _saveGas() async {
    if (_gasController.text.isEmpty || _gasEmission <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageService.isEnglish ? 'Please enter a valid m³ value' : 'Lütfen geçerli bir m³ değeri girin')),
      );
      return;
    }

    try {
      await DatabaseService.instance.insertActivity({
        'category': 'energy',
        'subcategory': 'natural_gas',
        'description': '${_gasController.text} m³ ${_languageService.isEnglish ? 'natural gas consumption' : 'doğal gaz tüketimi'}',
        'co2_amount': _gasEmission,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'cubic_meters': double.parse(_gasController.text),
          'notes': _gasNotesController.text,
          'co2_factor': 2.0,
        }
      });
      
      _showSuccessMessage(_languageService.isEnglish ? 'Natural Gas' : 'Doğal Gaz', _gasEmission);
      _clearGasForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageService.isEnglish ? 'Error saving gas data' : 'Gaz verisi kaydedilirken hata oluştu')),
      );
    }
  }

  void _showSuccessMessage(String type, double emission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ $type tüketimi kaydedildi! ${emission.toStringAsFixed(2)} kg CO₂',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _clearElectricityForm() {
    setState(() {
      _electricityController.clear();
      _electricityNotesController.clear();
      _electricityEmission = 0.0;
    });
  }

  void _clearGasForm() {
    setState(() {
      _gasController.clear();
      _gasNotesController.clear();
      _gasEmission = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ Enerji Tüketimi'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.flash_on),
              text: 'Elektrik',
            ),
            Tab(
              icon: Icon(Icons.local_fire_department),
              text: 'Doğal Gaz',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildElectricityTab(),
          _buildGasTab(),
        ],
      ),
    );
  }

  Widget _buildElectricityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Elektrik Tüketimi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Türkiye elektrik şebekesi CO₂ faktörü: 0.486 kg CO₂/kWh',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Elektrik Tüketimi (kWh)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _electricityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Örn: 150',
              suffixText: 'kWh',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.flash_on),
              helperText: 'Fatura üzerindeki aylık tüketim miktarı',
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Notlar (İsteğe bağlı)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _electricityNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Örn: Ekim ayı faturası',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),

          const SizedBox(height: 24),

          if (_electricityEmission > 0) ...[
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
                          '${_electricityController.text} kWh elektrik',
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
                          _electricityEmission.toStringAsFixed(2),
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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _electricityEmission > 0 ? _saveElectricity : null,
              icon: const Icon(Icons.save),
              label: const Text('Elektrik Tüketimini Kaydet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Doğal Gaz Tüketimi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Doğal gaz CO₂ faktörü: 2.0 kg CO₂/m³',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Doğal Gaz Tüketimi (m³)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gasController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Örn: 75',
              suffixText: 'm³',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.local_fire_department),
              helperText: 'Fatura üzerindeki aylık tüketim miktarı',
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Notlar (İsteğe bağlı)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gasNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Örn: Kış ayı ısıtma',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),

          const SizedBox(height: 24),

          if (_gasEmission > 0) ...[
            Card(
              color: Colors.orange.shade100,
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
                          '${_gasController.text} m³ doğal gaz',
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
                          _gasEmission.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _gasEmission > 0 ? _saveGas : null,
              icon: const Icon(Icons.save),
              label: const Text('Doğal Gaz Tüketimini Kaydet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}