import '../models/models.dart';
import '../utils/logger.dart';

/// Repository for rosary data access.
///
/// Provides hardcoded prayers and mystery data with built-in caching.
/// No database required - all data is in-memory.
///
/// Usage:
/// ```dart
/// final repository = RosaryRepository.instance;
/// final prayers = await repository.getPrayers();
/// final mysteries = await repository.getMysteries(MysterySet.joyful);
/// ```
class RosaryRepository {
  // Singleton pattern
  static final RosaryRepository _instance = RosaryRepository._internal();
  static RosaryRepository get instance => _instance;

  RosaryRepository._internal();

  // Caches
  List<RosaryPrayer>? _cachedPrayers;
  List<Mystery>? _cachedMysteries;

  // =============================================================================
  // PRAYER DATA
  // =============================================================================

  /// Get all rosary prayers (Sign of Cross, Creed, Our Father, Hail Mary, etc.)
  List<RosaryPrayer> getPrayers() {
    if (_cachedPrayers != null) {
      return _cachedPrayers!;
    }

    try {
      _cachedPrayers = _loadPrayers();
      AppLogger.info('Loaded ${_cachedPrayers!.length} rosary prayers', 'REPO');
      return _cachedPrayers!;
    } catch (e) {
      AppLogger.error('Error loading prayers', e, null, 'REPO');
      return [];
    }
  }

  /// Load all prayers from hardcoded data
  List<RosaryPrayer> _loadPrayers() {
    return [
      // Opening Prayers
      const RosaryPrayer(
        id: 'sign-of-cross',
        title: 'Sign of the Cross',
        text:
            'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
        type: PrayerType.signOfCross,
        sequenceOrder: 1,
      ),
      const RosaryPrayer(
        id: 'apostles-creed',
        title: 'Apostles\' Creed',
        text:
            '''I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; he descended into hell; on the third day he rose again from the dead; he ascended into heaven, and is seated at the right hand of God the Father almighty; from there he will come to judge the living and the dead. I believe in the Holy Spirit, the holy catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.''',
        type: PrayerType.apostlesCreed,
        sequenceOrder: 2,
      ),
      const RosaryPrayer(
        id: 'our-father-opening',
        title: 'Our Father',
        description: 'On the first bead',
        text:
            '''Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.''',
        type: PrayerType.openingOurFather,
        sequenceOrder: 3,
      ),
      const RosaryPrayer(
        id: 'hail-mary-opening',
        title: 'Hail Mary (x3)',
        description: 'On the next three beads (for Faith, Hope, and Charity)',
        text: '',
        type: PrayerType.openingHailMary,
        sequenceOrder: 4,
        partialStart:
            'Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women and blessed is the fruit of thy womb, Jesus.',
        partialRepeat:
            'Holy Mary, Mother of God, pray for us sinners now and at the hour of our death. Amen.',
        partialEnd: '',
        repeatCount: 3,
      ),
      const RosaryPrayer(
        id: 'glory-be-opening',
        title: 'Glory Be',
        text:
            'Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.',
        type: PrayerType.gloryBe,
        sequenceOrder: 5,
      ),

      // Per-decade prayers
      const RosaryPrayer(
        id: 'our-father',
        title: 'Our Father',
        description: 'Before each decade',
        text:
            '''Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.''',
        type: PrayerType.ourFather,
      ),
      const RosaryPrayer(
        id: 'hail-mary',
        title: 'Hail Mary',
        description: 'Ten per decade',
        text: '',
        type: PrayerType.hailMary,
        partialStart:
            'Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women and blessed is the fruit of thy womb, Jesus.',
        partialRepeat:
            'Holy Mary, Mother of God, pray for us sinners now and at the hour of our death. Amen.',
        partialEnd: '',
        repeatCount: 10,
      ),
      const RosaryPrayer(
        id: 'glory-be',
        title: 'Glory Be',
        description: 'After each decade',
        text:
            'Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.',
        type: PrayerType.gloryBe,
      ),
      const RosaryPrayer(
        id: 'fatima-prayer',
        title: 'O My Jesus',
        description: 'Fatima Prayer (optional, after each Glory Be)',
        text:
            'O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those in most need of Thy mercy. Amen.',
        type: PrayerType.fatimaPrayer,
      ),

      // Closing Prayers
      const RosaryPrayer(
        id: 'hail-holy-queen',
        title: 'Hail Holy Queen',
        text:
            '''Hail Holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious advocate, thine eyes of mercy toward us, and after this, our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary.

V. Pray for us, O holy Mother of God.
R. That we may be made worthy of the promises of Christ.''',
        type: PrayerType.closing,
        sequenceOrder: 6,
      ),
      const RosaryPrayer(
        id: 'closing-prayer',
        title: 'Let Us Pray',
        text:
            'Let us pray. O God, whose only begotten Son, by His life, death, and resurrection, has purchased for us the rewards of eternal life, grant, we beseech Thee, that meditating upon these mysteries of the Most Holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise, through the same Christ Our Lord. Amen.',
        type: PrayerType.closing,
        sequenceOrder: 7,
      ),
    ];
  }

  // =============================================================================
  // MYSTERY DATA
  // =============================================================================

  /// Get all 20 mysteries
  List<Mystery> getAllMysteries() {
    if (_cachedMysteries != null) {
      return _cachedMysteries!;
    }

    try {
      _cachedMysteries = _loadAllMysteries();
      AppLogger.info('Loaded ${_cachedMysteries!.length} mysteries', 'REPO');
      return _cachedMysteries!;
    } catch (e) {
      AppLogger.error('Error loading mysteries', e, null, 'REPO');
      return [];
    }
  }

  /// Get 5 mysteries for a specific set
  List<Mystery> getMysteries(MysterySet set) {
    try {
      final allMysteries = getAllMysteries();
      final filtered = allMysteries.where((m) => m.mysterySet == set).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

      AppLogger.info(
        'Retrieved ${filtered.length} mysteries for ${set.displayName}',
        'REPO',
      );
      return filtered;
    } catch (e) {
      AppLogger.error(
        'Error getting mysteries for ${set.displayName}',
        e,
        null,
        'REPO',
      );
      return [];
    }
  }

  /// Get the mystery set recommended for a specific weekday
  /// 1 = Monday, 7 = Sunday
  MysterySet getMysteryForDay(int weekday) {
    final set = MysterySet.forWeekday(weekday);
    AppLogger.info('Mystery for weekday $weekday: ${set.displayName}', 'REPO');
    return set;
  }

  /// Get mystery set for today
  MysterySet getMysteryForToday() {
    return getMysteryForDay(DateTime.now().weekday);
  }

  /// Load all 20 mysteries from hardcoded data
  List<Mystery> _loadAllMysteries() {
    return [
      // Joyful Mysteries
      const Mystery(
        id: 'joyful-1',
        name: 'The Annunciation',
        mysterySet: MysterySet.joyful,
        number: 1,
        fruit: 'Humility',
        scripture: 'Luke 1:26-38',
        description:
            'The Angel Gabriel announces to Mary that she will conceive and bear the Son of God.',
        extendedMeditation:
            'Consider Mary\'s humility and willingness to accept God\'s will, responding "Be it done unto me according to thy word."',
      ),
      const Mystery(
        id: 'joyful-2',
        name: 'The Visitation',
        mysterySet: MysterySet.joyful,
        number: 2,
        fruit: 'Love of Neighbor',
        scripture: 'Luke 1:39-56',
        description:
            'Mary visits her cousin Elizabeth, who is also miraculously pregnant with John the Baptist.',
        extendedMeditation:
            'Mary\'s concern for others led her to help Elizabeth. Consider how you can serve those in need.',
      ),
      const Mystery(
        id: 'joyful-3',
        name: 'The Nativity',
        mysterySet: MysterySet.joyful,
        number: 3,
        fruit: 'Poverty of Spirit',
        scripture: 'Luke 2:1-20',
        description: 'Jesus is born in Bethlehem and laid in a manger.',
        extendedMeditation:
            'The Son of God chose to be born in poverty. Consider detachment from material things and trust in God\'s providence.',
      ),
      const Mystery(
        id: 'joyful-4',
        name: 'The Presentation',
        mysterySet: MysterySet.joyful,
        number: 4,
        fruit: 'Obedience',
        scripture: 'Luke 2:22-38',
        description:
            'Mary and Joseph present Jesus in the Temple according to Jewish law.',
        extendedMeditation:
            'Mary and Joseph faithfully observed God\'s law. Consider your own obedience to God\'s commands.',
      ),
      const Mystery(
        id: 'joyful-5',
        name: 'The Finding in the Temple',
        mysterySet: MysterySet.joyful,
        number: 5,
        fruit: 'Joy in Finding Jesus',
        scripture: 'Luke 2:41-52',
        description:
            'After three days of searching, Mary and Joseph find Jesus in the Temple.',
        extendedMeditation:
            'The anxiety of separation was replaced by joy. Consider how you can seek Jesus more diligently in your life.',
      ),

      // Sorrowful Mysteries
      const Mystery(
        id: 'sorrowful-1',
        name: 'The Agony in the Garden',
        mysterySet: MysterySet.sorrowful,
        number: 1,
        fruit: 'Contrition',
        scripture: 'Matthew 26:36-46',
        description:
            'Jesus prays in Gethsemane, sweating blood as He accepts the Father\'s will.',
        extendedMeditation:
            'Jesus suffered for our sins. Consider your own sins and ask for forgiveness with true contrition.',
      ),
      const Mystery(
        id: 'sorrowful-2',
        name: 'The Scourging at the Pillar',
        mysterySet: MysterySet.sorrowful,
        number: 2,
        fruit: 'Purity',
        scripture: 'Matthew 27:26',
        description: 'Jesus is whipped and scourged before His crucifixion.',
        extendedMeditation:
            'Christ suffered bodily for our sins. Consider how you can practice purity in thought, word, and deed.',
      ),
      const Mystery(
        id: 'sorrowful-3',
        name: 'The Crowning with Thorns',
        mysterySet: MysterySet.sorrowful,
        number: 3,
        fruit: 'Moral Courage',
        scripture: 'Matthew 27:27-31',
        description:
            'Jesus is mocked and crowned with thorns as "King of the Jews."',
        extendedMeditation:
            'Christ endured mockery for our sake. Consider how you can stand firm in your faith despite ridicule.',
      ),
      const Mystery(
        id: 'sorrowful-4',
        name: 'The Carrying of the Cross',
        mysterySet: MysterySet.sorrowful,
        number: 4,
        fruit: 'Patience',
        scripture: 'John 19:17',
        description:
            'Jesus carries His cross to Calvary, meeting His mother along the way.',
        extendedMeditation:
            'Christ carried the cross for our salvation. Consider how you can patiently bear your own crosses.',
      ),
      const Mystery(
        id: 'sorrowful-5',
        name: 'The Crucifixion',
        mysterySet: MysterySet.sorrowful,
        number: 5,
        fruit: 'Final Perseverance',
        scripture: 'Luke 23:33-46',
        description: 'Jesus dies on the cross for the salvation of the world.',
        extendedMeditation:
            'Christ gave His life for us. Consider how you can persevere in faith until the end.',
      ),

      // Glorious Mysteries
      const Mystery(
        id: 'glorious-1',
        name: 'The Resurrection',
        mysterySet: MysterySet.glorious,
        number: 1,
        fruit: 'Faith',
        scripture: 'Matthew 28:1-10',
        description:
            'Jesus rises from the dead on the third day, conquering death.',
        extendedMeditation:
            'Christ\'s resurrection gives us hope. Strengthen your faith in His promise of eternal life.',
      ),
      const Mystery(
        id: 'glorious-2',
        name: 'The Ascension',
        mysterySet: MysterySet.glorious,
        number: 2,
        fruit: 'Hope',
        scripture: 'Luke 24:50-53',
        description:
            'Jesus ascends into heaven and sits at the right hand of the Father.',
        extendedMeditation:
            'Christ has gone to prepare a place for us. Live in hope of heavenly glory.',
      ),
      const Mystery(
        id: 'glorious-3',
        name: 'The Descent of the Holy Spirit',
        mysterySet: MysterySet.glorious,
        number: 3,
        fruit: 'Love of God',
        scripture: 'Acts 2:1-4',
        description: 'The Holy Spirit descends upon the Apostles at Pentecost.',
        extendedMeditation:
            'The Spirit fills us with God\'s love. Open your heart to the Spirit\'s gifts and guidance.',
      ),
      const Mystery(
        id: 'glorious-4',
        name: 'The Assumption',
        mysterySet: MysterySet.glorious,
        number: 4,
        fruit: 'Grace of a Happy Death',
        scripture: 'Revelation 12:1',
        description: 'Mary is assumed body and soul into heaven.',
        extendedMeditation:
            'Mary was taken to heaven as a model for us. Pray for the grace of a holy death.',
      ),
      const Mystery(
        id: 'glorious-5',
        name: 'The Coronation',
        mysterySet: MysterySet.glorious,
        number: 5,
        fruit: 'Trust in Mary\'s Intercession',
        scripture: 'Revelation 12:1',
        description: 'Mary is crowned Queen of Heaven and Earth.',
        extendedMeditation:
            'Mary reigns as Queen and intercedes for us. Trust in her powerful prayers.',
      ),

      // Luminous Mysteries
      const Mystery(
        id: 'luminous-1',
        name: 'The Baptism in the Jordan',
        mysterySet: MysterySet.luminous,
        number: 1,
        fruit: 'Openness to the Holy Spirit',
        scripture: 'Matthew 3:13-17',
        description: 'Jesus is baptized by John in the Jordan River.',
        extendedMeditation:
            'The Spirit descended upon Jesus at His baptism. Be open to the Spirit\'s work in your life.',
      ),
      const Mystery(
        id: 'luminous-2',
        name: 'The Wedding at Cana',
        mysterySet: MysterySet.luminous,
        number: 2,
        fruit: 'To Jesus Through Mary',
        scripture: 'John 2:1-12',
        description:
            'At Mary\'s request, Jesus performs His first miracle at Cana.',
        extendedMeditation:
            'Mary interceded for the wedding couple. Bring your needs to Jesus through Mary\'s intercession.',
      ),
      const Mystery(
        id: 'luminous-3',
        name: 'The Proclamation of the Kingdom',
        mysterySet: MysterySet.luminous,
        number: 3,
        fruit: 'Repentance and Trust in God',
        scripture: 'Mark 1:14-15',
        description: 'Jesus preaches the Gospel and calls for repentance.',
        extendedMeditation:
            'Christ invites us to enter His Kingdom. Turn from sin and trust completely in God\'s mercy.',
      ),
      const Mystery(
        id: 'luminous-4',
        name: 'The Transfiguration',
        mysterySet: MysterySet.luminous,
        number: 4,
        fruit: 'Desire for Holiness',
        scripture: 'Matthew 17:1-9',
        description:
            'Jesus is transfigured before Peter, James, and John on Mount Tabor.',
        extendedMeditation:
            'Christ revealed His divine glory. Seek to be transformed into His likeness through prayer.',
      ),
      const Mystery(
        id: 'luminous-5',
        name: 'The Institution of the Eucharist',
        mysterySet: MysterySet.luminous,
        number: 5,
        fruit: 'Adoration',
        scripture: 'Matthew 26:26-29',
        description: 'Jesus institutes the Eucharist at the Last Supper.',
        extendedMeditation:
            'Christ gave us His Body and Blood in the Eucharist. Grow in love and reverence for this great gift.',
      ),
    ];
  }

  /// Clear all caches to force fresh data
  void clearCache() {
    _cachedPrayers = null;
    _cachedMysteries = null;
    AppLogger.info('Rosary repository cache cleared', 'REPO');
  }
}
