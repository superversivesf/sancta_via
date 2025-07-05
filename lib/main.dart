import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'features/examination/views/examination_list_screen.dart';
import 'features/examination/views/examination_intro_screen.dart';
import 'features/examination/views/examination_questions_screen.dart';
import 'features/examination/views/examination_summary_screen.dart';
import 'features/examination/views/completed_examinations_screen.dart';
import 'features/examination/views/completed_examination_detail_screen.dart';
import 'config/constants.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ConfessionCompanionApp(),
    ),
  );
}

class ConfessionCompanionApp extends ConsumerWidget {
  const ConfessionCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalData = ref.watch(currentLiturgicalDayProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: liturgicalData != null 
          ? AppTheme.lightTheme(LiturgicalColor.fromString(liturgicalData.celebration.color), colorIntensity)
          : AppTheme.lightTheme(null, colorIntensity),
      darkTheme: liturgicalData != null 
          ? AppTheme.darkTheme(LiturgicalColor.fromString(liturgicalData.celebration.color), colorIntensity)
          : AppTheme.darkTheme(null, colorIntensity),
      themeMode: themeMode,
      home: const HomeScreen(),
      routes: {
        '/examinations': (context) => const ExaminationListScreen(),
        '/completed-examinations': (context) => const CompletedExaminationsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle parameterized routes
        final uri = Uri.parse(settings.name ?? '');
        
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'examination') {
          final examinationId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => ExaminationIntroScreen(examinationId: examinationId),
          );
        }
        
        if (uri.pathSegments.length == 4 && 
            uri.pathSegments[0] == 'examination' && 
            uri.pathSegments[2] == 'category') {
          final examinationId = uri.pathSegments[1];
          final categoryId = uri.pathSegments[3];
          return MaterialPageRoute(
            builder: (context) => ExaminationQuestionsScreen(
              examinationId: examinationId,
              categoryId: categoryId,
            ),
          );
        }
        
        if (uri.pathSegments.length == 3 && 
            uri.pathSegments[0] == 'examination' && 
            uri.pathSegments[2] == 'summary') {
          final examinationId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => ExaminationSummaryScreen(examinationId: examinationId),
          );
        }
        
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'completed') {
          final sessionId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => CompletedExaminationDetailScreen(
              completedExaminationId: sessionId,
            ),
          );
        }
        
        return null;
      },
    );
  }
}
