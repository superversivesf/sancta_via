#!/usr/bin/env dart

/// Quick script to rebuild the Bible database and check for Revelation
/// This combines the build and debug steps for convenience

import 'dart:io';

void main() async {
  print('🔧 Bible Database Rebuild & Debug Tool');
  print('====================================');
  
  // Step 1: Rebuild the database
  print('\n📗 Step 1: Rebuilding database...');
  final buildResult = await Process.run(
    'dart', 
    ['tools/build_bible_database.dart'],
    workingDirectory: '.',
  );
  
  print('Build output:');
  print(buildResult.stdout);
  
  if (buildResult.stderr.isNotEmpty) {
    print('Build errors:');
    print(buildResult.stderr);
  }
  
  if (buildResult.exitCode != 0) {
    print('❌ Database build failed with exit code ${buildResult.exitCode}');
    return;
  }
  
  // Step 2: Debug Revelation
  print('\n🔍 Step 2: Checking Revelation...');
  final debugResult = await Process.run(
    'dart', 
    ['tools/debug_revelation.dart'],
    workingDirectory: '.',
  );
  
  print('Debug output:');
  print(debugResult.stdout);
  
  if (debugResult.stderr.isNotEmpty) {
    print('Debug errors:');
    print(debugResult.stderr);
  }
  
  print('\n✅ Rebuild and debug complete!');
  print('\nNext steps:');
  print('1. Run flutter clean');
  print('2. Run flutter pub get');  
  print('3. Test the app to see if Revelation loads correctly');
}
