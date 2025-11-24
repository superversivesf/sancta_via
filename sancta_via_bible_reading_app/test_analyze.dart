import 'dart:io';

void main() async {
  print('Testing Flutter Analysis...');
  
  // Run flutter analyze and capture output
  try {
    final result = await Process.run('flutter', ['analyze'], 
      workingDirectory: '/Users/jason/Repos/SanctaVia/sancta_via_bible_reading_app'
    );
    
    print('Flutter Analyze Exit Code: ${result.exitCode}');
    print('STDOUT:');
    print(result.stdout);
    if (result.stderr.isNotEmpty) {
      print('STDERR:');  
      print(result.stderr);
    }
    
  } catch (e) {
    print('Error running flutter analyze: $e');
  }
}
