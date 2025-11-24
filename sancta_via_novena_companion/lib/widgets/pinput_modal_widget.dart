import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// A modal bottom sheet widget for PIN entry using Pinput
class PinputModalWidget {
  /// Shows a PIN entry modal using full-screen overlay for better keyboard handling
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String? errorMessage,
    bool isLoading = false,
    bool obscureText = true,
    String? confirmPinText,
    VoidCallback? onForgotPin,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: !isLoading,
      barrierColor: Colors.black54,
      useSafeArea: false,
      builder: (context) => _PinputOverlay(
        title: title,
        subtitle: subtitle,
        errorMessage: errorMessage,
        isLoading: isLoading,
        obscureText: obscureText,
        confirmPinText: confirmPinText,
        onForgotPin: onForgotPin,
      ),
    );
  }
}

class _PinputOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? errorMessage;
  final bool isLoading;
  final bool obscureText;
  final String? confirmPinText;
  final VoidCallback? onForgotPin;

  const _PinputOverlay({
    required this.title,
    required this.isLoading,
    required this.obscureText,
    this.subtitle,
    this.errorMessage,
    this.confirmPinText,
    this.onForgotPin,
  });

  @override
  State<_PinputOverlay> createState() => _PinputOverlayState();
}

class _PinputOverlayState extends State<_PinputOverlay>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _pinController;
  late final FocusNode _focusNode;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _focusNode = FocusNode();
    
    // Setup shake animation for errors
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Auto-focus the PIN input with delay to ensure modal is fully shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.debug('Requesting focus for PIN input', 'PINPUT_MODAL');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !widget.isLoading) {
          _focusNode.requestFocus();
          AppLogger.debug('Focus requested for PIN input', 'PINPUT_MODAL');
        }
      });
    });
  }

  @override
  void didUpdateWidget(_PinputOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Trigger shake animation when error message appears
    if (widget.errorMessage != null && oldWidget.errorMessage != widget.errorMessage) {
      _shakeController.forward().then((_) {
        _shakeController.reset();
        // Clear the PIN field on error
        _pinController.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            // Positioned container that sits above keyboard
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight + 20, // 20px margin above keyboard
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.7, // Max 70% of screen height
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subtitle!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.isLoading ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Confirm PIN display (if provided)
                            if (widget.confirmPinText != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withAlpha(51),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Your PIN:',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.confirmPinText!,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontFamily: 'monospace',
                                        letterSpacing: 8,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // PIN Input - with proper centering
                            AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_shakeAnimation.value * 10 * (0.5 - _shakeAnimation.value), 0),
                                  child: child,
                                );
                              },
                              child: _buildPinput(colorScheme),
                            ),

                            const SizedBox(height: 16),

                            // Error message
                            if (widget.errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: colorScheme.onErrorContainer,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.errorMessage!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Loading indicator
                            if (widget.isLoading) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Verifying...',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Forgot PIN button
                            if (widget.onForgotPin != null) ...[
                              TextButton(
                                onPressed: widget.isLoading ? null : widget.onForgotPin,
                                child: const Text('Forgot PIN?'),
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _buildPinput(ColorScheme colorScheme) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withAlpha(153),
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest, // Use a more contrasted background
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: colorScheme.primary,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.primaryContainer,
        border: Border.all(
          color: colorScheme.primary,
          width: 2.0,
        ),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.errorContainer.withAlpha(77),
        border: Border.all(
          color: colorScheme.error,
          width: 2.5,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Pinput(
        controller: _pinController,
        focusNode: _focusNode,
        length: AppConstants.pinLength,
        defaultPinTheme: defaultPinTheme,
        focusedPinTheme: focusedPinTheme,
        submittedPinTheme: submittedPinTheme,
        errorPinTheme: widget.errorMessage != null ? errorPinTheme : null,
        obscureText: widget.obscureText,
        obscuringCharacter: '●',
        pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
        showCursor: true,
        cursor: Container(
          width: 2,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        enabled: !widget.isLoading,
        // Keyboard configuration
        keyboardType: TextInputType.number,
        autofocus: true,
        useNativeKeyboard: true, // Use native keyboard for better UX
        hapticFeedbackType: HapticFeedbackType.lightImpact,
        onCompleted: (pin) {
          AppLogger.debug('PIN completed: length=${pin.length}', 'PINPUT_MODAL');
          if (!widget.isLoading) {
            Navigator.of(context).pop(pin);
          }
        },
        onChanged: (pin) {
          AppLogger.debug('PIN changed: length=${pin.length}', 'PINPUT_MODAL');
        },
        onTap: () {
          AppLogger.debug('PIN input tapped - requesting focus', 'PINPUT_MODAL');
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
      ),
    );
  }
}
