# Development Resources

This directory contains resources that are used during development but are **NOT** shipped with the app.

## 📁 Structure

### `bibles/` Directory
Contains compressed Bible translation files (`.json.gz` format):
- `cpdv.json.gz` - Catholic Public Domain Version
- `drc.json.gz` - Douay-Rheims Catholic Bible  
- `engwebc.json.gz` - English Web Bible Catholic

## 🚫 **Important: These files are NOT shipped with the app!**

The app uses a pre-built SQLite database (`assets/bibles.db`) for all Bible content at runtime. These compressed files serve the following purposes:

### **Development Uses:**
1. **Source of truth** - Original Bible text data
2. **Database rebuilding** - Can be decompressed to rebuild the SQLite database
3. **Version control** - Compact storage in Git repository
4. **Development testing** - Testing compression/decompression functionality

### **Compression Script Usage:**

```bash
# Compress all JSON files (requires uncompressed .json files in this directory)
./scripts/compress_bibles.sh

# Decompress a specific file for editing
./scripts/compress_bibles.sh decompress cpdv.json.gz
```

## 🔧 **Database Rebuilding Workflow:**

If you need to rebuild the SQLite database from these sources:

1. **Decompress the files:**
   ```bash
   cd dev_resources/bibles
   gunzip -k *.gz  # Keep originals, create .json files
   ```

2. **Use your Bible data package tools** to rebuild `assets/bibles.db`

3. **Clean up temporary files:**
   ```bash
   rm *.json  # Remove decompressed files, keep .gz originals
   ```

## 📦 **App Bundle Size Savings:**

By moving these files out of the app bundle:
- **Removed ~5.5MB** of compressed Bible data from app downloads
- **Kept ~25.7MB** of uncompressed data out of app bundle
- **Total savings: ~82%** reduction in Bible-related asset size

The app still provides the same functionality using the optimized SQLite database (`~500KB` vs `~12MB` for full Bible loading).

## ⚠️ **Do Not Delete:**

These files are the source of truth for Bible translations. If lost, you would need to re-obtain the original Bible text data to rebuild the database.
