import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/error_handler_service.dart';
import '../utils/app_colors.dart';

class ErrorScreen extends StatelessWidget {
  final String? errorMessage;
  final String? errorDetails;
  final VoidCallback? onRetry;
  final VoidCallback? onRestart;
  final bool showDetails;
  final ErrorSeverity severity;

  const ErrorScreen({
    super.key,
    this.errorMessage,
    this.errorDetails,
    this.onRetry,
    this.onRestart,
    this.showDetails = false,
    this.severity = ErrorSeverity.medium,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final language = languageProvider.currentLanguage;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          
                          // Error icon with animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: _getErrorColor().withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getErrorIcon(),
                                    size: 60,
                                    color: _getErrorColor(),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Error title
                          Text(
                            _getErrorTitle(language),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Error message
                          Text(
                            errorMessage ?? _getDefaultMessage(language),
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Action buttons
                          _buildActionButtons(language),
                          
                          // Error details (collapsible)
                          if (showDetails && errorDetails != null) ...[
                            const SizedBox(height: 32),
                            _buildErrorDetails(language),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom help text
                  _buildHelpText(language),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(String language) {
    return Column(
      children: [
        // Primary action
        if (onRetry != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                language == 'tr' ? 'Tekrar Dene' : 'Try Again',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        
        if (onRetry != null && onRestart != null)
          const SizedBox(height: 12),
        
        // Secondary action
        if (onRestart != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt),
              label: Text(
                language == 'tr' ? 'Uygulamayı Yeniden Başlat' : 'Restart App',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Report problem button
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _showReportDialog(language),
            icon: const Icon(Icons.bug_report, size: 18),
            label: Text(
              language == 'tr' ? 'Sorunu Bildir' : 'Report Problem',
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDetails(String language) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          language == 'tr' ? 'Hata Detayları' : 'Error Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: Icon(
          Icons.info_outline,
          color: AppColors.textSecondary,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language == 'tr' ? 'Hata Detayları:' : 'Error Details:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(errorDetails!),
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: language == 'tr' 
                        ? 'Panoya Kopyala' 
                        : 'Copy to Clipboard',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  errorDetails!,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpText(String language) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              language == 'tr'
                ? 'Bu hata devam ederse, uygulama ayarlarından "Destek" bölümünden bizimle iletişime geçin.'
                : 'If this error persists, please contact us through the "Support" section in app settings.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getErrorColor() {
    switch (severity) {
      case ErrorSeverity.low:
        return AppColors.info;
      case ErrorSeverity.medium:
        return AppColors.warning;
      case ErrorSeverity.high:
        return Colors.orange;
      case ErrorSeverity.critical:
        return AppColors.error;
    }
  }

  IconData _getErrorIcon() {
    switch (severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  String _getErrorTitle(String language) {
    switch (severity) {
      case ErrorSeverity.low:
        return language == 'tr' ? 'Küçük Bir Sorun' : 'Minor Issue';
      case ErrorSeverity.medium:
        return language == 'tr' ? 'Bir Sorun Oluştu' : 'Something Went Wrong';
      case ErrorSeverity.high:
        return language == 'tr' ? 'Önemli Hata' : 'Important Error';
      case ErrorSeverity.critical:
        return language == 'tr' ? 'Kritik Hata' : 'Critical Error';
    }
  }

  String _getDefaultMessage(String language) {
    switch (severity) {
      case ErrorSeverity.low:
        return language == 'tr'
          ? 'Küçük bir teknik sorun yaşandı. Lütfen tekrar deneyin.'
          : 'We encountered a minor technical issue. Please try again.';
      case ErrorSeverity.medium:
        return language == 'tr'
          ? 'Beklenmeyen bir sorun oluştu. Lütfen tekrar deneyin veya uygulamayı yeniden başlatın.'
          : 'An unexpected problem occurred. Please try again or restart the app.';
      case ErrorSeverity.high:
        return language == 'tr'
          ? 'Önemli bir hata oluştu. Uygulamayı yeniden başlatmanız gerekebilir.'
          : 'A significant error occurred. You may need to restart the app.';
      case ErrorSeverity.critical:
        return language == 'tr'
          ? 'Kritik bir sistem hatası oluştu. Lütfen uygulamayı yeniden başlatın.'
          : 'A critical system error occurred. Please restart the application.';
    }
  }

  void _showReportDialog(String language) {
    // This will be handled by the feedback system
    ErrorHandlerService().log(
      'User requested to report error: ${errorMessage ?? "Unknown error"}',
      LogLevel.info,
      context: {
        'error_details': errorDetails,
        'severity': severity.toString(),
        'user_action': 'report_requested',
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}

// Error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(String error, VoidCallback retry)? errorBuilder;
  final String? errorMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.errorMessage,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(
        _error.toString(),
        _retry,
      ) ?? ErrorScreen(
        errorMessage: widget.errorMessage,
        errorDetails: _stackTrace?.toString(),
        onRetry: _retry,
        severity: ErrorSeverity.medium,
        showDetails: true,
      );
    }

    return widget.child;
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Catch errors in this widget tree
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
        
        // Report to error handler
        ErrorHandlerService().recordError(
          details.exception,
          details.stack,
          fatal: false,
          severity: ErrorSeverity.medium,
          context: {'widget': 'ErrorBoundary'},
        );
      }
      FlutterError.presentError(details);
    };
  }
}