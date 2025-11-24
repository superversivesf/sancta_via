#!/usr/bin/env dart

import 'dart:io';

/// Build script for generating liturgical calendar data
/// 
/// This script regenerates the embedded Dart liturgical data by calling
/// the Node.js generation script. It's designed to be run from the
/// package root directory.
void main(List<String> args) async {
  print('🗓️  Liturgical Calendar Data Builder');
  print('=====================================');
  
  final scriptDir = Directory('../../tools/romcal_integration');
  final packageDir = Directory.current;
  
  print('📁 Package directory: ${packageDir.path}');
  print('🛠️  Script directory: ${scriptDir.path}');
  
  // Check if the romcal integration directory exists
  if (!await scriptDir.exists()) {
    print('❌ Error: RomCal integration directory not found at ${scriptDir.path}');
    print('   Make sure you\'re running this from the liturgical_calendar package directory');
    exit(1);
  }
  
  // Check if Node.js is available
  final nodeResult = await Process.run('node', ['--version']);
  if (nodeResult.exitCode != 0) {
    print('❌ Error: Node.js not found. Please install Node.js to generate liturgical data.');
    exit(1);
  }
  
  print('✅ Node.js version: ${nodeResult.stdout.toString().trim()}');
  
  // Change to the romcal integration directory
  final originalDir = Directory.current;
  Directory.current = scriptDir;
  
  try {
    print('\n🔄 Installing dependencies...');
    final npmInstall = await Process.run('npm', ['install']);
    if (npmInstall.exitCode != 0) {
      print('❌ Failed to install npm dependencies:');
      print(npmInstall.stderr);
      exit(1);
    }
    
    print('✅ Dependencies installed');
    
    print('\n🏗️  Generating Dart liturgical data...');
    final generateResult = await Process.run('npm', ['run', 'generate-dart']);
    
    if (generateResult.exitCode == 0) {
      print('✅ Data generation completed successfully!');
      print('\n📋 Output:');
      print(generateResult.stdout);
      
      // Check if files were generated
      final generatedDir = Directory('${originalDir.path}/lib/src/data/generated');
      if (await generatedDir.exists()) {
        final files = await generatedDir.list().toList();
        print('\n📁 Generated files:');
        for (final file in files) {
          if (file is File && file.path.endsWith('.dart')) {
            final stat = await file.stat();
            final sizeKb = (stat.size / 1024).toStringAsFixed(1);
            print('   📄 ${file.uri.pathSegments.last} (${sizeKb}KB)');
          }
        }
      }
      
      print('\n🎉 Liturgical calendar data has been successfully generated!');
      print('\n📝 Next steps:');
      print('   1. Run tests: dart test');
      print('   2. Run example: dart run example/direct_liturgical_calendar_example.dart');
      print('   3. Commit the generated files to your repository');
      
    } else {
      print('❌ Data generation failed:');
      print(generateResult.stderr);
      exit(1);
    }
    
  } finally {
    // Restore original directory
    Directory.current = originalDir;
  }
}
