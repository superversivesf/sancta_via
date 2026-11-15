import 'package:http/http.dart' as http;

Future<void> main() async {
  final Uri uri = Uri.parse(
    'https://en.wikipedia.org/w/api.php?action=query&prop=extracts'
    '&explaintext=1&format=json&formatversion=2&redirects=1&titles=Padre%20Pio',
  );
  final Stopwatch clock = Stopwatch()..start();
  final http.Client client = http.Client();
  try {
    final http.Response response = await client
        .get(
          uri,
          headers: <String, String>{'user-agent': 'sancta-via-grounding/1.0'},
        )
        .timeout(const Duration(seconds: 30));
    print('status ${response.statusCode} in ${clock.elapsedMilliseconds}ms, '
        'len ${response.body.length}');
  } catch (error) {
    print('FAILED after ${clock.elapsedMilliseconds}ms: $error');
  }
  client.close();
}
