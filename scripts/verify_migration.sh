#!/bin/bash
set -e

echo "🔍 Running Flutter analysis to verify fixes..."
cd /Users/jason/Repos/SanctaVia/sancta_via_prayer_companion

# Run flutter analyze
if flutter analyze; then
    echo "✅ Analysis passed! No compilation errors found."
    echo "🎉 Migration appears to be successful!"
    
    echo ""
    echo "Next steps:"
    echo "1. Test the app: flutter run"
    echo "2. If working, delete: rm assets/prayers/prayers_metadata.json"
    echo "3. Optional cleanup: rm lib/models/prayer_metadata.dart"
else
    echo "❌ Analysis failed. There are still issues to fix."
    exit 1
fi
