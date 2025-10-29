import 'package:flutter/material.dart';
import '../services/carbon_calculator_service.dart';
import '../services/database_service.dart';
import '../l10n/app_localizations.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  
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
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('energy.validation.enterValidKwh'))),
      );
      return;
    }

    try {
      await DatabaseService.instance.insertActivity({
        'category': 'energy',
        'subcategory': 'electricity',
        'description': '${_electricityController.text} kWh ${AppLocalizations.of(context)!.translate('energy.electricityConsumption')}',
        'co2_amount': _electricityEmission,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'kwh': double.parse(_electricityController.text),
          'notes': _electricityNotesController.text,
          'co2_factor': 0.486,
        }
      });
      
      _showSuccessMessage(AppLocalizations.of(context)!.energyElectricity, _electricityEmission);
      _clearElectricityForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('energy.errors.saveElectricity'))),
      );
    }
  }

  Future<void> _saveGas() async {
    if (_gasController.text.isEmpty || _gasEmission <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('energy.validation.enterValidM3'))),
      );
      return;
    }

    try {
      await DatabaseService.instance.insertActivity({
        'category': 'energy',
        'subcategory': 'natural_gas',
        'description': '${_gasController.text} m³ ${AppLocalizations.of(context)!.translate('energy.naturalGasConsumption')}',
        'co2_amount': _gasEmission,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'cubic_meters': double.parse(_gasController.text),
          'notes': _gasNotesController.text,
          'co2_factor': 2.0,
        }
      });
      
      _showSuccessMessage(AppLocalizations.of(context)!.energyNaturalGas, _gasEmission);
      _clearGasForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('energy.errors.saveGas'))),
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
        title: Text('⚡ ${AppLocalizations.of(context)!.energyTitle}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.flash_on),
              text: AppLocalizations.of(context)!.energyElectricity,
            ),
            Tab(
              icon: const Icon(Icons.local_fire_department),
              text: AppLocalizations.of(context)!.energyNaturalGas,
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
                        AppLocalizations.of(context)!.translate('energy.electricitySectionTitle'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.translate('energy.co2FactorElectricity'),
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
            AppLocalizations.of(context)!.translate('energy.input.electricityKwh'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _electricityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '150',
              suffixText: AppLocalizations.of(context)!.energyKwh,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.flash_on),
              helperText: AppLocalizations.of(context)!.translate('energy.hints.monthlyBillUsage'),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context)!.translate('common.notesOptional'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _electricityNotesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.translate('common.notesOptional'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note),
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
                          AppLocalizations.of(context)!.translate('energy.estimatedEmission'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_electricityController.text} ${AppLocalizations.of(context)!.energyKwh} ${AppLocalizations.of(context)!.energyElectricity.toLowerCase()}',
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
              label: Text(AppLocalizations.of(context)!.translate('energy.saveElectricity')),
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
                        AppLocalizations.of(context)!.translate('energy.naturalGasSectionTitle'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.translate('energy.co2FactorGas'),
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
            AppLocalizations.of(context)!.translate('energy.input.gasM3'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gasController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '75',
              suffixText: AppLocalizations.of(context)!.energyM3,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.local_fire_department),
              helperText: AppLocalizations.of(context)!.translate('energy.hints.monthlyBillUsage'),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context)!.translate('common.notesOptional'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gasNotesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.translate('energy.hints.gasNoteExample'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note),
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
                          AppLocalizations.of(context)!.translate('energy.estimatedEmission'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_gasController.text} ${AppLocalizations.of(context)!.energyM3} ${AppLocalizations.of(context)!.energyNaturalGas.toLowerCase()}',
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
              label: Text(AppLocalizations.of(context)!.translate('energy.saveGas')),
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