#!/bin/bash

# Prayer metadata migration script
# Consolidates prayer metadata into individual prayer files

echo "🙏 Starting prayer metadata consolidation..."

METADATA_FILE="assets/prayers/prayers_metadata.json"
PRAYERS_DIR="assets/prayers"

if [ ! -f "$METADATA_FILE" ]; then
    echo "❌ Error: prayers_metadata.json not found"
    exit 1
fi

# Check if required tools are available
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed"
    echo "   Install with: brew install jq (macOS) or apt install jq (Ubuntu)"
    exit 1
fi

echo "📋 Processing prayers..."

# Read metadata and process each prayer
jq -r '.prayers[] | @base64' "$METADATA_FILE" | while read -r prayer_meta; do
    # Decode the base64 prayer metadata
    prayer_json=$(echo "$prayer_meta" | base64 --decode)
    
    # Extract fields
    fileName=$(echo "$prayer_json" | jq -r '.fileName')
    id=$(echo "$prayer_json" | jq -r '.id')
    categories=$(echo "$prayer_json" | jq -c '.categories')
    description=$(echo "$prayer_json" | jq -r '.description')
    tags=$(echo "$prayer_json" | jq -c '.tags')
    isLiturgical=$(echo "$prayer_json" | jq '.isLiturgical')
    liturgicalPriority=$(echo "$prayer_json" | jq '.liturgicalPriority')
    liturgicalSeason=$(echo "$prayer_json" | jq '.liturgicalSeason')
    
    prayer_file="$PRAYERS_DIR/$fileName"
    
    if [ ! -f "$prayer_file" ]; then
        echo "⚠️  Warning: Prayer file $fileName not found, skipping..."
        continue
    fi
    
    # Create temporary file with updated content
    temp_file=$(mktemp)
    
    # Merge existing prayer data with metadata
    jq --argjson categories "$categories" \
       --arg description "$description" \
       --argjson tags "$tags" \
       --argjson isLiturgical "$isLiturgical" \
       --argjson liturgicalPriority "$liturgicalPriority" \
       --argjson liturgicalSeason "$liturgicalSeason" \
       '. + {
         categories: $categories,
         description: $description,
         tags: $tags,
         isLiturgical: $isLiturgical,
         liturgicalPriority: $liturgicalPriority,
         liturgicalSeason: $liturgicalSeason
       }' "$prayer_file" > "$temp_file"
    
    # Replace original file with updated content
    mv "$temp_file" "$prayer_file"
    
    echo "✅ Updated $fileName"
done

echo ""
echo "🎉 Migration complete!"
echo "🗑️  You can now safely delete prayers_metadata.json"
echo "   The metadata has been consolidated into individual prayer files."
