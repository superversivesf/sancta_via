import 'dart:convert';
import 'dart:io';

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// The pack JSON the brief's load assertions are pinned to: fixed-date
/// schedule, one prayer in content, one prayer step referencing it.
Map<String, dynamic> validPackJson() => <String, dynamic>{
  'id': 'holy-hour',
  'title': 'Holy Hour',
  'family': 'novena',
  'schedule': <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
  'content': <String, dynamic>{
    'angelus': <String, dynamic>{
      'id': 'angelus',
      'text': 'The Angel of the Lord declared unto Mary.',
      'source': 'Traditional',
      'license': 'public-domain',
    },
  },
  'session': <String, dynamic>{
    'id': 'holy-hour-session',
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'prayer',
        'id': 's-angelus',
        'title': 'The Angelus',
        'contentRef': 'angelus',
      },
    ],
  },
};

/// A minimal pack shell with a caller-chosen schedule object; the session
/// needs no content, so schedule dispatch is exercised in isolation.
Map<String, dynamic> packWithSchedule(Map<String, dynamic> schedule) =>
    <String, dynamic>{
      'id': 'dispatch-pack',
      'title': 'Dispatch',
      'family': 'routine',
      'schedule': schedule,
      'session': <String, dynamic>{
        'id': 'dispatch-session',
        'steps': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'intercession',
            'id': 's-1',
            'prompt': 'Offer your intentions.',
          },
        ],
      },
    };

/// A directly constructed pack for validator tests (no JSON involved).
ContentPack directPack(ScheduleSpec schedule) => ContentPack(
  id: 'validator-pack',
  title: 'Validator',
  family: PackFamily.routine,
  schedule: schedule,
  session: SessionScript(
    id: 'validator-session',
    steps: <SessionStep>[
      IntercessionStep(id: 's-1', prompt: 'Offer your intentions.'),
    ],
  ),
);

/// One pack JSON per schedule `type`, paired with the spec class the
/// dispatch must construct.
final List<(Map<String, dynamic>, Type)> scheduleCases =
    <(Map<String, dynamic>, Type)>[
      (
        <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
        FixedDateSpec,
      ),
      (
        <String, dynamic>{
          'type': 'easterOffset',
          'startOffset': -2,
          'lengthDays': 9,
        },
        EasterOffsetSpec,
      ),
      (
        <String, dynamic>{'type': 'nthWeekdayOfMonth', 'weekday': 7, 'nth': 1},
        NthWeekdayOfMonthSpec,
      ),
      (
        <String, dynamic>{
          'type': 'weeklyLoop',
          'weekdays': <int>[2, 4],
          'skipMonths': <int>[12],
        },
        WeeklyLoopSpec,
      ),
      (
        <String, dynamic>{
          'type': 'timeOfDay',
          'hour': 6,
          'minute': 0,
          'baseLabel': 'angelus',
          'variants': <Map<String, dynamic>>[
            <String, dynamic>{
              'months': <int>[4, 5],
              'variantId': 'regina_caeli',
            },
          ],
        },
        TimeOfDaySpec,
      ),
      (
        <String, dynamic>{
          'type': 'consecutiveCommitments',
          'anchor': <String, dynamic>{
            'type': 'nthWeekdayOfMonth',
            'weekday': 7,
            'nth': 1,
          },
          'count': 5,
          'policy': 'strict',
          'windows': <Map<String, dynamic>>[
            <String, dynamic>{
              'item': 'confession',
              'beforeDays': 8,
              'afterDays': 8,
            },
          ],
        },
        ConsecutiveCommitmentSpec,
      ),
    ];

Map<String, dynamic> allStepsPackJson() => <String, dynamic>{
  'id': 'all-steps',
  'title': 'All Step Types',
  'family': 'office',
  'schedule': <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
  'content': <String, dynamic>{
    'memorare': <String, dynamic>{
      'id': 'memorare',
      'text': 'Remember, O most gracious Virgin Mary...',
      'source': 'Traditional',
      'license': 'public-domain',
    },
    'salve-regina': <String, dynamic>{
      'id': 'salve-regina',
      'text': 'Hail, Holy Queen, Mother of Mercy...',
      'source': 'Traditional',
      'license': 'public-domain',
    },
    'reading': <String, dynamic>{
      'id': 'reading',
      'text': 'A short patristic reading.',
      'source': 'Church',
      'license': 'public-domain',
    },
  },
  'session': <String, dynamic>{
    'id': 'all-steps-session',
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'prayer',
        'id': 's-prayer',
        'title': 'Opening',
        'contentRef': 'memorare',
      },
      <String, dynamic>{
        'type': 'verse',
        'id': 's-verse',
        'versicle': 'Pray for us, O Holy Mother of God.',
        'response': 'That we may be made worthy of the promises of Christ.',
        'closingRef': 'salve-regina',
      },
      <String, dynamic>{
        'type': 'reflection',
        'id': 's-reflection',
        'textRef': 'reading',
        'durationSeconds': 45,
      },
      <String, dynamic>{
        'type': 'checkpoint',
        'id': 's-checkpoint',
        'item': 'rosary',
        'requiredForCompletion': true,
      },
      <String, dynamic>{
        'type': 'intercession',
        'id': 's-intercession',
        'prompt': 'Offer your intentions.',
      },
      <String, dynamic>{
        'type': 'beadGroup',
        'id': 's-beads',
        'mysteryTitle': 'The Annunciation',
        'mysteryFruit': 'Humility',
        'hailMaryCount': 10,
        'includeFatimaPrayer': true,
      },
      <String, dynamic>{
        'type': 'repetition',
        'id': 's-repetition',
        'contentRef': 'memorare',
        'count': 3,
      },
      <String, dynamic>{
        'type': 'litany',
        'id': 's-litany',
        'invocations': <String>['Holy Mary,', 'Mother of God,'],
        'response': 'pray for us.',
        'groupedResponse': true,
      },
    ],
  },
};

void main() {
  group('ContentPack', () {
    test('constructs with required fields and defaults empty optionals', () {
      final ContentPack pack = ContentPack(
        id: 'holy-hour',
        title: 'Holy Hour',
        family: PackFamily.novena,
        schedule: FixedDateSpec(11, 2),
        session: SessionScript(
          id: 'session',
          steps: <SessionStep>[
            IntercessionStep(id: 's-1', prompt: 'Offer your intentions.'),
          ],
        ),
      );

      expect(pack.id, 'holy-hour');
      expect(pack.title, 'Holy Hour');
      expect(pack.family, PackFamily.novena);
      expect(pack.schedule, isA<FixedDateSpec>());
      expect(pack.session.id, 'session');
      expect(pack.content, isEmpty);
      expect(pack.reminders, isEmpty);
      expect(pack.variants, isEmpty);
    });

    test('exposes unmodifiable collections', () {
      final ContentPack pack = ContentPack(
        id: 'holy-hour',
        title: 'Holy Hour',
        family: PackFamily.novena,
        schedule: FixedDateSpec(11, 2),
        session: SessionScript(
          id: 'session',
          steps: <SessionStep>[
            IntercessionStep(id: 's-1', prompt: 'Offer your intentions.'),
          ],
        ),
        content: <String, PrayerText>{},
        reminders: <String, dynamic>{},
        variants: <Map<String, dynamic>>[],
      );

      expect(
        () => pack.content['new'] = PrayerText(
          id: 'new',
          text: 'A prayer.',
          source: 'Traditional',
          license: 'public-domain',
        ),
        throwsUnsupportedError,
      );
      expect(() => pack.reminders['daily'] = '09:00', throwsUnsupportedError);
      expect(
        () => pack.variants.add(<String, dynamic>{}),
        throwsUnsupportedError,
      );
    });

    test('validating constructor rejects an empty id', () {
      expect(
        () => ContentPack(
          id: '',
          title: 'Holy Hour',
          family: PackFamily.novena,
          schedule: FixedDateSpec(11, 2),
          session: SessionScript(
            id: 'session',
            steps: <SessionStep>[
              IntercessionStep(id: 's-1', prompt: 'Offer your intentions.'),
            ],
          ),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.message, 'message', contains('ContentPack'))
              .having(
                (e) => e.message,
                'message',
                contains('id must not be empty'),
              ),
        ),
      );
    });

    test('validating constructor rejects an empty title', () {
      expect(
        () => ContentPack(
          id: 'holy-hour',
          title: '',
          family: PackFamily.novena,
          schedule: FixedDateSpec(11, 2),
          session: SessionScript(
            id: 'session',
            steps: <SessionStep>[
              IntercessionStep(id: 's-1', prompt: 'Offer your intentions.'),
            ],
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('title must not be empty'),
          ),
        ),
      );
    });
  });

  group('PackLoader.load', () {
    test('valid pack (fixed-date schedule, one prayer, prayer step) loads', () {
      final ContentPack pack = PackLoader.load(validPackJson());

      expect(pack.id, 'holy-hour');
      expect(pack.title, 'Holy Hour');
      expect(pack.family, PackFamily.novena);
      expect(pack.schedule, isA<FixedDateSpec>());
      expect(pack.session.id, 'holy-hour-session');

      final SessionStep step = pack.session.steps.single;
      expect(step, isA<PrayerStep>());
      expect(step.id, 's-angelus');
      expect(step.title, 'The Angelus');
      expect(
        (step as PrayerStep).text,
        same(pack.content['angelus']),
        reason: 'the step must resolve its contentRef to the content entry',
      );
      expect(pack.content, hasLength(1));
      expect(pack.content['angelus']!.license, 'public-domain');
      expect(pack.reminders, isEmpty);
      expect(pack.variants, isEmpty);
    });

    test('text with empty license throws ContentValidationException', () {
      final Map<String, dynamic> json = validPackJson();
      (json['content'] as Map<String, dynamic>)['angelus']['license'] = '';
      // The step references a different (valid) prayer so the license is the
      // only problem raised.
      (json['session']
          as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'prayer',
          'id': 's-other',
          'contentRef': 'other',
        },
      ];
      (json['content'] as Map<String, dynamic>)['other'] = <String, dynamic>{
        'id': 'other',
        'text': 'Another prayer.',
        'source': 'Traditional',
        'license': 'public-domain',
      };

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('content.angelus: license must not be empty')),
          ),
        ),
      );
    });

    test('unknown family throws ContentValidationException naming it', () {
      final Map<String, dynamic> json = validPackJson();
      json['family'] = 'rosary';

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('unknown family "rosary"')),
          ),
        ),
      );
    });

    test('missing family throws ContentValidationException', () {
      final Map<String, dynamic> json = validPackJson()..remove('family');

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains("missing required field 'family'")),
          ),
        ),
      );
    });

    test('missing id throws ContentValidationException', () {
      final Map<String, dynamic> json = validPackJson()..remove('id');

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('id must be a non-empty string')),
          ),
        ),
      );
    });

    test('unresolved contentRef throws listing the missing id', () {
      final Map<String, dynamic> json = validPackJson();
      (json['session']
          as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'prayer',
          'id': 's-angelus',
          'contentRef': 'memorare',
        },
      ];

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(
              contains(
                'session.steps[0]: contentRef "memorare" does not resolve to content',
              ),
            ),
          ),
        ),
      );
    });

    test('accumulates problems and throws once', () {
      final Map<String, dynamic> json = validPackJson();
      json['family'] = 'rosary';
      (json['content'] as Map<String, dynamic>)['angelus']['license'] = '';
      (json['session']
          as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'prayer',
          'id': 's-broken',
          'contentRef': 'angelus',
        },
        <String, dynamic>{
          'type': 'prayer',
          'id': 's-ghost',
          'contentRef': 'ghost',
        },
      ];

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>()
              .having(
                (e) => e.problems,
                'problems',
                anyElement(contains('unknown family "rosary"')),
              )
              .having(
                (e) => e.problems,
                'problems',
                anyElement(contains('license must not be empty')),
              )
              .having((e) => e.problems, 'problems', hasLength(4)),
        ),
      );
    });

    test('an empty (or absent) content map is allowed', () {
      final Map<String, dynamic> json = validPackJson()..remove('content');
      (json['session']
          as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'intercession',
          'id': 's-1',
          'prompt': 'Offer your intentions.',
        },
        <String, dynamic>{
          'type': 'checkpoint',
          'id': 's-2',
          'item': 'holy-hour',
          'requiredForCompletion': true,
        },
      ];

      final ContentPack pack = PackLoader.load(json);

      expect(pack.content, isEmpty);
    });

    test('unknown schedule type throws ContentValidationException', () {
      final Map<String, dynamic> json = validPackJson();
      json['schedule'] = <String, dynamic>{'type': 'lunar', 'phase': 'full'};

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('unknown schedule type "lunar"')),
          ),
        ),
      );
    });

    test('unknown step type throws ContentValidationException', () {
      final Map<String, dynamic> json = validPackJson();
      (json['session']
          as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
        <String, dynamic>{'type': 'meditation', 'id': 's-1'},
      ];

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('unknown step type "meditation"')),
          ),
        ),
      );
    });

    test('folds nested spec constructor errors into the problems list', () {
      final Map<String, dynamic> json = validPackJson();
      json['schedule'] = <String, dynamic>{
        'type': 'fixedDate',
        'month': 13,
        'day': 2,
      };

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>()
              .having(
                (e) => e.problems,
                'problems',
                anyElement(contains('month must be between 1 and 12')),
              )
              .having(
                (e) => e.problems,
                'problems',
                anyElement(isNot(contains('unknown schedule type'))),
              ),
        ),
      );
    });

    test('folds a reversed same-month window into the problems list', () {
      final Map<String, dynamic> json = validPackJson();
      json['schedule'] = <String, dynamic>{
        'type': 'fixedDate',
        'month': 11,
        'day': 8,
        'untilDay': 1,
      };

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(
              contains('window end must not precede the window start'),
            ),
          ),
        ),
      );
    });

    test('parses optional reminders and variants', () {
      final Map<String, dynamic> json = validPackJson();
      json['reminders'] = <String, dynamic>{'daily': '09:00'};
      json['variants'] = <Map<String, dynamic>>[
        <String, dynamic>{'language': 'latin'},
      ];

      final ContentPack pack = PackLoader.load(json);

      expect(pack.reminders['daily'], '09:00');
      expect(pack.variants.single['language'], 'latin');
    });
  });

  group('schedule type dispatch', () {
    test('covers all six spec classes and round-trips each schedule', () {
      for (final (Map<String, dynamic> scheduleJson, Type expected)
          in scheduleCases) {
        final ContentPack pack = PackLoader.load(
          packWithSchedule(scheduleJson),
        );

        expect(
          pack.schedule.runtimeType,
          expected,
          reason:
              "dispatch of type '${scheduleJson['type']}' must build "
              '$expected',
        );

        final ContentPack repacked = PackLoader.load(pack.toJson());
        expect(
          repacked.schedule.runtimeType,
          expected,
          reason:
              "round-trip of type '${scheduleJson['type']}' must rebuild "
              '$expected',
        );
        expect(
          repacked.toJson()['schedule'],
          scheduleJson,
          reason:
              "round-trip JSON of type '${scheduleJson['type']}' must "
              'reproduce the input schedule',
        );
      }
    });

    test('sessionSeries dispatch builds the consecration schedule', () {
      final ContentPack pack = PackLoader.load(
        packWithSchedule(<String, dynamic>{
          'type': 'sessionSeries',
          'startDate': '2027-01-04',
          'lengthDays': 34,
        }),
      );

      expect(pack.schedule, isA<SessionSeriesSpec>());
      final SessionSeriesSpec spec = pack.schedule as SessionSeriesSpec;
      expect(spec.startDate, DateTime(2027, 1, 4));
      expect(spec.lengthDays, 34);
    });

    test('parses consecutiveCommitments anchor, policy, and windows', () {
      final ContentPack pack = PackLoader.load(
        packWithSchedule(<String, dynamic>{
          'type': 'consecutiveCommitments',
          'anchor': <String, dynamic>{
            'type': 'nthWeekdayOfMonth',
            'weekday': 7,
            'nth': 1,
          },
          'count': 5,
          'policy': 'permissive',
          'windows': <Map<String, dynamic>>[
            <String, dynamic>{
              'item': 'confession',
              'beforeDays': 8,
              'afterDays': 8,
            },
          ],
        }),
      );

      final ConsecutiveCommitmentSpec spec =
          pack.schedule as ConsecutiveCommitmentSpec;
      expect(spec.count, 5);
      expect(spec.policy, RestartPolicy.permissive);
      expect(spec.anchor, isA<NthWeekdayOfMonthSpec>());
      final NthWeekdayOfMonthSpec anchor = spec.anchor as NthWeekdayOfMonthSpec;
      expect(anchor.weekday, 7);
      expect(anchor.nth, 1);
      expect(spec.windows, hasLength(1));
      expect(spec.windows.single.item, 'confession');
      expect(spec.windows.single.beforeDays, 8);
      expect(spec.windows.single.afterDays, 8);
    });

    test('rejects an unknown commitment policy', () {
      final Map<String, dynamic> schedule = <String, dynamic>{
        'type': 'consecutiveCommitments',
        'anchor': <String, dynamic>{
          'type': 'nthWeekdayOfMonth',
          'weekday': 7,
          'nth': 1,
        },
        'count': 5,
        'policy': 'weekly',
      };

      expect(
        () => PackLoader.load(packWithSchedule(schedule)),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('unknown policy "weekly"')),
          ),
        ),
      );
    });

    test('parses field values for the recurring schedule classes', () {
      final FixedDateSpec fixed =
          PackLoader.load(
                packWithSchedule(<String, dynamic>{
                  'type': 'fixedDate',
                  'month': 11,
                  'day': 1,
                  'untilDay': 8,
                }),
              ).schedule
              as FixedDateSpec;
      expect(fixed.month, 11);
      expect(fixed.day, 1);
      expect(fixed.untilMonth, isNull);
      expect(fixed.untilDay, 8);

      final EasterOffsetSpec easter =
          PackLoader.load(
                packWithSchedule(<String, dynamic>{
                  'type': 'easterOffset',
                  'startOffset': -2,
                  'lengthDays': 9,
                }),
              ).schedule
              as EasterOffsetSpec;
      expect(easter.startOffset, -2);
      expect(easter.lengthDays, 9);

      final NthWeekdayOfMonthSpec nth =
          PackLoader.load(
                packWithSchedule(<String, dynamic>{
                  'type': 'nthWeekdayOfMonth',
                  'weekday': 7,
                  'nth': 1,
                }),
              ).schedule
              as NthWeekdayOfMonthSpec;
      expect(nth.weekday, 7);
      expect(nth.nth, 1);

      final WeeklyLoopSpec weekly =
          PackLoader.load(
                packWithSchedule(<String, dynamic>{
                  'type': 'weeklyLoop',
                  'weekdays': <int>[2, 4],
                  'skipMonths': <int>[12],
                }),
              ).schedule
              as WeeklyLoopSpec;
      expect(weekly.weekdays, <int>{2, 4});
      expect(weekly.skipMonths, <int>[12]);

      final TimeOfDaySpec timeOfDay =
          PackLoader.load(
                packWithSchedule(<String, dynamic>{
                  'type': 'timeOfDay',
                  'hour': 6,
                  'minute': 0,
                  'baseLabel': 'angelus',
                  'variants': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'months': <int>[4, 5],
                      'variantId': 'regina_caeli',
                    },
                  ],
                }),
              ).schedule
              as TimeOfDaySpec;
      expect(timeOfDay.hour, 6);
      expect(timeOfDay.minute, 0);
      expect(timeOfDay.baseLabel, 'angelus');
      expect(timeOfDay.variants.single.variantId, 'regina_caeli');
      expect(timeOfDay.variants.single.months, <int>[4, 5]);
    });
  });

  group('session step dispatch', () {
    test('parses all eight step types with their fields', () {
      final ContentPack pack = PackLoader.load(allStepsPackJson());

      expect(pack.session.steps, hasLength(8));
      final List<SessionStep> steps = pack.session.steps;

      final PrayerStep prayer = steps[0] as PrayerStep;
      expect(prayer.title, 'Opening');
      expect(prayer.text, same(pack.content['memorare']));

      final VerseStep verse = steps[1] as VerseStep;
      expect(verse.versicle, 'Pray for us, O Holy Mother of God.');
      expect(verse.closing, same(pack.content['salve-regina']));

      final ReflectionStep reflection = steps[2] as ReflectionStep;
      expect(reflection.text, same(pack.content['reading']));
      expect(reflection.duration, const Duration(seconds: 45));

      final CheckpointStep checkpoint = steps[3] as CheckpointStep;
      expect(checkpoint.item, 'rosary');
      expect(checkpoint.requiredForCompletion, isTrue);

      final IntercessionStep intercession = steps[4] as IntercessionStep;
      expect(intercession.prompt, 'Offer your intentions.');

      final BeadGroupStep beads = steps[5] as BeadGroupStep;
      expect(beads.mysteryTitle, 'The Annunciation');
      expect(beads.mysteryFruit, 'Humility');
      expect(beads.hailMaryCount, 10);
      expect(beads.includeFatimaPrayer, isTrue);

      final RepetitionStep repetition = steps[6] as RepetitionStep;
      expect(repetition.text, same(pack.content['memorare']));
      expect(repetition.count, 3);

      final LitanyStep litany = steps[7] as LitanyStep;
      expect(litany.invocations, <String>['Holy Mary,', 'Mother of God,']);
      expect(litany.response, 'pray for us.');
      expect(litany.groupedResponse, isTrue);
    });

    test('round-trips the full pack', () {
      final ContentPack pack = PackLoader.load(allStepsPackJson());

      final ContentPack repacked = PackLoader.load(pack.toJson());

      expect(repacked.id, pack.id);
      expect(repacked.title, pack.title);
      expect(repacked.family, pack.family);
      expect(repacked.schedule.runtimeType, pack.schedule.runtimeType);
      expect(repacked.session.steps, hasLength(pack.session.steps.length));
      expect(repacked.session.steps, eachPairMatchesStepIn(pack.session.steps));
      expect(repacked.content.keys, pack.content.keys);
      expect(repacked.toJson(), pack.toJson());
    });
  });

  group('PackLoader.loadFromJsonString', () {
    test('loads from a JSON string', () {
      final ContentPack pack = PackLoader.loadFromJsonString(
        jsonEncode(validPackJson()),
      );

      expect(pack.id, 'holy-hour');
      expect(pack.family, PackFamily.novena);
    });

    test('rejects top-level non-object JSON', () {
      expect(
        () => PackLoader.loadFromJsonString('[1, 2]'),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains('pack JSON must be a JSON object')),
          ),
        ),
      );
    });
  });

  group('PackLoader.loadFixturesIn', () {
    test('loads .json files in sorted filename order, nothing else', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'pack_fixtures',
      );
      addTearDown(() => dir.delete(recursive: true));
      File(
        '${dir.path}/b_pack.json',
      ).writeAsStringSync(jsonEncode(minimalPackJson('b')));
      File(
        '${dir.path}/a_pack.json',
      ).writeAsStringSync(jsonEncode(minimalPackJson('a')));
      File('${dir.path}/notes.txt').writeAsStringSync('ignored');
      final Directory sub = Directory('${dir.path}/sub')..createSync();
      File(
        '${sub.path}/nested.json',
      ).writeAsStringSync(jsonEncode(minimalPackJson('nested')));

      final List<ContentPack> packs = PackLoader.loadFixturesIn(dir.path);

      expect(
        packs.map((ContentPack pack) => pack.id),
        equals(<String>['a', 'b']),
      );
    });

    test('returns an empty list for an empty directory', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'pack_fixtures_empty',
      );
      addTearDown(() => dir.delete(recursive: true));

      expect(PackLoader.loadFixturesIn(dir.path), isEmpty);
    });

    test(
      'propagates ContentValidationException for a broken fixture',
      () async {
        final Directory dir = await Directory.systemTemp.createTemp(
          'pack_fixtures_broken',
        );
        addTearDown(() => dir.delete(recursive: true));
        final Map<String, dynamic> json = minimalPackJson('broken');
        (json['session']
            as Map<String, dynamic>)['steps'] = <Map<String, dynamic>>[
          <String, dynamic>{'type': 'meditation', 'id': 's-1'},
        ];
        File('${dir.path}/broken.json').writeAsStringSync(jsonEncode(json));

        expect(
          () => PackLoader.loadFixturesIn(dir.path),
          throwsA(isA<ContentValidationException>()),
        );
      },
    );

    test('propagates a file-system error for a missing directory', () {
      expect(
        () => PackLoader.loadFixturesIn('/nonexistent/pack_fixtures_dir'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('PackValidator', () {
    test('returns no problems for a pack resolving in the fixture year', () {
      final List<String> problems = PackValidator.problems(
        directPack(FixedDateSpec(12, 17)),
        2026,
      );

      expect(problems, isEmpty);
    });

    test('reports zero due dates in the fixture year', () {
      final List<String> problems = PackValidator.problems(
        directPack(
          SessionSeriesSpec(startDate: DateTime(2027, 2, 14), lengthDays: 45),
        ),
        2026,
      );

      expect(problems, hasLength(1));
      expect(problems.single, contains('zero due dates in 2026'));
    });
  });
}

/// Builds a minimal pack JSON with no content map and one content-free step.
Map<String, dynamic> minimalPackJson(String id) => <String, dynamic>{
  'id': id,
  'title': 'Pack $id',
  'family': 'routine',
  'schedule': <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
  'session': <String, dynamic>{
    'id': '$id-session',
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'intercession',
        'id': 's-1',
        'prompt': 'Offer your intentions.',
      },
    ],
  },
};

/// A matcher asserting that [actual] pairs with [expected] step by step: the
/// same runtime type and the same [SessionStep.id] in walk order.
Matcher eachPairMatchesStepIn(List<SessionStep> expected) =>
    predicate<List<SessionStep>>((List<SessionStep> actual) {
      if (actual.length != expected.length) {
        return false;
      }
      for (int i = 0; i < actual.length; i++) {
        if (actual[i].runtimeType != expected[i].runtimeType ||
            actual[i].id != expected[i].id) {
          return false;
        }
      }
      return true;
    }, 'pairs step by step with ${expected.length} steps');
