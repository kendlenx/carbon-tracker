import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/error_handler_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_colors.dart';

class FeedbackDialog extends StatefulWidget {
  final String? crashContext;
  final String? errorMessage;
  final bool includeSystemInfo;
  final VoidCallback? onFeedbackSent;

  const FeedbackDialog({
    super.key,
    this.crashContext,
    this.errorMessage,
    this.includeSystemInfo = true,
    this.onFeedbackSent,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();
  final _screenshotController = ScreenshotController();
  
  FeedbackType _selectedType = FeedbackType.bug;
  int _rating = 0;
  bool _includeScreenshot = true;
  bool _includeErrorLogs = true;
  bool _isSubmitting = false;
  File? _screenshotFile;

  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      _selectedType = FeedbackType.bug;
      _feedbackController.text = 'App crashed with error: ${widget.errorMessage}';
    }
    _captureScreenshot();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Screenshot(
          controller: _screenshotController,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.feedback,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.translate('ui.feedback'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feedback type selection
                    _buildFeedbackTypeSection(languageCode),
                    const SizedBox(height: 16),
                    
                    // Rating section (for general feedback)
                    if (_selectedType == FeedbackType.general) ...[
                      _buildRatingSection(languageCode),
                      const SizedBox(height: 16),
                    ],
                    
                    // Email field
                    _buildEmailField(languageCode),
                    const SizedBox(height: 16),
                    
                    // Feedback text
                    _buildFeedbackTextField(languageCode),
                    const SizedBox(height: 16),
                    
                    // Options
                    _buildOptionsSection(languageCode),
                    
                    // Screenshot preview
                    if (_includeScreenshot && _screenshotFile != null) ...[
                      const SizedBox(height: 16),
                      _buildScreenshotPreview(languageCode),
                    ],
                    
                    // System info preview
                    if (widget.includeSystemInfo) ...[
                      const SizedBox(height: 16),
                      _buildSystemInfoPreview(languageCode),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)!.translate('common.cancel'),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSubmitting || _feedbackController.text.trim().isEmpty
                  ? null 
                  : () => _submitFeedback(languageCode),
                icon: _isSubmitting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
                label: Text(
                  AppLocalizations.of(context)!.translate('common.send'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          );
  }

  Widget _buildFeedbackTypeSection(String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('feedback.typeLabel'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: FeedbackType.values.map((type) {
            final isSelected = type == _selectedType;
            return FilterChip(
              label: Text(_getFeedbackTypeLabel(type, language)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedType = type;
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRatingSection(String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('feedback.ratingQuestion'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              onPressed: () => setState(() => _rating = index + 1),
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmailField(String language) {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.translate('feedback.emailOptional'),
        hintText: AppLocalizations.of(context)!.translate('feedback.emailHint'),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.email),
      ),
    );
  }

  Widget _buildFeedbackTextField(String language) {
    return TextField(
      controller: _feedbackController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.translate('feedback.messageLabel'),
        hintText: _getFeedbackHint(language),
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildOptionsSection(String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('feedback.additionalInfo'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        CheckboxListTile(
          title: Text(
            AppLocalizations.of(context)!.translate('feedback.includeScreenshot'),
            style: const TextStyle(fontSize: 14),
          ),
          value: _includeScreenshot,
          onChanged: (value) => setState(() => _includeScreenshot = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: Text(
            AppLocalizations.of(context)!.translate('feedback.includeErrorLogs'),
            style: const TextStyle(fontSize: 14),
          ),
          value: _includeErrorLogs,
          onChanged: (value) => setState(() => _includeErrorLogs = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildScreenshotPreview(String language) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.screenshot, size: 16),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.translate('feedback.screenshot'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _screenshotFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _screenshotFile!,
                    fit: BoxFit.cover,
                  ),
                )
              : const Center(
                  child: Icon(Icons.image, color: Colors.grey),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoPreview(String language) {
    return ExpansionTile(
      title: Text(
        AppLocalizations.of(context)!.translate('feedback.systemInfo'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.info, size: 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getSystemInfo(),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  String _getFeedbackTypeLabel(FeedbackType type, String language) {
    switch (type) {
      case FeedbackType.bug:
        return AppLocalizations.of(context)!.translate('feedback.type.bug');
      case FeedbackType.feature:
        return AppLocalizations.of(context)!.translate('feedback.type.feature');
      case FeedbackType.general:
        return AppLocalizations.of(context)!.translate('feedback.type.general');
      case FeedbackType.performance:
        return AppLocalizations.of(context)!.translate('feedback.type.performance');
    }
  }

  String _getFeedbackHint(String language) {
    switch (_selectedType) {
      case FeedbackType.bug:
        return AppLocalizations.of(context)!.translate('feedback.hint.bug');
      case FeedbackType.feature:
        return AppLocalizations.of(context)!.translate('feedback.hint.feature');
      case FeedbackType.performance:
        return AppLocalizations.of(context)!.translate('feedback.hint.performance');
      case FeedbackType.general:
        return AppLocalizations.of(context)!.translate('feedback.hint.general');
    }
  }

  String _getSystemInfo() {
    final errorHistory = ErrorHandlerService().getErrorHistory();
    final recentErrors = errorHistory.take(3).toList();
    
    return '''
App Version: 1.0.0
Platform: ${Platform.operatingSystem}
Feedback Type: ${_selectedType.toString()}
${widget.crashContext != null ? 'Crash Context: ${widget.crashContext}' : ''}
${widget.errorMessage != null ? 'Error: ${widget.errorMessage}' : ''}
Recent Errors: ${recentErrors.length}
Rating: ${_rating > 0 ? _rating : 'Not rated'}
Timestamp: ${DateTime.now().toIso8601String()}
''';
  }

  Future<void> _captureScreenshot() async {
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/feedback_screenshot.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(image);
        
        setState(() {
          _screenshotFile = imageFile;
        });
      }
    } catch (e) {
      ErrorHandlerService().log(
        'Failed to capture screenshot for feedback: $e',
        LogLevel.warning,
      );
    }
  }

  Future<void> _submitFeedback(String language) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final feedback = FeedbackData(
        type: _selectedType,
        message: _feedbackController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        rating: _rating > 0 ? _rating : null,
        includeScreenshot: _includeScreenshot,
        includeErrorLogs: _includeErrorLogs,
        screenshotPath: _includeScreenshot ? _screenshotFile?.path : null,
        systemInfo: widget.includeSystemInfo ? _getSystemInfo() : null,
        crashContext: widget.crashContext,
        errorMessage: widget.errorMessage,
      );

      await FeedbackService().submitFeedback(feedback);

      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate('feedback.sentSuccess'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        widget.onFeedbackSent?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.translate('feedback.sentFailed')}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

// Quick feedback button widget
class QuickFeedbackButton extends StatelessWidget {
  final String? crashContext;
  final String? errorMessage;

  const QuickFeedbackButton({
    super.key,
    this.crashContext,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return FloatingActionButton.extended(
      onPressed: () => _showFeedbackDialog(context),
      icon: const Icon(Icons.feedback),
      label: Text(
        AppLocalizations.of(context)!.translate('ui.feedback'),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(
        crashContext: crashContext,
        errorMessage: errorMessage,
      ),
    );
  }
}