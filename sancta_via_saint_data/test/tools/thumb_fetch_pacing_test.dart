// Pacing + backoff tests for `tools/fetch_saint_images.dart`
// (Task 6, fix round 1: the controller's full run drowned in HTTP 429s
// because the committed tool re-requested instantly and recorded the
// throttle into the permanent ledger).
//
// Two layers:
//   1. The pure timing helpers, pinned with exact values:
//      `backoffDelayFor` (Retry-After honored, then a 2s→4s→8s ladder that
//      clamps at 8s) and `pacingDelayAfter` (measure-elapsed-then-top-up so
//      slow downloads are not double-punished by the minimum request gap).
//   2. `fetchAndProcessOne` behavior against a REAL localhost HttpServer
//      stub. Binding 127.0.0.1 inside the flutter_tester sandbox works
//      (probe-verified); the "no network" restriction concerns external
//      hosts, not loopback. The stub demonstrates: 429 + `Retry-After`
//      backing off to a success; an exhausted throttle budget surfacing as
//      `FetchThrottledException` — a DEFERRAL the caller must keep out of
//      the ledger — while permanent classes (404, undecodable body,
//      connection refused) surface as `FetchFailedException` after the
//      plan's single no-wait retry and are ledger-able.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../tools/fetch_saint_images.dart';

void main() {
  group('backoffDelayFor', () {
    test('ladder 2s, 4s, 8s, then clamps at the last rung', () {
      expect(backoffDelayFor(1), const Duration(seconds: 2));
      expect(backoffDelayFor(2), const Duration(seconds: 4));
      expect(backoffDelayFor(3), const Duration(seconds: 8));
      expect(backoffDelayFor(4), const Duration(seconds: 8));
      expect(backoffDelayFor(99), const Duration(seconds: 8));
    });

    test('an integer Retry-After header wins over the ladder', () {
      expect(backoffDelayFor(1, retryAfter: '1'), const Duration(seconds: 1));
      expect(backoffDelayFor(3, retryAfter: '0'), Duration.zero);
    });

    test('an oversized Retry-After is clamped to the cap', () {
      expect(
        backoffDelayFor(1, retryAfter: '999'),
        const Duration(seconds: 60),
      );
    });

    test('a missing, non-integer, or negative Retry-After uses the ladder', () {
      expect(backoffDelayFor(1, retryAfter: null), const Duration(seconds: 2));
      expect(
        backoffDelayFor(2, retryAfter: 'soon'),
        const Duration(seconds: 4),
      );
      expect(backoffDelayFor(2, retryAfter: '-5'), const Duration(seconds: 4));
    });

    test('custom waits replace the default ladder (test seam)', () {
      final List<Duration> waits = <Duration>[
        const Duration(milliseconds: 10),
        const Duration(milliseconds: 20),
      ];
      expect(backoffDelayFor(1, waits: waits), waits[0]);
      expect(backoffDelayFor(2, waits: waits), waits[1]);
      expect(backoffDelayFor(3, waits: waits), waits[1]);
    });
  });

  group('pacingDelayAfter', () {
    test('tops a fast request up to the minimum gap', () {
      expect(
        pacingDelayAfter(
          const Duration(milliseconds: 50),
          const Duration(milliseconds: 250),
        ),
        const Duration(milliseconds: 200),
      );
    });

    test('a slow download is not double-punished', () {
      expect(
        pacingDelayAfter(
          const Duration(milliseconds: 300),
          const Duration(milliseconds: 250),
        ),
        Duration.zero,
      );
    });

    test('a zero gap stays zero', () {
      expect(
        pacingDelayAfter(const Duration(milliseconds: 1), Duration.zero),
        Duration.zero,
      );
    });
  });

  group('fetchAndProcessOne against a localhost stub', () {
    /// A valid 8×8 PNG, small enough for instant decode.
    final List<int> imageBytes = img.encodePng(img.Image(width: 8, height: 8));

    late Directory tempDir;
    late _ScriptedStub stub;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('thumb-fetch-stub-');
      stub = _ScriptedStub();
      await stub.start();
    });

    tearDown(() async {
      await stub.close();
      tempDir.deleteSync(recursive: true);
    });

    File thumbFile(String name) => File('${tempDir.path}/$name.jpg');

    test(
      'backs off on 429 (Retry-After first, then ladder) and succeeds',
      () async {
        stub.script = <_StubResponse>[
          _StubResponse(429, retryAfter: '1'),
          _StubResponse(429),
          _StubResponse(200, body: imageBytes),
        ];
        final http.Client client = http.Client();
        final Stopwatch watch = Stopwatch()..start();
        // Default minRequestGap on purpose: the pacing top-up is exercised
        // for real (250 ms after each request, including the trailing one).
        await fetchAndProcessOne(
          client,
          ImageTarget('stub-success', stub.urlFor('/img.jpg')),
          thumbFile('stub-success'),
        );
        client.close();
        watch.stop();

        expect(thumbFile('stub-success').existsSync(), isTrue);
        expect(stub.hits, 3);
        // ≥ 1s (Retry-After) + ≥ 2s (ladder rung for the second throttle
        // error, with no header) + pacing for 2 in-URL requests; the exact
        // pacing gaps make this comfortably above 3s but far under the
        // default 30s per-test timeout.
        expect(watch.elapsed, greaterThanOrEqualTo(const Duration(seconds: 3)));
        expect(watch.elapsed, lessThan(const Duration(seconds: 29)));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('exhausted throttling is a DEFERRAL (FetchThrottledException), '
        'not a permanent failure — and writes no thumb', () async {
      stub.script = <_StubResponse>[_StubResponse(429)];
      final http.Client client = http.Client();
      // Two backoff retries => 3 total throttle attempts, with fast test
      // waits instead of the 2s/4s production ladder.
      await expectLater(
        fetchAndProcessOne(
          client,
          ImageTarget('stub-throttled', stub.urlFor('/img.jpg')),
          thumbFile('stub-throttled'),
          throttleWaits: const <Duration>[
            Duration(milliseconds: 10),
            Duration(milliseconds: 20),
          ],
          minRequestGap: Duration.zero,
        ),
        throwsA(isA<FetchThrottledException>()),
      );
      client.close();

      expect(stub.hits, 3);
      expect(thumbFile('stub-throttled').existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a permanent HTTP error retries once without waiting, then '
        'surfaces as FetchFailedException (ledger-able)', () async {
      stub.script = <_StubResponse>[_StubResponse(404)];
      final http.Client client = http.Client();
      final Stopwatch watch = Stopwatch()..start();
      await expectLater(
        fetchAndProcessOne(
          client,
          ImageTarget('stub-missing', stub.urlFor('/img.jpg')),
          thumbFile('stub-missing'),
          minRequestGap: Duration.zero,
        ),
        throwsA(isA<FetchFailedException>()),
      );
      client.close();
      watch.stop();

      expect(stub.hits, 2, reason: 'brief retry-once budget: exactly 2 tries');
      // No backoff waits on the permanent path — only pacing top-ups.
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(thumbFile('stub-missing').existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('an undecodable body is a permanent (ledger-able) failure', () async {
      final Uint8List garbage = Uint8List.fromList(List<int>.filled(64, 0x99));
      stub.script = <_StubResponse>[_StubResponse(200, body: garbage)];
      final http.Client client = http.Client();
      await expectLater(
        fetchAndProcessOne(
          client,
          ImageTarget('stub-garbage', stub.urlFor('/img.jpg')),
          thumbFile('stub-garbage'),
          minRequestGap: Duration.zero,
        ),
        throwsA(
          isA<FetchFailedException>().having(
            (FetchFailedException error) => '$error',
            'message',
            contains('image decode failed'),
          ),
        ),
      );
      client.close();

      expect(stub.hits, 2, reason: 'decode failures use the retry-once budget');
      expect(thumbFile('stub-garbage').existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a refused connection retries once after a brief pause, then '
        'surfaces as FetchFailedException', () async {
      // The stub is torn down by tearDown(); this test closes it EARLY and
      // re-binds its port value by fetching while nothing listens.
      await stub.close();

      final http.Client client = http.Client();
      final Stopwatch watch = Stopwatch()..start();
      await expectLater(
        fetchAndProcessOne(
          client,
          ImageTarget(
            'stub-dead',
            'http://127.0.0.1:1/img.jpg', // port 1: nothing listens there
          ),
          thumbFile('stub-dead'),
          minRequestGap: Duration.zero,
        ),
        throwsA(isA<FetchFailedException>()),
      );
      client.close();
      watch.stop();

      // The single connection retry waits ~750 ms; two immediate refusals
      // cannot be faster, and nothing should hang.
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('main() run-loop routing against a localhost stub', () {
    test('a throttle-exhausted URL is DEFERRED — printed, never written to the '
        'ledger, and no thumb is produced', () async {
      // Fixture run-loop test, patterned after
      // test/tools/build_saints_db_fixture_test.dart: the tool resolves
      // its inputs from `Directory.current`, so a tiny snapshot is staged
      // under the package's .dart_tool/ (gitignored) and runs as a
      // subprocess with production defaults. The loopback stub lives in
      // THIS process; the subprocess's dart VM connects to it — the same
      // 127.0.0.1 interface, so no external network is involved.
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'thumb-main-stub-',
      );
      final _ScriptedStub mainStub = _ScriptedStub()
        ..script = <_StubResponse>[_StubResponse(429)];
      await mainStub.start();

      final Directory fixture = Directory(
        '${Directory.current.path}/.dart_tool/'
        'fixture-fetch-saint-images-${DateTime.now().microsecondsSinceEpoch}',
      );
      Directory('${fixture.path}/data').createSync(recursive: true);
      Directory('${fixture.path}/tools').createSync(recursive: true);
      // The tool under test, copied verbatim.
      File(
        '${Directory.current.path}/tools/fetch_saint_images.dart',
      ).copySync('${fixture.path}/tools/fetch_saint_images.dart');
      File('${fixture.path}/data/saints_source.json').writeAsStringSync(
        '{"saints":[{"slug":"stub-saint","name":"St. Stub",'
        '"image":{"url":"${mainStub.urlFor('/img.jpg')}",'
        '"attribution":"stub","altText":"stub"}}]}\n',
      );

      try {
        final ProcessResult result = await Process.run(
          _dartExecutable(),
          <String>['run', 'tools/fetch_saint_images.dart', '--limit', '1'],
          workingDirectory: fixture.path,
        );

        expect(
          result.exitCode,
          0,
          reason:
              'a throttled run is a completed run; stderr: ${result.stderr}',
        );
        final String stdout = result.stdout as String;
        expect(stdout, contains('DEFERRED stub-saint'));
        expect(
          stdout,
          contains(
            'deferred (throttled, retry on next run): 1 '
            '(not recorded in the ledger)',
          ),
        );
        // Production ladder (2s→4s→8s) = 1 initial request + 3 backoff
        // retries, i.e. exactly 4 attempts before the throttle defers.
        expect(mainStub.hits, 4);
        // Ledger hygiene: the throttle produced NO failure entry.
        final File ledger = File('${fixture.path}/data/image_failures.json');
        expect(ledger.existsSync(), isTrue);
        expect(ledger.readAsStringSync().trim(), '[]');
        // No thumb, so the next re-run will re-attempt this URL.
        expect(
          File('${fixture.path}/assets/thumbs/stub-saint.jpg').existsSync(),
          isFalse,
        );
      } finally {
        await mainStub.close();
        tempDir.deleteSync(recursive: true);
        if (fixture.existsSync()) {
          fixture.deleteSync(recursive: true);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// The `dart` CLI to spawn `dart run` with: tests execute inside the
/// flutter_tester engine binary, so [Platform.resolvedExecutable] cannot
/// launch a dart command. [Platform.environment] carries FLUTTER_ROOT when
/// the flutter tool is the parent process; its pinned dart-sdk is used.
/// (Same resolution as test/tools/build_saints_db_fixture_test.dart.)
String _dartExecutable() {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final String dartSdk = '$flutterRoot/bin/cache/dart-sdk/bin/dart';
    if (File(dartSdk).existsSync()) {
      return dartSdk;
    }
    final String wrapper = '$flutterRoot/bin/dart';
    if (File(wrapper).existsSync()) {
      return wrapper;
    }
  }
  // Fall back to a PATH lookup (plain `dart test` or manual runs).
  return 'dart';
}

/// One scripted HTTP response the stub serves (in order; the last entry
/// repeats once the script is exhausted).
class _StubResponse {
  _StubResponse(this.status, {this.retryAfter, this.body = const <int>[]});

  final int status;
  final String? retryAfter;
  final List<int> body;
}

/// A loopback HTTP server serving a scripted sequence of responses, used to
/// exercise the tool's fetch path without touching Wikimedia.
class _ScriptedStub {
  List<_StubResponse> script = <_StubResponse>[];
  int hits = 0;
  late String baseUrl;

  late final HttpServer _server;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${_server.port}';
    _server.listen(_handle);
  }

  String urlFor(String path) => '$baseUrl$path';

  void _handle(HttpRequest request) {
    final _StubResponse response =
        script[hits >= script.length ? script.length - 1 : hits];
    hits++;
    if (response.retryAfter != null) {
      request.response.headers.set('retry-after', response.retryAfter!);
    }
    request.response.statusCode = response.status;
    request.response.add(response.body);
    request.response.close();
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}
