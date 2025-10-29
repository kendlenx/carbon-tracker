import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/image_export_service.dart';
import '../l10n/app_localizations.dart';

/// Share Composer Bottom Sheet
class ShareComposerBottomSheet extends StatefulWidget {
  const ShareComposerBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ShareComposerBottomSheet(),
    );
  }

  @override
  State<ShareComposerBottomSheet> createState() => _ShareComposerBottomSheetState();
}

class _ShareComposerBottomSheetState extends State<ShareComposerBottomSheet> {
  int _tabIndex = 0; // 0: Template, 1: Customize, 2: Export
  double _ratio = 1.0; // 1:1
  Color _primary = Colors.green;
  bool _showLogo = true;
  String _title = 'Carbon Step';
  String _subtitle = 'Bugünkü ayak izi';
  String _value = '12.3 kg CO₂';

  final GlobalKey _previewKey = GlobalKey();
  SharedPreferences? _prefs;

  // Controllers to avoid rebuilding TextEditingController each frame
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _title)
      ..addListener(() {
        _title = _titleController.text;
      });
    _subtitleController = TextEditingController(text: _subtitle)
      ..addListener(() {
        _subtitle = _subtitleController.text;
      });
    _loadPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context)!;
    // Set localized defaults if not customized yet
    final storedTitle = _prefs?.getString('composer_title') ?? _title;
    if (storedTitle == 'Carbon Step') {
      _title = l.appTitle;
      _titleController.text = _title;
    }
    final storedSubtitle = _prefs?.getString('composer_subtitle') ?? _subtitle;
    if (storedSubtitle == 'Bugünkü ayak izi' || storedSubtitle == 'Your Carbon Footprint' || storedSubtitle == 'Today') {
      _subtitle = l.translate('statistics.today');
      _subtitleController.text = _subtitle;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _ratio = _prefs!.getDouble('composer_ratio') ?? 1.0;
      final colorValue = _prefs!.getInt('composer_color');
      if (colorValue != null) _primary = Color(colorValue);
      _showLogo = _prefs!.getBool('composer_show_logo') ?? true;
      _title = _prefs!.getString('composer_title') ?? _title;
      _subtitle = _prefs!.getString('composer_subtitle') ?? _subtitle;
    });
  }

  Future<void> _savePrefs() async {
    if (_prefs == null) return;
    await _prefs!.setDouble('composer_ratio', _ratio);
    await _prefs!.setInt('composer_color', _primary.value);
    await _prefs!.setBool('composer_show_logo', _showLogo);
    await _prefs!.setString('composer_title', _title);
    await _prefs!.setString('composer_subtitle', _subtitle);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = MediaQuery.of(context).size.height * 0.9;
    return Container(
      height: sheet,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(AppLocalizations.of(context)!.translate('share.tabs.templates'))),
                ButtonSegment(value: 1, label: Text(AppLocalizations.of(context)!.translate('share.tabs.customize'))),
                ButtonSegment(value: 2, label: Text(AppLocalizations.of(context)!.translate('share.tabs.export'))),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Live Preview
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight;
                      double targetW = maxW;
                      double targetH = targetW / _ratio;
                      if (targetH > maxH) {
                        targetH = maxH;
                        targetW = targetH * _ratio;
                      }
                      return Center(
                        child: SizedBox(
                          width: targetW,
                          height: targetH,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
child: AspectRatio(
                              aspectRatio: _ratio,
                              child: _buildPreviewCard(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Controls
                Expanded(
                  flex: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: _buildControls(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: Text(AppLocalizations.of(context)!.translate('share.actions.share')),
                  ),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.download),
                    label: Text(AppLocalizations.of(context)!.translate('share.actions.save')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.translate('common.close')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return RepaintBoundary(
      key: _previewKey,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLogo)
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                  child: const Icon(Icons.eco, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(_title, style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
              ],
            ),
          const Spacer(),
          Text(_value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primary)),
          const SizedBox(height: 6),
          Text(_subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.tag, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text('#CarbonStep', style: TextStyle(color: _primary)),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildControls() {
    switch (_tabIndex) {
      case 0:
        return _buildTemplates();
      case 1:
        return _buildCustomize();
      case 2:
        return _buildExport();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTemplates() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: Text(AppLocalizations.of(context)!.translate('share.templates.summaryCard')),
            onTap: () {
            setState(() {
              _title = AppLocalizations.of(context)!.translate('appTitle');
              _subtitle = AppLocalizations.of(context)!.translate('statistics.today');
              _value = '12.3 kg CO₂';
              _titleController.text = _title;
              _subtitleController.text = _subtitle;
            });
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: Text(AppLocalizations.of(context)!.translate('share.templates.badge')),
            onTap: () {
            setState(() {
              _title = AppLocalizations.of(context)!.translate('achievements.title');
              _subtitle = AppLocalizations.of(context)!.translate('ui.weeklyReward');
              _value = '🏆 750 XP';
              _titleController.text = _title;
              _subtitleController.text = _subtitle;
            });
            },
          ),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: Text(AppLocalizations.of(context)!.translate('share.templates.trend')),
            onTap: () {
            setState(() {
              _title = AppLocalizations.of(context)!.translate('statistics.sevenDayTrend');
              _subtitle = AppLocalizations.of(context)!.translate('statistics.dailyAverage');
              _value = '−3.1 kg';
              _titleController.text = _title;
              _subtitleController.text = _subtitle;
            });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomize() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.translate('share.customize.ratio')),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('1:1'), selected: _ratio == 1.0, onSelected: (_) { setState(() => _ratio = 1.0); _savePrefs(); }),
              ChoiceChip(label: const Text('4:5'), selected: (_ratio - (4 / 5)).abs() < 0.001, onSelected: (_) { setState(() => _ratio = 4 / 5); _savePrefs(); }),
            ],
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.translate('share.customize.themeColor')),
          Wrap(
            spacing: 8,
            children: [
              for (final c in [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal])
                GestureDetector(
                  onTap: () { setState(() => _primary = c); _savePrefs(); },
                  child: CircleAvatar(backgroundColor: c, radius: 14,
                    child: _primary == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.translate('share.customize.logoWatermark')),
            value: _showLogo,
            onChanged: (v) { setState(() => _showLogo = v); _savePrefs(); },
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.translate('share.customize.title')),
            controller: _titleController,
            onChanged: (v) { _savePrefs(); },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.translate('share.customize.subtitle')),
            controller: _subtitleController,
            onChanged: (v) { _savePrefs(); },
          ),
        ],
      ),
    );
  }

  Widget _buildExport() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.translate('share.export.options')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.image),
                label: Text(AppLocalizations.of(context)!.translate('share.export.savePng')),
              ),
              OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share),
                label: Text(AppLocalizations.of(context)!.translate('share.actions.share')),
              ),
            ],
          )
        ],
      ),
    );
  }

  Size _exportSize() {
    if (_ratio == 1.0) return const Size(1080, 1080);
    if ((_ratio - (4 / 5)).abs() < 0.001) return const Size(1080, 1350); // Portrait
    // Fallback to square
    return const Size(1080, 1080);
  }

  Future<void> _share() async {
    final size = _exportSize();
    try {
      await ImageExportService.instance.shareFromRepaintBoundary(
        key: _previewKey,
        size: size,
        fileName: 'carbon_share.png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('share.prepared'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('share.failed')}: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final size = _exportSize();
    try {
      final file = await ImageExportService.instance.exportFromRepaintBoundary(
        key: _previewKey,
        size: size,
        fileName: 'carbon_share.png',
      );
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.translate('common.success')),
            content: Text('${AppLocalizations.of(context)!.translate('share.savedTo')}: ${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.translate('common.ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('share.saveFailed')}: $e')),
        );
      }
    }
  }
}
