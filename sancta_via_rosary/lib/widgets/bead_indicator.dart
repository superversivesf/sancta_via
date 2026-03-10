import 'package:flutter/material.dart';

/// Visual indicator showing rosary beads with current position highlighted
class BeadIndicator extends StatelessWidget {
  final int currentBead;
  final int totalBeads;
  final Color? activeColor;
  final Color? inactiveColor;
  final double beadSize;

  const BeadIndicator({
    super.key,
    required this.currentBead,
    this.totalBeads = 10,
    this.activeColor,
    this.inactiveColor,
    this.beadSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ?? colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        children: [
          // Row of beads
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(totalBeads, (index) {
              final isActive = index == currentBead;
              final isPast = index < currentBead;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? beadSize * 1.5 : beadSize,
                height: isActive ? beadSize * 1.5 : beadSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? active
                      : isPast
                      ? active.withValues(alpha: 0.5)
                      : inactive,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: active.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: isActive ? colorScheme.surface : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              );
            }),
          ),
          const SizedBox(height: 12),
          // Progress text
          Text(
            '${currentBead + 1} of $totalBeads',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Decade indicator showing progress through all 5 decades
class DecadeIndicator extends StatelessWidget {
  final int currentDecade;
  final int? currentHailMary;
  final Color? activeColor;
  final Color? inactiveColor;

  const DecadeIndicator({
    super.key,
    required this.currentDecade,
    this.currentHailMary,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ?? colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 1; i <= 5; i++) ...[
            _buildDecadeDot(
              decade: i,
              isActive: i == currentDecade,
              isPast: i < currentDecade,
              currentHailMary: currentHailMary ?? 0,
              activeColor: active,
              inactiveColor: inactive,
            ),
            if (i < 5)
              Container(
                width: 24,
                height: 2,
                color: i < currentDecade
                    ? active.withValues(alpha: 0.5)
                    : inactive.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDecadeDot({
    required int decade,
    required bool isActive,
    required bool isPast,
    required int currentHailMary,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final baseSize = isActive ? 36.0 : 28.0;

    return Container(
      width: baseSize,
      height: baseSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? activeColor
            : isPast
            ? activeColor.withValues(alpha: 0.5)
            : inactiveColor,
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: isActive && currentHailMary > 0
            ? Text(
                '$currentHailMary',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Text(
                '$decade',
                style: TextStyle(
                  color: isActive || isPast
                      ? Colors.white
                      : inactiveColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
