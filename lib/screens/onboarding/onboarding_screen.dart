import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/onboarding_provider.dart';
import '../../providers/text_scaling_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
    
    // Start the onboarding process
    Future.microtask(() {
      ref.read(onboardingProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(onboardingProvider);
    final textScaling = ref.watch(textScaleProvider);
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);

    // Parse liturgical color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity) ?? 
                     Theme.of(context).colorScheme.primary;

    // Navigate to home when completed
    ref.listen(onboardingProvider, (previous, current) {
      if (current.state == OnboardingState.completed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && context.mounted) {
            context.go('/');
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo/Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: themeColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.menu_book,
                          size: 60,
                          color: themeColor,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // App Title
                      Text(
                        'Sancta Via Bible',
                        style: textScaling.scaledHeadlineLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Subtitle
                      Text(
                        'Catholic Bible Reading App',
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Progress section
                      _buildProgressSection(context, progress, themeColor, textScaling),
                      
                      const SizedBox(height: 32),
                      
                      // Error handling
                      if (progress.state == OnboardingState.error) ...[
                        _buildErrorSection(context, progress, themeColor, textScaling),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Footer
                      Text(
                        'Preparing your Catholic Bible reading experience...',
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    OnboardingProgress progress,
    Color themeColor,
    TextScaling textScaling,
  ) {
    return Column(
      children: [
        // Progress indicator
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // Progress bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: themeColor.withValues(alpha: 0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: MediaQuery.of(context).size.width * progress.progress,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeColor.withValues(alpha: 0.7),
                          themeColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Progress text
              Text(
                progress.message,
                style: textScaling.scaledTitleMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Step indicator
              if (progress.totalSteps > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 1; i <= progress.totalSteps; i++) ...[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= progress.currentStep 
                              ? themeColor 
                              : themeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      if (i < progress.totalSteps) ...[
                        Container(
                          width: 24,
                          height: 2,
                          color: i < progress.currentStep 
                              ? themeColor 
                              : themeColor.withValues(alpha: 0.3),
                        ),
                      ],
                    ],
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Step ${progress.currentStep} of ${progress.totalSteps}',
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              
              // Loading indicator
              if (progress.state == OnboardingState.loading || 
                  progress.state == OnboardingState.checking) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
              ],
              
              // Completion check
              if (progress.state == OnboardingState.completed) ...[
                const SizedBox(height: 24),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 32,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(
    BuildContext context,
    OnboardingProgress progress,
    Color themeColor,
    TextScaling textScaling,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.error_outline,
            size: 32,
            color: Colors.red,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Setup Error',
          style: textScaling.scaledTitleMedium(context).copyWith(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        if (progress.error != null) ...[
          Text(
            progress.error!,
            style: textScaling.scaledBodyMedium(context).copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
        ],
        
        ElevatedButton(
          onPressed: () {
            ref.read(onboardingProvider.notifier).retry();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text(
            'Retry',
            style: textScaling.scaledLabelLarge(context),
          ),
        ),
      ],
    );
  }
}
