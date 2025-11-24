#!/bin/bash
cd /Users/jason/Repos/SanctaVia/sancta_via_bible_reading_app
flutter analyze > analysis_output.txt 2>&1
cat analysis_output.txt
