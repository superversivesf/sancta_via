import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/text_scaling_provider.dart';

enum PrayerReadingMode {
  normal,
  contemplative,
  immersive,
}

class EnhancedPrayerText extends ConsumerStatefulWidget {
  final String text;
  final String language;
  final Color? themeColor;
  final PrayerReadingMode readingMode;
  final bool enableVerseHighlighting;

  const EnhancedPrayerText({
    super.key,
    required this.text,
    this.language = 'English',
    this.themeColor,
    this.readingMode = PrayerReadingMode.normal,
    this.enableVerseHighlighting = false,
  });

  @override
  ConsumerState<EnhancedPrayerText> createState() => _EnhancedPrayerTextState();
}

class _EnhancedPrayerTextState extends ConsumerState<EnhancedPrayerText> {
  int? highlightedVerseIndex;
  List<String> verses = [];

  @override
  void initState() {
    super.initState();
    _parseVerses();
  }

  @override
  void didUpdateWidget(EnhancedPrayerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _parseVerses();
    }
  }

  void _parseVerses() {
    // Split prayer text into verses/lines for highlighting
    verses = widget.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }

  TextStyle _getPrayerTextStyle(BuildContext context) {
    final textScaling = ref.watch(textScaleProvider);
    
    // Determine appropriate text color based on theme and context
    Color textColor;
    final brightness = Theme.of(context).brightness;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    
    // Ensure good contrast regardless of liturgical background
    if (brightness == Brightness.dark) {
      textColor = onSurface; // Use theme's onSurface for dark theme
    } else {
      textColor = onSurface; // Use theme's onSurface for light theme
    }
    
    // Base style with enhanced typography and proper color
    TextStyle baseStyle = textScaling.scaledPrayerText(
      context,
      language: widget.language,
      color: textColor,
    );

    // Enhanced line spacing and formatting based on reading mode
    switch (widget.readingMode) {
      case PrayerReadingMode.contemplative:
        return baseStyle.copyWith(
          height: 2.0, // Extra generous line spacing
          fontSize: (baseStyle.fontSize ?? 16) * 1.1,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          color: textColor, // Ensure color is preserved
        );
      case PrayerReadingMode.immersive:
        return baseStyle.copyWith(
          height: 1.8,
          fontSize: (baseStyle.fontSize ?? 16) * 1.05,
          letterSpacing: 0.3,
          color: textColor, // Ensure color is preserved
        );
      case PrayerReadingMode.normal:
      default:
        return baseStyle.copyWith(
          height: 1.6, // Better than default 1.0 line spacing
          letterSpacing: 0.2,
          color: textColor, // Ensure color is preserved
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableVerseHighlighting) {
      // Simple enhanced text without verse highlighting
      return _buildSimpleEnhancedText(context);
    }

    // Verse-by-verse highlighting enabled
    return _buildVerseHighlightingText(context);
  }

  Widget _buildSimpleEnhancedText(BuildContext context) {
    return SelectableText(
      widget.text,
      style: _getPrayerTextStyle(context),
      textAlign: _getTextAlignment(),
    );
  }

  Widget _buildVerseHighlightingText(BuildContext context) {
    return Column(
      crossAxisAlignment: _getCrossAxisAlignment(),
      children: [
        // Instructions for verse highlighting
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Tap each verse to follow along',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: widget.themeColor?.withValues(alpha: 0.7) ?? 
                     Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Verses with highlighting
        ...verses.asMap().entries.map((entry) {
          final index = entry.key;
          final verse = entry.value;
          final isHighlighted = highlightedVerseIndex == index;
          final isPreviouslyRead = highlightedVerseIndex != null && index < highlightedVerseIndex!;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                highlightedVerseIndex = index;
              });
              
              // Auto-advance after a delay in contemplative mode
              if (widget.readingMode == PrayerReadingMode.contemplative) {
                Future.delayed(const Duration(seconds: 8), () {
                  if (mounted && highlightedVerseIndex == index && index < verses.length - 1) {
                    setState(() {
                      highlightedVerseIndex = index + 1;
                    });
                  }
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getVerseBackgroundColor(context, isHighlighted, isPreviouslyRead),
                borderRadius: BorderRadius.circular(8),
                border: isHighlighted
                    ? Border.all(
                        color: widget.themeColor?.withValues(alpha: 0.5) ?? 
                               Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        width: 2,
                      )
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: _getPrayerTextStyle(context).copyWith(
                  color: _getVerseTextColor(context, isHighlighted, isPreviouslyRead),
                  fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.w400,
                ),
                child: SelectableText(
                  verse,
                  textAlign: _getTextAlignment(),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Color _getVerseBackgroundColor(BuildContext context, bool isHighlighted, bool isPreviouslyRead) {
    if (isHighlighted) {
      return widget.themeColor?.withValues(alpha: 0.15) ?? 
             Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    } else if (isPreviouslyRead) {
      return Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3);
    }
    return Colors.transparent;
  }

  Color _getVerseTextColor(BuildContext context, bool isHighlighted, bool isPreviouslyRead) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    
    if (isHighlighted) {
      return onSurface;
    } else if (isPreviouslyRead) {
      return onSurface.withValues(alpha: 0.6);
    }
    return onSurface.withValues(alpha: 0.8);
  }

  TextAlign _getTextAlignment() {
    switch (widget.readingMode) {
      case PrayerReadingMode.contemplative:
        return TextAlign.center;
      case PrayerReadingMode.immersive:
        return TextAlign.center;
      case PrayerReadingMode.normal:
      default:
        return TextAlign.left;
    }
  }

  CrossAxisAlignment _getCrossAxisAlignment() {
    switch (widget.readingMode) {
      case PrayerReadingMode.contemplative:
      case PrayerReadingMode.immersive:
        return CrossAxisAlignment.center;
      case PrayerReadingMode.normal:
      default:
        return CrossAxisAlignment.stretch;
    }
  }
}
