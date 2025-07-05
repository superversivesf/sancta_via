import 'package:bible_data/bible_data.dart';

/// Example showing how to use the bible_data package
void main() async {
  print('=== Bible Data Package Example ===\n');

  // Example 1: Using ScriptureReference
  print('1. Scripture Reference Examples:');
  
  final ref1 = ScriptureReference.parse('John 3:16');
  print('   Parsed reference: ${ref1.displayText}');
  print('   Book: ${ref1.book}, Chapter: ${ref1.chapter}, Verse: ${ref1.startVerse}');
  print('   Is single verse: ${ref1.isSingleVerse}');
  
  final ref2 = ScriptureReference.range('Romans', 8, 28, 30);
  print('   Range reference: ${ref2.displayText}');
  print('   Verse count: ${ref2.verseCount}');
  
  // Example 2: Book mapping
  print('\n2. Book Mapping Examples:');
  
  final genesis = BibleBookMapping.getByName('Genesis');
  if (genesis != null) {
    print('   Genesis - ID: ${genesis.id}, Order: ${genesis.order}, OT: ${genesis.isOldTestament}');
  }
  
  final matthew = BibleBookMapping.findBook('Mt');
  if (matthew != null) {
    print('   Found by abbreviation "Mt": ${matthew.name}');
  }
  
  print('   Total books in mapping: ${BibleBookMapping.allBooks.length}');
  print('   OT books: ${BibleBookMapping.oldTestamentBooks.length}');
  print('   NT books: ${BibleBookMapping.newTestamentBooks.length}');
  
  // Example 3: Reference parsing
  print('\n3. Reference Parsing Examples:');
  
  final testReferences = [
    'Genesis 1:1',
    '1 Corinthians 13:4-8',
    'Psalm 23',
    'Mt 5:3-12',
    '2 Tim 3:16',
  ];
  
  for (final refText in testReferences) {
    if (ReferenceParser.isValidReference(refText)) {
      final normalized = ReferenceParser.normalize(refText);
      print('   "$refText" → "$normalized"');
    }
  }
  
  // Example 4: Bible translations
  print('\n4. Bible Translation Examples:');
  
  for (final translation in BibleTranslation.values) {
    print('   ${translation.abbreviation}: ${translation.name}');
  }
  
  print('\n   Default translation: ${BibleTranslation.defaultTranslation.name}');
  print('   Available IDs: ${BibleTranslation.availableIds}');
  
  // Example 5: Mock Bible service usage (would need actual data)
  print('\n5. Bible Service Usage Pattern:');
  print('   // Create a loader (e.g., EmbeddedBibleLoader)');
  print('   // final loader = EmbeddedBibleLoader();');
  print('   // final service = BibleService(loader);');
  print('   //');
  print('   // Get scripture content:');
  print('   // final content = await service.getScriptureByReference(');
  print('   //   "John 3:16", BibleTranslation.cpdv);');
  print('   // print(content.text);');
  print('   //');
  print('   // Search for text:');
  print('   // final results = await service.searchText(');
  print('   //   "love", BibleTranslation.cpdv, maxResults: 5);');
  print('   // for (final result in results) {');
  print('   //   print(result.displayText);');
  print('   // }');
  
  print('\n=== Example Complete ===');
}
