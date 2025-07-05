/// Shared UI components for Sancta Via Catholic Apps Ecosystem
///
/// This library provides reusable UI components, themes, and extensions that are
/// specifically designed for Catholic liturgical applications. It includes:
///
/// - **Liturgical Color Theming** - Automatic themes based on liturgical seasons
/// - **Responsive Design Components** - Widgets that adapt to different screen sizes
/// - **Catholic UI Patterns** - Common UI patterns for prayer and liturgical apps
/// - **Theme Providers** - Riverpod providers for reactive theming
/// - **Accessibility Support** - WCAG compliant components
///
/// ## Quick Start
///
/// ```dart
/// import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
///
/// class MyApp extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // Automatic liturgical theming
///     final theme = ref.watch(liturgicalThemeProvider);
///     
///     return MaterialApp(
///       theme: theme,
///       home: Scaffold(
///         appBar: AppBar(
///           title: Text('Catholic App'),
///           backgroundColor: ref.watch(liturgicalColorProvider),
///         ),
///         body: Column(
///           children: [
///             LiturgicalColorPreview(),
///             ThemeModeSelector(),
///             ColorIntensitySelector(),
///           ],
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Core Components
///
/// ### Theme Providers
/// - `liturgicalThemeProvider` - Season-based Material theme
/// - `liturgicalColorProvider` - Current liturgical color
/// - `themeModeProvider` - Light/dark mode management
/// - `colorIntensityProvider` - Color intensity preferences
///
/// ### UI Widgets
/// - `LiturgicalColorPreview` - Visual color indicator
/// - `ThemeModeSelector` - Light/dark mode toggle
/// - `ColorIntensitySelector` - Color intensity slider
/// - `SettingsSectionHeader` - Consistent section headers
///
/// ### Extensions
/// - `LiturgicalColorExtensions` - Color manipulation utilities
/// - `ThemeExtensions` - Theme-related helpers
///
library sancta_via_shared_ui;

// Theme and color providers
export 'src/providers/theme_providers.dart';

// Theme configuration
export 'src/config/app_theme.dart';

// Shared UI components
export 'src/widgets/theme_mode_selector.dart';
export 'src/widgets/color_intensity_selector.dart';
export 'src/widgets/liturgical_color_preview.dart';
export 'src/widgets/settings_section_header.dart';

// Extensions
export 'src/extensions/liturgical_color_extensions.dart';
export 'src/extensions/theme_extensions.dart';

// Re-export liturgical calendar for convenience
export 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

// Re-export riverpod for convenience
export 'package:flutter_riverpod/flutter_riverpod.dart' 
    show Consumer, ConsumerWidget, ConsumerStatefulWidget, WidgetRef;