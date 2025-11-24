import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

/// Debug screen to verify that numbered books are working correctly
class NumberedBooksDebugScreen extends ConsumerWidget {
  const NumberedBooksDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = BibleTranslation.cpdv;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Numbered Books Debug'),
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Testing Numbered Books',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This screen verifies that books starting with numbers (like "1 Samuel") are working correctly after the book name normalization fix.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              
              // Test numbered books
              _buildTestSection('Old Testament Books', [
                '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
                '1 Chronicles', '2 Chronicles',
              ], translation, ref),
              
              const SizedBox(height: 24),
              
              _buildTestSection('New Testament Books', [
                '1 Corinthians', '2 Corinthians',
                '1 Thessalonians', '2 Thessalonians',
                '1 Timothy', '2 Timothy',
                '1 Peter', '2 Peter',
                '1 John', '2 John', '3 John',
              ], translation, ref),
              
              const SizedBox(height: 24),
              
              _buildBookNameNormalizationInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, List<String> books, BibleTranslation translation, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        ...books.map((book) => _buildBookTest(book, translation, ref)),
      ],
    );
  }

  Widget _buildBookTest(String bookName, BibleTranslation translation, WidgetRef ref) {
    final chapterCountAsync = ref.watch(optimizedChapterCountProvider((
      bookName: bookName,
      translation: translation,
    )));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                bookName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              flex: 1,
              child: chapterCountAsync.when(
                data: (count) => Row(
                  children: [
                    Icon(
                      count > 0 ? Icons.check_circle : Icons.error,
                      color: count > 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count chapters',
                      style: TextStyle(
                        color: count > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading...'),
                  ],
                ),
                error: (error, stack) => const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Error',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'DB: ${BookNameNormalizer.toDatabaseFormat(bookName)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookNameNormalizationInfo() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Name Normalization',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'The database stores book names with Roman numerals (I, II, III), but users expect Arabic numerals (1, 2, 3). The normalization system converts between these formats automatically.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Examples:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            ...['1 Samuel', '2 Corinthians', '3 John'].map((book) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $book → ${BookNameNormalizer.toDatabaseFormat(book)} (database)',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
