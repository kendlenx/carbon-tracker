import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/language_provider.dart';
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final language = languageProvider.currentLanguage;
        
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
                    language == 'tr' ? 'Geri Bildirim' : 'Feedback',
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
                    _buildFeedbackTypeSection(language),
                    const SizedBox(height: 16),
                    
                    // Rating section (for general feedback)
                    if (_selectedType == FeedbackType.general) ...[
                      _buildRatingSection(language),
                      const SizedBox(height: 16),
                    ],
                    
                    // Email field
                    _buildEmailField(language),
                    const SizedBox(height: 16),
                    
                    // Feedback text
                    _buildFeedbackTextField(language),
                    const SizedBox(height: 16),
                    
                    // Options
                    _buildOptionsSection(language),
                    
                    // Screenshot preview
                    if (_includeScreenshot && _screenshotFile != null) ...[
                      const SizedBox(height: 16),
                      _buildScreenshotPreview(language),
                    ],
                    
                    // System info preview
                    if (widget.includeSystemInfo) ...[
                      const SizedBox(height: 16),
                      _buildSystemInfoPreview(language),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  language == 'tr' ? 'İptal' : 'Cancel',
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSubmitting || _feedbackController.text.trim().isEmpty
                  ? null 
                  : () => _submitFeedback(language),
                icon: _isSubmitting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
                label: Text(
                  language == 'tr' ? 'Gönder' : 'Send',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackTypeSection(String language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language == 'tr' ? 'Geri bildirim türü:' : 'Feedback type:',
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
          language == 'tr' 
            ? 'Uygulamayı nasıl değerlendirirsiniz?' 
            : 'How would you rate the app?',
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
        labelText: language == 'tr' ? 'E-posta (isteğe bağlı)' : 'Email (optional)',
        hintText: language == 'tr' 
          ? 'Yanıt almak için e-posta adresiniz' 
          : 'Your email for response',
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
        labelText: language == 'tr' ? 'Geri bildiriminiz' : 'Your feedback',
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
          language == 'tr' ? 'Ek bilgiler:' : 'Additional information:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        CheckboxListTile(
          title: Text(
            language == 'tr' ? 'Ekran görüntüsü ekle' : 'Include screenshot',
            style: const TextStyle(fontSize: 14),
          ),
          value: _includeScreenshot,
          onChanged: (value) => setState(() => _includeScreenshot = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: Text(
            language == 'tr' ? 'Hata günlüklerini ekle' : 'Include error logs',
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
                language == 'tr' ? 'Ekran görüntüsü:' : 'Screenshot:',
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
        language == 'tr' ? 'Sistem bilgileri' : 'System information',
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
        return language == 'tr' ? 'Hata' : 'Bug';
      case FeedbackType.feature:
        return language == 'tr' ? 'Özellik İsteği' : 'Feature Request';
      case FeedbackType.general:
        return language == 'tr' ? 'Genel' : 'General';
      case FeedbackType.performance:
        return language == 'tr' ? 'Performans' : 'Performance';
    }
  }

  String _getFeedbackHint(String language) {
    switch (_selectedType) {
      case FeedbackType.bug:
        return language == 'tr'
          ? 'Hatayı detaylı olarak açıklayın...'
          : 'Describe the bug in detail...';
      case FeedbackType.feature:
        return language == 'tr'
          ? 'Hangi özelliği istiyorsunuz?'
          : 'What feature would you like to see?';
      case FeedbackType.performance:
        return language == 'tr'
          ? 'Performans sorunu nerede yaşanıyor?'
          : 'Where are you experiencing performance issues?';
      case FeedbackType.general:
        return language == 'tr'
          ? 'Düşüncelerinizi paylaşın...'
          : 'Share your thoughts...';
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
              language == 'tr'
                ? 'Geri bildiriminiz başarıyla gönderildi. Teşekkürler!'
                : 'Your feedback has been sent successfully. Thank you!',
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
              language == 'tr'
                ? 'Geri bildirim gönderilemedi: ${e.toString()}'
                : 'Failed to send feedback: ${e.toString()}',
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final language = languageProvider.currentLanguage;
        
        return FloatingActionButton.extended(
          onPressed: () => _showFeedbackDialog(context),
          icon: const Icon(Icons.feedback),
          label: Text(
            language == 'tr' ? 'Geri Bildirim' : 'Feedback',
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        );
      },
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