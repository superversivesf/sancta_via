#!/usr/bin/env dart
// Migration script to consolidate prayer metadata into individual prayer files

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🙏 Starting prayer metadata consolidation...');
  
  // Read the metadata file
  final metadataFile = File('assets/prayers/prayers_metadata.json');
  if (!metadataFile.existsSync()) {
    print('❌ Error: prayers_metadata.json not found');
    exit(1);
  }
  
  final metadataContent = metadataFile.readAsStringSync();
  final metadata = jsonDecode(metadataContent);
  final prayers = metadata['prayers'] as List;
  
  print('📋 Found ${prayers.length} prayers to process');
  
  int processed = 0;
  int errors = 0;
  
  for (final prayerMeta in prayers) {
    try {
      final fileName = prayerMeta['fileName'] as String;
      final prayerFile = File('assets/prayers/$fileName');
      
      if (!prayerFile.existsSync()) {
        print('⚠️  Warning: Prayer file $fileName not found, skipping...');
        continue;
      }
      
      // Read existing prayer content
      final prayerContent = prayerFile.readAsStringSync();
      final prayerData = jsonDecode(prayerContent);
      
      // Add metadata fields to prayer data
      prayerData['categories'] = prayerMeta['categories'];
      prayerData['description'] = prayerMeta['description'];
      prayerData['tags'] = prayerMeta['tags'];
      prayerData['isLiturgical'] = prayerMeta['isLiturgical'];
      prayerData['liturgicalPriority'] = prayerMeta['liturgicalPriority'];
      prayerData['liturgicalSeason'] = prayerMeta['liturgicalSeason'];
      
      // Write updated prayer file
      const encoder = JsonEncoder.withIndent('  ');
      final updatedContent = encoder.convert(prayerData);
      prayerFile.writeAsStringSync(updatedContent);
      
      print('✅ Updated $fileName');
      processed++;
      
    } catch (e) {
      print('❌ Error processing ${prayerMeta['fileName']}: $e');
      errors++;
    }
  }
  
  print('\n🎉 Migration complete!');
  print('   Processed: $processed prayers');
  if (errors > 0) {
    print('   Errors: $errors prayers');
  }
  
  print('\n🗑️  You can now safely delete prayers_metadata.json');
  print('   The metadata has been consolidated into individual prayer files.');
}
