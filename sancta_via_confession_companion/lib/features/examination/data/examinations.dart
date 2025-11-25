import '../models/examination_model.dart';

// Sample examination data
final List<ExaminationModel> sampleExaminations = [
  ExaminationModel(
    id: 'ten-commandments',
    title: 'Traditional Examination Based on Ten Commandments',
    description:
        'A thorough examination of conscience based on the Ten Commandments, suitable for adults preparing for confession.',
    source: 'Traditional Catholic Examination',
    targetAudience: 'Adults',
    categories: [
      ExaminationCategory(
        title:
            'First Commandment: "I am the Lord your God, you shall not have strange gods before me."',
        description:
            'This commandment asks us to put God first in our lives and to avoid idolatry in all its forms.',
        items: [
          ExaminationItem(
            text: 'Have I neglected to pray daily?',
            clarification:
                'Prayer is our lifeline to God. Daily prayer helps us maintain our relationship with Him.',
          ),
          ExaminationItem(text: 'Have I denied or doubted God\'s existence?'),
          ExaminationItem(
            text:
                'Have I dabbled in occult practices, horoscopes, or superstitions?',
            clarification:
                'These practices attribute power to created things rather than to God, the Creator.',
          ),
          ExaminationItem(
            text:
                'Have I made material possessions, achievements, relationships, or pleasure more important than God?',
          ),
          ExaminationItem(text: 'Have I been lukewarm in my faith?'),
          ExaminationItem(
            text: 'Have I presumed on God\'s mercy by sinning deliberately?',
          ),
          ExaminationItem(text: 'Have I despaired of God\'s mercy?'),
        ],
      ),
      ExaminationCategory(
        title:
            'Second Commandment: "You shall not take the name of the Lord your God in vain."',
        description:
            'This commandment requires us to show respect for God\'s name and avoid misusing it.',
        items: [
          ExaminationItem(
            text: 'Have I used God\'s name carelessly or in anger?',
          ),
          ExaminationItem(
            text:
                'Have I used Jesus\' name as an expression of surprise or anger rather than in prayer?',
          ),
          ExaminationItem(
            text:
                'Have I spoken irreverently about God, saints, or sacred things?',
          ),
          ExaminationItem(text: 'Have I used profane or vulgar language?'),
          ExaminationItem(
            text: 'Have I made promises in God\'s name that I didn\'t keep?',
          ),
        ],
      ),
      // Add more commandments and categories as needed
    ],
  ),

  ExaminationModel(
    id: 'st-francis-de-sales',
    title: 'St. Francis de Sales Examination',
    description:
        'A gentle but thorough examination focusing on everyday virtues and habits, based on the spirituality of St. Francis de Sales.',
    source: 'St. Francis de Sales',
    targetAudience: 'All Catholics',
    categories: [
      ExaminationCategory(
        title: 'Relationship with God',
        items: [
          ExaminationItem(
            text: 'Have I failed to thank God for His blessings?',
          ),
          ExaminationItem(
            text: 'Have I neglected prayer or spiritual reading?',
          ),
          ExaminationItem(
            text:
                'Have I received Holy Communion without proper reverence or thanksgiving?',
          ),
          ExaminationItem(
            text: 'Have I been distracted in prayer by worldly concerns?',
          ),
        ],
      ),
      ExaminationCategory(
        title: 'Charity Toward Others',
        items: [
          ExaminationItem(
            text: 'Have I failed to be kind and considerate to others?',
          ),
          ExaminationItem(
            text: 'Have I spoken unkindly about others in their absence?',
          ),
          ExaminationItem(text: 'Have I judged others harshly in my thoughts?'),
          ExaminationItem(
            text:
                'Have I neglected to help those in need when I could have done so?',
          ),
          ExaminationItem(
            text:
                'Have I been impatient with the faults and limitations of others?',
          ),
        ],
      ),
      // Add more categories as needed
    ],
  ),

  ExaminationModel(
    id: 'children',
    title: 'Examination for Children',
    description:
        'A simplified examination of conscience designed specifically for children preparing for confession, using age-appropriate language.',
    source: 'Adapted for Children',
    targetAudience: 'Children',
    categories: [
      ExaminationCategory(
        title: 'My Relationship with God',
        items: [
          ExaminationItem(text: 'Did I forget to pray to God?'),
          ExaminationItem(
            text: 'Did I miss Mass on Sunday or not pay attention during Mass?',
          ),
          ExaminationItem(
            text:
                'Did I use God\'s name without respect or say it when I was angry?',
          ),
        ],
      ),
      ExaminationCategory(
        title: 'My Relationship with Family',
        items: [
          ExaminationItem(text: 'Did I disobey my parents or teachers?'),
          ExaminationItem(
            text: 'Did I speak disrespectfully to my parents or other adults?',
          ),
          ExaminationItem(text: 'Did I fight with my brothers or sisters?'),
          ExaminationItem(text: 'Did I refuse to help with chores when asked?'),
        ],
      ),
      ExaminationCategory(
        title: 'My Relationship with Others',
        items: [
          ExaminationItem(text: 'Did I hurt anyone by what I said or did?'),
          ExaminationItem(text: 'Did I say mean things about other people?'),
          ExaminationItem(
            text: 'Did I leave someone out of games or activities on purpose?',
          ),
          ExaminationItem(text: 'Did I lie to someone?'),
          ExaminationItem(text: 'Did I take something that wasn\'t mine?'),
          ExaminationItem(text: 'Did I refuse to share my things with others?'),
        ],
      ),
    ],
  ),
];
