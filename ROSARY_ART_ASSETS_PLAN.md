# Rosary Mystery Art Assets Implementation Plan

## Current Status
- ✅ `showImagery` setting exists in RosarySettings (but not implemented)
- ✅ Image container structure ready in prayer screen UI
- ❌ No mystery images currently available
- ❌ No asset directory structure for images

## Art Asset Options

### **Option 1: Public Domain Religious Art** ⭐ (RECOMMENDED)

**Sources:**
- **Wikimedia Commons** - Public domain Catholic art
- **The Metropolitan Museum of Art** - Open access collection
- **Google Arts & Culture** - High-resolution religious paintings
- **Internet Archive** - Digitized classical religious art

**Specific Artworks by Mystery:**

**Joyful Mysteries:**
1. **Annunciation** - Fra Angelico's "Annunciation" (1430-1432)
2. **Visitation** - Giotto's "Visitation" (1305-1306)
3. **Nativity** - Giotto's "Nativity" (1305-1306)
4. **Presentation** - Unknown master, "Presentation in the Temple"
5. **Finding in Temple** - "Jesus Among the Doctors" (various artists)

**Sorrowful Mysteries:**
1. **Agony in Garden** - Andrea Mantegna's "Agony in the Garden" (1459)
2. **Scourging at Pillar** - "Flagellation of Christ" (various masters)
3. **Crowning with Thorns** - Titian's "Crowning with Thorns" (1543)
4. **Carrying Cross** - Tintoretto's "Christ Carrying the Cross"
5. **Crucifixion** - Giotto's "Crucifixion" (1305-1306)

**Glorious Mysteries:**
1. **Resurrection** - Piero della Francesca's "Resurrection" (1460)
2. **Ascension** - Garofalo's "Ascension of Christ" (1520)
3. **Descent of Holy Spirit** - Titian's "Pentecost" (1545)
4. **Assumption** - Titian's "Assumption of the Virgin" (1518)
5. **Coronation** - "Coronation of the Virgin" (various masters)

**Luminous Mysteries:**
1. **Baptism** - Piero della Francesca's "Baptism of Christ" (1450)
2. **Wedding at Cana** - Giotto's "Marriage at Cana" (1305-1306)
3. **Proclamation of Kingdom** - "Sermon on the Mount" artworks
4. **Transfiguration** - Raphael's "Transfiguration" (1520)
5. **Eucharist/Last Supper** - Da Vinci's "Last Supper" (1498)

### **Option 2: SVG Icon Style** (MODERN ALTERNATIVE)

**Features:**
- Simple, clean vector illustrations
- Scalable to any size
- Work well with Material Design
- Consistent visual style
- Smaller file sizes (~10-50KB each vs 200-500KB for paintings)

**Style Options:**
- Stained glass window patterns
- Minimalist line art with liturgical colors
- Geometric/iconographic representations
- Flat design with traditional symbols

### **Option 3: Commission Custom Artwork** (FUTURE)

## Technical Implementation

### **File Structure**
```
sancta_via_rosary_companion/
assets/
├── app_icon.png
├── images/
│   └── mysteries/
│       ├── joyful/
│       │   ├── 1-annunciation.jpg
│       │   ├── 2-visitation.jpg
│       │   ├── 3-nativity.jpg
│       │   ├── 4-presentation.jpg
│       │   └── 5-finding-temple.jpg
│       ├── sorrowful/
│       │   ├── 1-agony-garden.jpg
│       │   ├── 2-scourging-pillar.jpg
│       │   ├── 3-crowning-thorns.jpg
│       │   ├── 4-carrying-cross.jpg
│       │   └── 5-crucifixion.jpg
│       ├── glorious/
│       │   ├── 1-resurrection.jpg
│       │   ├── 2-ascension.jpg
│       │   ├── 3-pentecost.jpg
│       │   ├── 4-assumption.jpg
│       │   └── 5-coronation.jpg
│       └── luminous/
│           ├── 1-baptism.jpg
│           ├── 2-wedding-cana.jpg
│           ├── 3-proclamation-kingdom.jpg
│           ├── 4-transfiguration.jpg
│           └── 5-eucharist.jpg
└── data/
    ├── mysteries.json
    └── prayers.json
```

### **pubspec.yaml Updates**
```yaml
flutter:
  assets:
    - assets/data/
    - assets/images/mysteries/joyful/
    - assets/images/mysteries/sorrowful/
    - assets/images/mysteries/glorious/
    - assets/images/mysteries/luminous/
```

### **Model Updates**
Add image path to `RosaryMystery` model:
```dart
class RosaryMystery {
  final String imagePath; // Add this field
  // ... existing fields
}
```

Update `mysteries.json` to include image references:
```json
{
  "mysteries": [
    {
      "id": "joyful-1",
      "type": "joyful",
      "mystery_number": 1,
      "title": "The Annunciation",
      "description": "...",
      "scripture_text": "...",
      "meditation_text": "...",
      "image_path": "assets/images/mysteries/joyful/1-annunciation.jpg"
    }
  ]
}
```

### **UI Integration**
Update `rosary_prayer_screen.dart` to display images:
```dart
// In the mystery display Card
if (currentMystery.imagePath != null && settings.showImagery) {
  Image.asset(
    currentMystery.imagePath!,
    height: 200,
    fit: BoxFit.cover,
  ),
  const SizedBox(height: 12),
}
```

## Implementation Steps

### **Phase 1: Asset Collection** (1-2 hours)
1. Download public domain artworks from Wikimedia Commons
2. Resize and optimize images (800x600 or similar, ~200-300KB each)
3. Organize into proper directory structure
4. Ensure all images are clearly public domain

### **Phase 2: Technical Integration** (30 minutes)
1. Add assets to pubspec.yaml
2. Update `mysteries.json` with image paths
3. Add `imagePath` field to `RosaryMystery` model
4. Update repository to handle new field
5. Update database schema to store image paths

### **Phase 3: UI Implementation** (30 minutes)
1. Update `rosary_prayer_screen.dart` to display images
2. Add proper loading states and fallbacks
3. Ensure images respect `showImagery` setting
4. Add proper error handling for missing images

### **Phase 4: Testing** (15 minutes)
1. Test all 4 mystery types display correct images
2. Verify image loading with different network conditions
3. Test toggle functionality of `showImagery` setting
4. Check app bundle size impact

## Considerations

### **Licensing** ✅
- All suggested artworks are public domain (pre-1927)
- Wikimedia Commons clearly marks public domain works
- No attribution required for public domain art

### **File Size** ⚠️
- 20 images × ~300KB = ~6MB additional app size
- Consider WebP format for better compression
- Potential for downloadable content in future versions

### **Accessibility** ✅
- All images will have alt text from mystery descriptions
- Screen reader compatible
- High contrast when needed

### **Cultural Sensitivity** ✅
- Traditional Catholic art is appropriate for this audience
- Avoids modern/controversial interpretations
- Respects traditional iconography

## Recommendation

**Start with Option 1 (Public Domain Art)** because:
- ✅ Legally safe (public domain)
- ✅ Authentic traditional Catholic art
- ✅ High visual impact
- ✅ Free to use
- ✅ Quick to implement

**Next Steps:**
1. Let me know if you'd like me to proceed with collecting public domain artworks
2. I can download and organize the first mystery set (Joyful) as a proof of concept
3. Then we can implement the technical integration

Would you like me to proceed with downloading some public domain mystery artworks to get started?