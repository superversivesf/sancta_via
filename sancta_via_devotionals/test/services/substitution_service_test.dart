// Placeholder substitution tests (Plan 2, Task 7).
//
// Pins the Review Focus 4 leakage gate: pack session content carries
// `{{day}}`, `{{mysteryTitle}}`, and `{{mysteryFruit}}` placeholders (the
// sanctioned pack-content conventions from Plan 1 Tasks 16/17), and no
// unresolved `{{…}}` occurrence may ever reach rendered session text.
// Substitution is a single left-to-right pass with verbatim insertion —
// substituted values are never re-scanned — so a value containing `{{…}}`
// survives `substitute` and is caught by `requireFullySubstituted` on the
// final output.
//
// Documented legacy shape (Plan 1 Task 19 ruling): the 54-day pack stores
// the thanksgiving-decade formulas under key `petition` for BOTH phases, so
// callers read `variant['petition']` regardless of phase and hand that text
// in as a token value; this service is shape-agnostic on the token map.
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/services/substitution_service.dart';

void main() {
  group('SubstitutionService.substitute', () {
    test('dayIndex substitutes {{day}}', () {
      final String result = SubstitutionService.substitute(
        'Day {{day}} of the 33-day preparation',
        dayIndex: 5,
      );
      expect(result, 'Day 5 of the 33-day preparation');
    });

    test(
      'token map replaces {{mysteryTitle}} and {{mysteryFruit}} verbatim',
      () {
        final String result = SubstitutionService.substitute(
          '{{mysteryTitle}} — fruit of the mystery: {{mysteryFruit}}',
          tokens: <String, String>{
            'mysteryTitle': 'The Annunciation',
            'mysteryFruit': 'Humility',
          },
        );
        expect(result, 'The Annunciation — fruit of the mystery: Humility');
      },
    );

    test(
      '{{day}} without dayIndex stays and is caught by the requirement gate',
      () {
        final String result = SubstitutionService.substitute(
          'Day {{day}} of the novena',
        );
        expect(result, 'Day {{day}} of the novena');
        expect(
          () => SubstitutionService.requireFullySubstituted(result),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('{{day}}'),
            ),
          ),
        );
      },
    );

    test(
      'substituted values containing {{…}} are inserted verbatim (one pass)',
      () {
        final String result = SubstitutionService.substitute(
          'the fruit: {{mysteryFruit}}',
          tokens: <String, String>{'mysteryFruit': 'trust in {{day}} grace'},
        );
        // Verbatim insertion: the value's own {{day}} is NOT recursively
        // substituted — it survives into the output and must fail the
        // final-output requirement check below (documented on the class).
        expect(result, 'the fruit: trust in {{day}} grace');
        expect(
          () => SubstitutionService.requireFullySubstituted(result),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('{{day}}'),
            ),
          ),
        );
      },
    );
  });

  group('SubstitutionService.requireFullySubstituted', () {
    test('clean text passes through unchanged', () {
      final String clean = 'The Annunciation — Humility — day 5';
      expect(SubstitutionService.requireFullySubstituted(clean), clean);
    });

    test(
      'leftover scan lists ALL remaining {{…}} occurrences, not just the first',
      () {
        const String leaky = 'Petition: {{petition}} | Day: {{day}}';
        expect(
          () => SubstitutionService.requireFullySubstituted(leaky),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              allOf(contains('{{petition}}'), contains('{{day}}')),
            ),
          ),
        );
      },
    );

    test('unknown token {{color}} surfaces in the error', () {
      const String leaky = 'color of the roses: {{color}}';
      expect(
        () => SubstitutionService.requireFullySubstituted(leaky),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('{{color}}'),
          ),
        ),
      );
    });
  });
}
