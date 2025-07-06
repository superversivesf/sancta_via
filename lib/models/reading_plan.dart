import 'package:flutter/material.dart';

enum BookCollection {
  wholeBible,
  newTestament,
  oldTestament,
  gospels,
  paulineEpistles,
  psalmsProverbs,
  majorProphets,
  minorProphets,
  wisdom,
  history;

  String get displayName {
    switch (this) {
      case BookCollection.wholeBible:
        return 'Whole Bible';
      case BookCollection.newTestament:
        return 'New Testament';
      case BookCollection.oldTestament:
        return 'Old Testament';
      case BookCollection.gospels:
        return 'Gospels';
      case BookCollection.paulineEpistles:
        return 'Pauline Epistles';
      case BookCollection.psalmsProverbs:
        return 'Psalms & Proverbs';
      case BookCollection.majorProphets:
        return 'Major Prophets';
      case BookCollection.minorProphets:
        return 'Minor Prophets';
      case BookCollection.wisdom:
        return 'Wisdom Books';
      case BookCollection.history:
        return 'Historical Books';
    }
  }

  String get description {
    switch (this) {
      case BookCollection.wholeBible:
        return 'Read through the entire Bible from Genesis to Revelation';
      case BookCollection.newTestament:
        return 'Focus on the New Testament books (Matthew to Revelation)';
      case BookCollection.oldTestament:
        return 'Focus on the Old Testament books (Genesis to Malachi)';
      case BookCollection.gospels:
        return 'Read the four Gospels: Matthew, Mark, Luke, and John';
      case BookCollection.paulineEpistles:
        return 'Paul\'s letters: Romans through Philemon';
      case BookCollection.psalmsProverbs:
        return 'Devotional reading through Psalms and Proverbs';
      case BookCollection.majorProphets:
        return 'Isaiah, Jeremiah, Lamentations, Ezekiel, and Daniel';
      case BookCollection.minorProphets:
        return 'The twelve minor prophets: Hosea through Malachi';
      case BookCollection.wisdom:
        return 'Job, Psalms, Proverbs, Ecclesiastes, and Song of Songs';
      case BookCollection.history:
        return 'Historical books from Joshua through Esther';
    }
  }

  List<String> get bookNames {
    switch (this) {
      case BookCollection.wholeBible:
        return [
          // Old Testament
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
          'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
          // New Testament
          'Matthew', 'Mark', 'Luke', 'John',
          'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
          'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation'
        ];
      case BookCollection.newTestament:
        return [
          'Matthew', 'Mark', 'Luke', 'John',
          'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
          'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation'
        ];
      case BookCollection.oldTestament:
        return [
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
          'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'
        ];
      case BookCollection.gospels:
        return ['Matthew', 'Mark', 'Luke', 'John'];
      case BookCollection.paulineEpistles:
        return [
          'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon'
        ];
      case BookCollection.psalmsProverbs:
        return ['Psalms', 'Proverbs'];
      case BookCollection.majorProphets:
        return ['Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel'];
      case BookCollection.minorProphets:
        return [
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'
        ];
      case BookCollection.wisdom:
        return ['Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs'];
      case BookCollection.history:
        return [
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther'
        ];
    }
  }
}

enum ReadingFrequency {
  daily,
  weekdays,
  weekends,
  weekly;

  String get displayName {
    switch (this) {
      case ReadingFrequency.daily:
        return 'Daily';
      case ReadingFrequency.weekdays:
        return 'Weekdays Only';
      case ReadingFrequency.weekends:
        return 'Weekends Only';
      case ReadingFrequency.weekly:
        return 'Weekly';
    }
  }

  String get description {
    switch (this) {
      case ReadingFrequency.daily:
        return 'Read every day of the week';
      case ReadingFrequency.weekdays:
        return 'Read Monday through Friday only';
      case ReadingFrequency.weekends:
        return 'Read Saturday and Sunday only';
      case ReadingFrequency.weekly:
        return 'Read once per week';
    }
  }

  bool shouldReadToday(DateTime date) {
    switch (this) {
      case ReadingFrequency.daily:
        return true;
      case ReadingFrequency.weekdays:
        return date.weekday >= 1 && date.weekday <= 5; // Monday to Friday
      case ReadingFrequency.weekends:
        return date.weekday == 6 || date.weekday == 7; // Saturday and Sunday
      case ReadingFrequency.weekly:
        return true; // Let user decide when to read weekly
    }
  }
}

class ReadingProgress {
  final String currentBook;
  final int currentChapter;
  final int bookIndex;
  final List<String> books;
  final bool isCompleted;

  const ReadingProgress({
    required this.currentBook,
    required this.currentChapter,
    required this.bookIndex,
    required this.books,
    this.isCompleted = false,
  });

  factory ReadingProgress.start(BookCollection collection) {
    final books = collection.bookNames;
    return ReadingProgress(
      currentBook: books.first,
      currentChapter: 1,
      bookIndex: 0,
      books: books,
      isCompleted: false,
    );
  }

  ReadingProgress copyWith({
    String? currentBook,
    int? currentChapter,
    int? bookIndex,
    List<String>? books,
    bool? isCompleted,
  }) {
    return ReadingProgress(
      currentBook: currentBook ?? this.currentBook,
      currentChapter: currentChapter ?? this.currentChapter,
      bookIndex: bookIndex ?? this.bookIndex,
      books: books ?? this.books,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentBook': currentBook,
      'currentChapter': currentChapter,
      'bookIndex': bookIndex,
      'books': books,
      'isCompleted': isCompleted,
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      currentBook: json['currentBook'],
      currentChapter: json['currentChapter'],
      bookIndex: json['bookIndex'],
      books: List<String>.from(json['books']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class ReadingPlan {
  final String id;
  final BookCollection collection;
  final ReadingFrequency frequency;
  final int chaptersPerDay;
  final bool remindersEnabled;
  final TimeOfDay? reminderTime;
  final ReadingProgress progress;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ReadingPlan({
    required this.id,
    required this.collection,
    required this.frequency,
    required this.chaptersPerDay,
    required this.remindersEnabled,
    this.reminderTime,
    required this.progress,
    required this.createdAt,
    this.completedAt,
  });

  ReadingPlan copyWith({
    String? id,
    BookCollection? collection,
    ReadingFrequency? frequency,
    int? chaptersPerDay,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
    ReadingProgress? progress,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ReadingPlan(
      id: id ?? this.id,
      collection: collection ?? this.collection,
      frequency: frequency ?? this.frequency,
      chaptersPerDay: chaptersPerDay ?? this.chaptersPerDay,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isCompleted => progress.isCompleted;

  bool shouldReadToday() {
    return frequency.shouldReadToday(DateTime.now()) && !isCompleted;
  }

  double get progressPercentage {
    if (progress.books.isEmpty) return 0.0;
    
    // Calculate total chapters read vs total chapters in collection
    // This is a simplified calculation - in a real app you'd want to know exact chapter counts
    final totalBooks = progress.books.length;
    final completedBooks = progress.bookIndex;
    final currentBookProgress = progress.currentChapter / 30.0; // Assume average 30 chapters per book
    
    return (completedBooks + currentBookProgress) / totalBooks;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection': collection.name,
      'frequency': frequency.name,
      'chaptersPerDay': chaptersPerDay,
      'remindersEnabled': remindersEnabled,
      'reminderTime': reminderTime != null ? {
        'hour': reminderTime!.hour,
        'minute': reminderTime!.minute,
      } : null,
      'progress': progress.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'],
      collection: BookCollection.values.firstWhere((e) => e.name == json['collection']),
      frequency: ReadingFrequency.values.firstWhere((e) => e.name == json['frequency']),
      chaptersPerDay: json['chaptersPerDay'],
      remindersEnabled: json['remindersEnabled'],
      reminderTime: json['reminderTime'] != null 
        ? TimeOfDay(
            hour: json['reminderTime']['hour'],
            minute: json['reminderTime']['minute'],
          )
        : null,
      progress: ReadingProgress.fromJson(json['progress']),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
}
