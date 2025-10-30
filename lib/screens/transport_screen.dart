import 'package:flutter/material.dart';
import '../services/widget_data_provider.dart';
import '../models/transport_activity.dart';
import '../services/database_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/micro_interactions.dart';

class TransportScreen extends StatefulWidget {
  final String? preSelectedTransportType;
  final double? preSelectedDistance;
  final bool isQuickAdd;
  
  const TransportScreen({
    super.key,
    this.preSelectedTransportType,
    this.preSelectedDistance,
    this.isQuickAdd = false,
  });

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> with TickerProviderStateMixin {
  TransportType? selectedTransportType;
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  
  late AnimationController _animationController;
  late AnimationController _resultAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  double calculatedCO2 = 0.0;
  bool showResult = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    distanceController.addListener(_calculateCO2);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _resultAnimationController, curve: Curves.easeOutBack),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _resultAnimationController, curve: Curves.easeOutBack),
    );
    
    // Set pre-selected values for quick add
    if (widget.isQuickAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.preSelectedTransportType != null) {
          // Find the transport type by name
          try {
            final transportType = TransportType.values.firstWhere(
              (type) => type.name == widget.preSelectedTransportType,
            );
            _selectTransportType(transportType);
          } catch (e) {
            // Transport type not found, ignore
          }
        }
        
        if (widget.preSelectedDistance != null) {
          distanceController.text = widget.preSelectedDistance!.toStringAsFixed(1);
          _calculateCO2();
        }
        
        // Auto-save for quick add after a short delay
        if (widget.preSelectedTransportType != null && widget.preSelectedDistance != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              _saveActivity();
            }
          });
        }
      });
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    distanceController.dispose();
    notesController.dispose();
    _animationController.dispose();
    _resultAnimationController.dispose();
    super.dispose();
  }

  void _calculateCO2() {
    if (selectedTransportType != null && distanceController.text.isNotEmpty) {
      final distance = double.tryParse(distanceController.text);
      if (distance != null && distance > 0) {
        setState(() {
          calculatedCO2 = TransportActivity.getCO2Factor(selectedTransportType!) * distance;
          if (!showResult) {
            showResult = true;
            _resultAnimationController.forward();
          }
        });
      }
    } else {
      setState(() {
        if (showResult) {
          _resultAnimationController.reverse();
        }
        showResult = false;
        calculatedCO2 = 0.0;
      });
    }
  }

  void _selectTransportType(TransportType type) async {
    await HapticHelper.trigger(HapticType.selection);
    setState(() {
      selectedTransportType = type;
      _calculateCO2();
    });
  }

  void _saveActivity() async {
    if (selectedTransportType == null || distanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.translate('transport.validation.selectTypeAndDistance')
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final distance = double.tryParse(distanceController.text);
    if (distance == null || distance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.translate('transport.validation.enterValidDistance')
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    await HapticHelper.trigger(HapticType.light);

    try {
      final activity = TransportActivity.create(
        type: selectedTransportType!,
        distanceKm: distance,
        durationMinutes: 0, // Default duration - could be estimated
        notes: notesController.text.isEmpty ? null : notesController.text,
      );

      await DatabaseService.instance.insertTransportActivity(activity);
      
      // Update widgets with new activity
      await WidgetDataProvider.instance.onActivityAdded(
        category: AppLocalizations.of(context)!.transportTitle,
        co2Amount: activity.co2EmissionKg,
        description: '${AppLocalizations.of(context)!.translate('transport.' + activity.type.name)} - ${activity.distanceKm} ${AppLocalizations.of(context)!.transportKm}',
      );
      
      if (mounted) {
        await HapticHelper.trigger(HapticType.success);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${AppLocalizations.of(context)!.translate('transport.saved')} ${activity.co2EmissionKg.toStringAsFixed(2)} kg CO₂',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset form
        setState(() {
          selectedTransportType = null;
          distanceController.clear();
          notesController.clear();
          showResult = false;
          calculatedCO2 = 0.0;
          isLoading = false;
        });
        _resultAnimationController.reset();

        // Return to home with success
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      await HapticHelper.trigger(HapticType.error);
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ ${AppLocalizations.of(context)!.translate('common.error')}: $e'
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚗 ${AppLocalizations.of(context)!.transportTitle}'),
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
              // Header card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.1),
                      Colors.blue.withValues(alpha: 0.05),
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
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car,
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
                            AppLocalizations.of(context)!.translate('transport.trackHeader'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.translate('transport.selectTypeAndDistance'),
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
              
              // Transport type selection
              Text(
                AppLocalizations.of(context)!.translate('transport.selectTransportType'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Transport type grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: TransportType.values.length,
                itemBuilder: (context, index) {
                  final transportType = TransportType.values[index];
                  final isSelected = selectedTransportType == transportType;
                  
                  return MicroCard(
                    onTap: () => _selectTransportType(transportType),
                    hapticType: HapticType.light,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            TransportActivity.getTransportTypeIcon(transportType),
                            style: TextStyle(
                              fontSize: isSelected ? 36 : 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.translate('transport.' + transportType.name),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.blue : null,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${TransportActivity.getCO2Factor(transportType).toStringAsFixed(2)} kg CO₂/km',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected 
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Distance input
              Text(
                '${AppLocalizations.of(context)!.transportDistance} (${AppLocalizations.of(context)!.transportKm})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: distanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '15.5',
                  suffixText: AppLocalizations.of(context)!.transportKm,
                  prefixIcon: const Icon(Icons.straighten),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.grey.shade50,
                ),
                onChanged: (value) => _calculateCO2(),
              ),
              
              const SizedBox(height: 24),
              
              // Notes (optional)
              Text(
                AppLocalizations.of(context)!.translate('common.notesOptional'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.translate('common.notesOptional'),
                  prefixIcon: const Icon(Icons.note),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.grey.shade50,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // CO2 calculation result with animation
              if (showResult) ...[
                AnimatedBuilder(
                  animation: _resultAnimationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withValues(alpha: 0.1),
                                Colors.green.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.eco,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppLocalizations.of(context)!.translate('energy.estimatedEmission'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedTransportType != null 
                                            ? AppLocalizations.of(context)!.translate('transport.' + selectedTransportType!.name)
                                            : '',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '${distanceController.text} ${AppLocalizations.of(context)!.transportKm}',
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
                                        calculatedCO2.toStringAsFixed(2),
                                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      Text(
                                        'kg CO₂',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: showResult && !isLoading ? _saveActivity : null,
                  icon: isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(AppLocalizations.of(context)!.translate('common.save')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showResult ? Colors.green : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
