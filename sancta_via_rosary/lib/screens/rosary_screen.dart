import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/audio_provider.dart';
import '../providers/rosary_session_provider.dart';
import '../widgets/audio_control_bar.dart';
import '../widgets/bead_indicator.dart';
import '../widgets/mystery_header.dart';
import '../widgets/prayer_card.dart';

/// Main rosary prayer screen with bead-by-bead progression
class RosaryScreen extends ConsumerStatefulWidget {
  final MysterySet? initialMysterySet;

  const RosaryScreen({super.key, this.initialMysterySet});

  @override
  ConsumerState<RosaryScreen> createState() => _RosaryScreenState();
}

class _RosaryScreenState extends ConsumerState<RosaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handle auto-advance when audio completes
  void _handleAudioComplete() {
    final mysterySet = widget.initialMysterySet ?? MysterySet.forToday();
    final sessionNotifier = ref.read(
      rosarySessionProvider(mysterySet).notifier,
    );

    // Check if auto-advance is enabled
    final autoAdvance = ref.read(autoAdvanceProvider);
    if (autoAdvance) {
      // Advance to next prayer
      sessionNotifier.next();
      _restartAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mysterySet = widget.initialMysterySet ?? MysterySet.forToday();
    final sessionState = ref.watch(rosarySessionProvider(mysterySet));
    final sessionNotifier = ref.read(
      rosarySessionProvider(mysterySet).notifier,
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_getScreenTitle(sessionState)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Audio settings button
          Consumer(
            builder: (context, ref, child) {
              final autoAdvance = ref.watch(autoAdvanceProvider);
              return IconButton(
                icon: Icon(autoAdvance ? Icons.volume_up : Icons.volume_off),
                tooltip: autoAdvance ? 'Audio On' : 'Audio Off',
                onPressed: () {
                  ref.read(autoAdvanceProvider.notifier).toggle();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart',
            onPressed: () => _showRestartDialog(context, sessionNotifier),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit',
            onPressed: () => _showExitDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            sessionNotifier.next();
            _restartAnimation();
            _handleStepChange(sessionState);
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 0) {
                // Swipe right - go back
                sessionNotifier.previous();
              } else {
                // Swipe left - go forward
                sessionNotifier.next();
              }
              _restartAnimation();
              _handleStepChange(sessionState);
            }
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Progress indicator
                _buildProgressIndicator(sessionState),
                const SizedBox(height: 8),
                // Main content
                Expanded(
                  child: _buildMainContent(sessionState, sessionNotifier),
                ),
                // Audio control bar
                const AudioControlBar(),
                // Navigation hints
                _buildNavigationHints(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle step changes for audio auto-play
  void _handleStepChange(RosaryPrayerState state) {
    final audioController = ref.read(audioControllerProvider);
    final mysterySet = widget.initialMysterySet ?? MysterySet.forToday();

    // Auto-play appropriate audio based on current step
    audioController.autoPlayForStep(
      prayerStep: state.currentStep,
      mysteryNumber: state.currentMystery,
      mysterySet: mysterySet,
      onComplete: _handleAudioComplete,
    );
  }

  void _restartAnimation() {
    _animationController.reset();
    _animationController.forward();
  }

  String _getScreenTitle(RosaryPrayerState state) {
    if (state.isComplete) return 'Rosary Complete';
    if (state.showClosing) return 'Closing Prayers';
    if (state.currentMystery == 0) return 'Opening Prayers';
    return 'Decade ${state.currentMystery}';
  }

  Widget _buildProgressIndicator(RosaryPrayerState state) {
    return Column(
      children: [
        // Decade progress
        if (state.currentMystery > 0 && !state.showClosing)
          DecadeIndicator(
            currentDecade: state.currentMystery,
            currentHailMary: state.hailMaryNumber > 0
                ? state.hailMaryNumber
                : null,
          ),
        // Linear progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.totalProgress / 100,
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(
    RosaryPrayerState state,
    RosaryPrayerNotifier notifier,
  ) {
    // Get the current prayer data
    final prayerData = _getCurrentPrayerData(state, notifier);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Mystery header (when in a decade)
          if (state.currentMystery > 0 &&
              !state.showClosing &&
              notifier.currentMysteryData != null)
            MysteryHeader(
              mystery: notifier.currentMysteryData,
              showSetName:
                  state.currentMystery == 1 && state.currentDecadePosition == 0,
            ),
          const SizedBox(height: 16),
          // Prayer content
          if (prayerData != null) ...[
            if (prayerData is Mystery)
              MysteryCard(
                mystery: prayerData,
                onTap: () {
                  notifier.next();
                  _restartAnimation();
                  _handleStepChange(state);
                },
              )
            else if (prayerData is RosaryPrayer)
              PrayerCard(
                prayer: prayerData,
                currentRepeat: state.currentStep == PrayerStep.hailMary
                    ? state.hailMaryNumber
                    : null,
                onTap: () {
                  notifier.next();
                  _restartAnimation();
                  _handleStepChange(state);
                },
              ),
          ],
          // Bead indicator (for Hail Marys)
          if (state.currentStep == PrayerStep.hailMary)
            BeadIndicator(currentBead: state.beadPosition, totalBeads: 10),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  dynamic _getCurrentPrayerData(
    RosaryPrayerState state,
    RosaryPrayerNotifier notifier,
  ) {
    switch (state.currentStep) {
      case PrayerStep.opening:
        return _getOpeningPrayer(state);
      case PrayerStep.announceMystery:
        return notifier.currentMysteryData;
      case PrayerStep.ourFather:
        return _getOurFather();
      case PrayerStep.hailMary:
        return _getHailMary();
      case PrayerStep.gloryBe:
        return _getGloryBe();
      case PrayerStep.fatima:
        return _getFatimaPrayer();
      case PrayerStep.closing:
        return _getClosingPrayers(state);
      case PrayerStep.complete:
        return _getCompletionView();
    }
  }

  RosaryPrayer? _getOpeningPrayer(RosaryPrayerState state) {
    switch (state.currentDecadePosition) {
      case 0:
        return const RosaryPrayer(
          id: 'sign-of-cross',
          title: 'Sign of the Cross',
          text:
              'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
          type: PrayerType.signOfCross,
        );
      case 1:
        return const RosaryPrayer(
          id: 'creed',
          title: 'Apostles\' Creed',
          text:
              '''I believe in God, the Father Almighty, Creator of heaven and earth, and in Jesus Christ, His only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; He descended into hell; on the third day He rose again from the dead; He ascended into heaven, and is seated at the right hand of God the Father Almighty; from there He will come to judge the living and the dead. I believe in the Holy Spirit, the Holy Catholic Church, the communion of Saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.''',
          type: PrayerType.apostlesCreed,
        );
      case 2:
        return const RosaryPrayer(
          id: 'opening-our-father',
          title: 'Our Father',
          text:
              'Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.',
          type: PrayerType.ourFather,
        );
      case 3:
      case 4:
        return const RosaryPrayer(
          id: 'opening-hail-marys',
          title: 'Hail Mary',
          text: '',
          type: PrayerType.hailMary,
          partialStart: 'For an increase in faith, hope, and charity:',
          partialRepeat:
              'Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.',
          partialEnd: '',
          repeatCount: 3,
        );
      default:
        return null;
    }
  }

  RosaryPrayer _getOurFather() {
    return const RosaryPrayer(
      id: 'our-father',
      title: 'Our Father',
      text:
          'Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.',
      type: PrayerType.ourFather,
    );
  }

  RosaryPrayer _getHailMary() {
    return const RosaryPrayer(
      id: 'hail-mary',
      title: 'Hail Mary',
      text: '',
      type: PrayerType.hailMary,
      partialRepeat:
          'Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.',
      repeatCount: 10,
    );
  }

  RosaryPrayer _getGloryBe() {
    return const RosaryPrayer(
      id: 'glory-be',
      title: 'Glory Be',
      text:
          'Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.',
      type: PrayerType.gloryBe,
    );
  }

  RosaryPrayer _getFatimaPrayer() {
    return const RosaryPrayer(
      id: 'fatima-prayer',
      title: 'O My Jesus (Fatima Prayer)',
      text:
          'O my Jesus, forgive us our sins, save us from the fires of hell, and lead all souls to Heaven, especially those in most need of Thy mercy.',
      type: PrayerType.fatimaPrayer,
    );
  }

  RosaryPrayer? _getClosingPrayers(RosaryPrayerState state) {
    // For now, return a simple closing
    return const RosaryPrayer(
      id: 'hail-holy-queen',
      title: 'Hail Holy Queen',
      text:
          '''Hail Holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious advocate, thine eyes of mercy towards us, and after this our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary.

Pray for us, O Holy Mother of God, that we may be made worthy of the promises of Christ. Amen.''',
      type: PrayerType.closing,
    );
  }

  Widget _getCompletionView() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Rosary Complete',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'May the peace of Christ be with you.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/');
            },
            icon: const Icon(Icons.home),
            label: const Text('Return Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationHints() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.swipe_left,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Swipe to go back',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Tap or swipe to advance',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swipe_right,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context, RosaryPrayerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Rosary?'),
        content: const Text(
          'This will reset your progress and return to the beginning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.reset();
              Navigator.of(context).pop();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Rosary?'),
        content: const Text(
          'Your progress will not be saved. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
