import 'package:bible_data/bible_data.dart';

/// Maximum number of simultaneous reading plans allowed
const int maxSimultaneousPlans = 5;

enum BookCollection {
  wholeBible,
  newTestament,
  oldTestament,
  gospels,
  paulineEpistles,
  pastoralEpistles,
  generalEpistles,
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
      case BookCollection.pastoralEpistles:
        return 'Pastoral Epistles';
      case BookCollection.generalEpistles:
        return 'General Epistles';
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
        return 'Read through the entire Bible from Genesis to Revelation of John';
      case BookCollection.newTestament:
        return 'Focus on the New Testament books (Matthew to Revelation of John)';
      case BookCollection.oldTestament:
        return 'Focus on the Old Testament books (Genesis to Malachi)';
      case BookCollection.gospels:
        return 'Read the four Gospels: Matthew, Mark, Luke, and John';
      case BookCollection.paulineEpistles:
        return 'Paul\'s letters: Romans through Philemon';
      case BookCollection.pastoralEpistles:
        return 'Paul\'s letters to pastors: 1 Timothy, 2 Timothy, and Titus';
      case BookCollection.generalEpistles:
        return 'Non-Pauline letters: Hebrews, James, Peter, John, and Jude';
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
          // Old Testament (Catholic Canon with Deuterocanonical Books)
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua',
          'Judges',
          'Ruth',
          '1 Samuel',
          '2 Samuel',
          '1 Kings',
          '2 Kings',
          '1 Chronicles',
          '2 Chronicles',
          'Ezra',
          'Nehemiah',
          'Tobit',
          'Judith',
          'Esther',
          '1 Maccabees', '2 Maccabees',
          'Job',
          'Psalms',
          'Proverbs',
          'Ecclesiastes',
          'Song of Songs',
          'Wisdom',
          'Sirach',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
          // New Testament
          'Matthew', 'Mark', 'Luke', 'John',
          'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians',
          'Philippians',
          'Colossians',
          '1 Thessalonians',
          '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
          'James',
          '1 Peter',
          '2 Peter',
          '1 John',
          '2 John',
          '3 John',
          'Jude',
          'Revelation of John',
        ];
      case BookCollection.newTestament:
        return [
          'Matthew',
          'Mark',
          'Luke',
          'John',
          'Acts',
          'Romans',
          '1 Corinthians',
          '2 Corinthians',
          'Galatians',
          'Ephesians',
          'Philippians',
          'Colossians',
          '1 Thessalonians',
          '2 Thessalonians',
          '1 Timothy',
          '2 Timothy',
          'Titus',
          'Philemon',
          'Hebrews',
          'James',
          '1 Peter',
          '2 Peter',
          '1 John',
          '2 John',
          '3 John',
          'Jude',
          'Revelation of John',
        ];
      case BookCollection.oldTestament:
        return [
          // Catholic Old Testament (including Deuterocanonical Books)
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua',
          'Judges',
          'Ruth',
          '1 Samuel',
          '2 Samuel',
          '1 Kings',
          '2 Kings',
          '1 Chronicles',
          '2 Chronicles',
          'Ezra',
          'Nehemiah',
          'Tobit',
          'Judith',
          'Esther',
          '1 Maccabees', '2 Maccabees',
          'Job',
          'Psalms',
          'Proverbs',
          'Ecclesiastes',
          'Song of Songs',
          'Wisdom',
          'Sirach',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
        ];
      case BookCollection.gospels:
        return ['Matthew', 'Mark', 'Luke', 'John'];
      case BookCollection.paulineEpistles:
        return [
          'Romans',
          '1 Corinthians',
          '2 Corinthians',
          'Galatians',
          'Ephesians',
          'Philippians',
          'Colossians',
          '1 Thessalonians',
          '2 Thessalonians',
          '1 Timothy',
          '2 Timothy',
          'Titus',
          'Philemon',
        ];
      case BookCollection.pastoralEpistles:
        return ['1 Timothy', '2 Timothy', 'Titus'];
      case BookCollection.generalEpistles:
        return [
          'Hebrews',
          'James',
          '1 Peter',
          '2 Peter',
          '1 John',
          '2 John',
          '3 John',
          'Jude',
        ];
      case BookCollection.psalmsProverbs:
        return ['Psalms', 'Proverbs'];
      case BookCollection.majorProphets:
        return [
          // Catholic Major Prophets (including Deuterocanonical Books)
          'Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Ezekiel', 'Daniel',
        ];
      case BookCollection.minorProphets:
        return [
          'Hosea',
          'Joel',
          'Amos',
          'Obadiah',
          'Jonah',
          'Micah',
          'Nahum',
          'Habakkuk',
          'Zephaniah',
          'Haggai',
          'Zechariah',
          'Malachi',
        ];
      case BookCollection.wisdom:
        return [
          // Catholic Wisdom Books (including Deuterocanonical Books)
          'Job',
          'Psalms',
          'Proverbs',
          'Ecclesiastes',
          'Song of Songs',
          'Wisdom',
          'Sirach',
        ];
      case BookCollection.history:
        return [
          // Catholic Historical Books (including Deuterocanonical Books)
          'Joshua',
          'Judges',
          'Ruth',
          '1 Samuel',
          '2 Samuel',
          '1 Kings',
          '2 Kings',
          '1 Chronicles',
          '2 Chronicles',
          'Ezra',
          'Nehemiah',
          'Tobit',
          'Judith',
          'Esther',
          '1 Maccabees', '2 Maccabees',
        ];
    }
  }
}

class ReadingProgress {
  final String currentBook;
  final int currentChapter;
  final int bookIndex;
  final List<String> books;
  final bool isCompleted;
  final DateTime? lastReadDate;

  const ReadingProgress({
    required this.currentBook,
    required this.currentChapter,
    required this.bookIndex,
    required this.books,
    this.isCompleted = false,
    this.lastReadDate,
  });

  factory ReadingProgress.start(BookCollection collection) {
    final books = collection.bookNames;
    return ReadingProgress(
      currentBook: books.first,
      currentChapter: 1,
      bookIndex: 0,
      books: books,
      isCompleted: false,
      lastReadDate: null,
    );
  }

  ReadingProgress copyWith({
    String? currentBook,
    int? currentChapter,
    int? bookIndex,
    List<String>? books,
    bool? isCompleted,
    DateTime? lastReadDate,
  }) {
    return ReadingProgress(
      currentBook: currentBook ?? this.currentBook,
      currentChapter: currentChapter ?? this.currentChapter,
      bookIndex: bookIndex ?? this.bookIndex,
      books: books ?? this.books,
      isCompleted: isCompleted ?? this.isCompleted,
      lastReadDate: lastReadDate ?? this.lastReadDate,
    );
  }

  String get nextChapterText {
    return '$currentBook $currentChapter';
  }

  String get nextChapterShortText {
    final metadata = BibleBookMapping.getByName(currentBook);
    final bookName = metadata?.abbreviation ?? currentBook;
    return '$bookName $currentChapter';
  }

  Map<String, dynamic> toJson() {
    return {
      'currentBook': currentBook,
      'currentChapter': currentChapter,
      'bookIndex': bookIndex,
      'books': books,
      'isCompleted': isCompleted,
      'lastReadDate': lastReadDate?.toIso8601String(),
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      currentBook: json['currentBook'],
      currentChapter: json['currentChapter'],
      bookIndex: json['bookIndex'],
      books: List<String>.from(json['books']),
      isCompleted: json['isCompleted'] ?? false,
      lastReadDate: json['lastReadDate'] != null
          ? DateTime.parse(json['lastReadDate'])
          : null,
    );
  }
}

class ReadingPlan {
  final String id;
  final String name;
  final BookCollection collection;
  final ReadingProgress progress;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isActive;

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.collection,
    required this.progress,
    required this.createdAt,
    this.completedAt,
    this.isActive = true,
  });

  ReadingPlan copyWith({
    String? id,
    String? name,
    BookCollection? collection,
    ReadingProgress? progress,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isActive,
  }) {
    return ReadingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      collection: collection ?? this.collection,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isCompleted => progress.isCompleted;

  String get nextChapterText => progress.nextChapterText;

  String get nextChapterShortText => progress.nextChapterShortText;

  double get progressPercentage {
    if (progress.books.isEmpty) return 0.0;

    // Calculate total chapters read vs total chapters in collection
    // This is a simplified calculation - in a real app you'd want to know exact chapter counts
    final totalBooks = progress.books.length;
    final completedBooks = progress.bookIndex;
    final currentBookProgress =
        progress.currentChapter / 30.0; // Assume average 30 chapters per book

    return (completedBooks + currentBookProgress) / totalBooks;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'collection': collection.name,
      'progress': progress.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'],
      name: json['name'] ?? 'Reading Plan',
      collection: BookCollection.values.firstWhere(
        (e) => e.name == json['collection'],
      ),
      progress: ReadingProgress.fromJson(json['progress']),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }
}

/// Simplified manager class for handling multiple reading plans
class ReadingPlanManager {
  final List<ReadingPlan> plans;
  final DateTime lastUpdated;
  final bool hasReadAnythingToday;
  final DateTime lastResetDate;

  const ReadingPlanManager({
    required this.plans,
    required this.lastUpdated,
    required this.hasReadAnythingToday,
    required this.lastResetDate,
  });

  factory ReadingPlanManager.empty() {
    final now = DateTime.now();
    return ReadingPlanManager(
      plans: [],
      lastUpdated: now,
      hasReadAnythingToday: false,
      lastResetDate: _normalizeToMidnight(now),
    );
  }

  /// Helper method to normalize DateTime to midnight of the same day
  static DateTime _normalizeToMidnight(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  List<ReadingPlan> get activePlans =>
      plans.where((plan) => plan.isActive && !plan.isCompleted).toList();
  List<ReadingPlan> get completedPlans =>
      plans.where((plan) => plan.isCompleted).toList();
  List<ReadingPlan> get pausedPlans =>
      plans.where((plan) => !plan.isActive && !plan.isCompleted).toList();

  bool canAddNewPlan() {
    return activePlans.length < maxSimultaneousPlans;
  }

  ReadingPlanManager addPlan(ReadingPlan plan) {
    if (!canAddNewPlan()) {
      throw Exception(
        'Maximum number of simultaneous plans ($maxSimultaneousPlans) reached',
      );
    }

    return copyWith(plans: [...plans, plan], lastUpdated: DateTime.now());
  }

  ReadingPlanManager updatePlan(ReadingPlan updatedPlan) {
    final updatedPlans = plans.map((plan) {
      return plan.id == updatedPlan.id ? updatedPlan : plan;
    }).toList();

    return copyWith(plans: updatedPlans, lastUpdated: DateTime.now());
  }

  ReadingPlanManager removePlan(String planId) {
    return copyWith(
      plans: plans.where((plan) => plan.id != planId).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  ReadingPlanManager markReadToday() {
    return copyWith(hasReadAnythingToday: true, lastUpdated: DateTime.now());
  }

  ReadingPlanManager copyWith({
    List<ReadingPlan>? plans,
    DateTime? lastUpdated,
    bool? hasReadAnythingToday,
    DateTime? lastResetDate,
  }) {
    return ReadingPlanManager(
      plans: plans ?? this.plans,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      hasReadAnythingToday: hasReadAnythingToday ?? this.hasReadAnythingToday,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plans': plans.map((plan) => plan.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'hasReadAnythingToday': hasReadAnythingToday,
      'lastResetDate': lastResetDate.toIso8601String(),
    };
  }

  factory ReadingPlanManager.fromJson(Map<String, dynamic> json) {
    final lastUpdated = DateTime.parse(json['lastUpdated']);
    return ReadingPlanManager(
      plans: (json['plans'] as List)
          .map((planJson) => ReadingPlan.fromJson(planJson))
          .toList(),
      lastUpdated: lastUpdated,
      hasReadAnythingToday: json['hasReadAnythingToday'] ?? false,
      lastResetDate: json['lastResetDate'] != null
          ? _normalizeToMidnight(DateTime.parse(json['lastResetDate']))
          : _normalizeToMidnight(lastUpdated),
    );
  }

  /// Check if we need to reset daily status (new day detected)
  bool get needsDailyReset {
    final now = DateTime.now();
    final resetDate = DateTime(
      lastResetDate.year,
      lastResetDate.month,
      lastResetDate.day,
    );
    final currentDate = DateTime(now.year, now.month, now.day);
    return currentDate.isAfter(resetDate);
  }
}
