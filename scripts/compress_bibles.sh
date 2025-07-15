#!/bin/bash

# Bible JSON Compression Script
# This script compresses Bible JSON files for the Sancta Via Bible Reading App
# to reduce app bundle size and improve download performance.

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIBLES_DIR="$PROJECT_ROOT/assets/bibles"

echo "🔄 Bible JSON Compression Script"
echo "================================="
echo "Project root: $PROJECT_ROOT"
echo "Bibles directory: $BIBLES_DIR"
echo ""

# Check if gzip is available
if ! command -v gzip &> /dev/null; then
    echo "❌ Error: gzip command not found"
    exit 1
fi

# Navigate to bibles directory
cd "$BIBLES_DIR"

# Function to compress a single JSON file
compress_file() {
    local json_file="$1"
    local gz_file="${json_file}.gz"
    
    if [[ ! -f "$json_file" ]]; then
        echo "⚠️  Warning: $json_file not found, skipping..."
        return
    fi
    
    echo "📦 Compressing $json_file..."
    
    # Get original size
    local original_size=$(wc -c < "$json_file")
    
    # Compress with maximum compression
    gzip -9 -f "$json_file"
    
    # Get compressed size
    local compressed_size=$(wc -c < "$gz_file")
    
    # Calculate compression ratio
    local savings=$((original_size - compressed_size))
    local ratio=$((savings * 100 / original_size))
    
    echo "   Original:   $(numfmt --to=iec-i --suffix=B $original_size)"
    echo "   Compressed: $(numfmt --to=iec-i --suffix=B $compressed_size)"
    echo "   Saved:      $(numfmt --to=iec-i --suffix=B $savings) (${ratio}%)"
    echo ""
}

# Function to decompress for editing
decompress_file() {
    local gz_file="$1"
    local json_file="${gz_file%.gz}"
    
    if [[ ! -f "$gz_file" ]]; then
        echo "❌ Error: $gz_file not found"
        return 1
    fi
    
    echo "📂 Decompressing $gz_file to $json_file..."
    gzip -d -k "$gz_file"
    echo "✅ Decompressed successfully"
}

# Main compression process
compress_all() {
    echo "🚀 Starting compression of all Bible JSON files..."
    echo ""
    
    # Bible translation files to compress
    local files=("cpdv.json" "drc.json" "engwebc.json")
    local total_original=0
    local total_compressed=0
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            local original_size=$(wc -c < "$file")
            total_original=$((total_original + original_size))
            
            compress_file "$file"
            
            if [[ -f "${file}.gz" ]]; then
                local compressed_size=$(wc -c < "${file}.gz")
                total_compressed=$((total_compressed + compressed_size))
            fi
        else
            echo "⚠️  $file not found, skipping..."
        fi
    done
    
    # Summary
    if [[ $total_original -gt 0 ]]; then
        local total_savings=$((total_original - total_compressed))
        local total_ratio=$((total_savings * 100 / total_original))
        
        echo "📊 Compression Summary"
        echo "====================="
        echo "Total original size:   $(numfmt --to=iec-i --suffix=B $total_original)"
        echo "Total compressed size: $(numfmt --to=iec-i --suffix=B $total_compressed)"
        echo "Total savings:         $(numfmt --to=iec-i --suffix=B $total_savings) (${total_ratio}%)"
        echo ""
        echo "✅ Compression completed successfully!"
    else
        echo "❌ No files were compressed"
        exit 1
    fi
}

# Command line argument handling
case "${1:-}" in
    "compress"|"")
        compress_all
        ;;
    "decompress")
        if [[ -z "$2" ]]; then
            echo "Usage: $0 decompress <filename.gz>"
            echo "Example: $0 decompress cpdv.json.gz"
            exit 1
        fi
        decompress_file "$2"
        ;;
    "help"|"-h"|"--help")
        echo "Bible JSON Compression Script"
        echo ""
        echo "Usage:"
        echo "  $0                    - Compress all JSON files"
        echo "  $0 compress           - Compress all JSON files"
        echo "  $0 decompress <file>  - Decompress a specific .gz file"
        echo "  $0 help               - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                           # Compress all Bible JSON files"
        echo "  $0 decompress cpdv.json.gz   # Decompress CPDV for editing"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
