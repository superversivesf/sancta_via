import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rosary_companion/main.dart';
import 'package:rosary_companion/screens/home/home_screen.dart';

void main() {
  group('Rosary Screen Widget Tests', () {
    Widget createTestApp({Widget? home, GoRouter? router}) {
      if (router != null) {
        return ProviderScope(child: MaterialApp.router(routerConfig: router));
      }
      return ProviderScope(
        child: MaterialApp(home: home ?? const HomeScreen()),
      );
    }

    group('Home Screen', () {
      testWidgets('renders with initial state', (tester) async {
        await tester.pumpWidget(createTestApp());

        // Verify home screen renders
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('displays app title', (tester) async {
        await tester.pumpWidget(createTestApp());

        // Verify title is present
        expect(find.text('Sancta Via Rosary'), findsOneWidget);
      });

      testWidgets('centered content is displayed', (tester) async {
        await tester.pumpWidget(createTestApp());

        // Verify some content is shown (placeholder for now)
        expect(find.byType(Center), findsOneWidget);
      });
    });

    group('RosaryCompanionApp', () {
      testWidgets('app builds successfully', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RosaryCompanionApp()),
        );

        // Wait for providers to initialize
        await tester.pumpAndSettle();

        // Verify app is rendered
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('supports theme switching', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: RosaryCompanionApp()),
        );

        await tester.pumpAndSettle();

        // MaterialApp should have both light and dark themes defined
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.theme, isNotNull);
        expect(materialApp.darkTheme, isNotNull);
      });
    });

    group('Navigation Tests', () {
      testWidgets('home route displays home screen', (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        );

        await tester.pumpWidget(createTestApp(router: router));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('unknown route shows error page', (tester) async {
        final router = GoRouter(
          initialLocation: '/unknown',
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
          errorBuilder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(child: Text('Page Not Found')),
          ),
        );

        await tester.pumpWidget(createTestApp(router: router));
        await tester.pumpAndSettle();

        expect(find.text('Page Not Found'), findsWidgets);
      });
    });

    group('Mystery Selection', () {
      testWidgets('placeholder for mystery selection screen', (tester) async {
        // This test will be expanded once mystery selection screen is implemented
        await tester.pumpWidget(createTestApp());

        // Currently home screen shows placeholder text
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    group('Prayer Advancement', () {
      testWidgets('placeholder for prayer advancement', (tester) async {
        // This test will be expanded once prayer screen is implemented
        await tester.pumpWidget(createTestApp());

        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });
  });
}
