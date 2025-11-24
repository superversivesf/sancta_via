#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Starting Monorepo Migration...${NC}"

# 1. Initialize Git if not already initialized
if [ ! -d ".git" ]; then
    echo -e "${GREEN}Initializing root git repository...${NC}"
    git init
else
    echo -e "${BLUE}Root git repository already exists.${NC}"
fi

# 2. Commit root configuration files
echo -e "${GREEN}Committing root configuration files...${NC}"
git add .gitignore melos.yaml pubspec.yaml *.md *.sh 2>/dev/null || true
# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No root changes to commit."
else
    git commit -m "chore: setup monorepo structure"
fi

# 3. Migrate Repositories
# List of directories that are expected to be git repos
repos=(
  "sancta_via_bible_data"
  "sancta_via_bible_data_riverpod"
  "sancta_via_bible_reading_app"
  "sancta_via_confession_companion"
  "sancta_via_liturgical_calendar"
  "sancta_via_liturgical_calendar_app"
  "sancta_via_liturgical_calendar_riverpod"
  "sancta_via_novena_companion"
  "sancta_via_prayer_companion"
  "sancta_via_scripts"
  "sancta_via_shared_ui"
)

for repo in "${repos[@]}"; do
    if [ -d "$repo" ]; then
        if [ -d "$repo/.git" ]; then
            echo -e "${BLUE}Migrating $repo...${NC}"
            
            # Detect branch
            branch=$(git -C "$repo" branch --show-current)
            if [ -z "$branch" ]; then
                branch="main" 
                echo -e "  Defaulting to branch 'main'"
            else
                echo -e "  Detected branch '$branch'"
            fi
            
            # Rename folder to avoid conflict (subtree add wants to create the folder)
            mv "$repo" "${repo}_temp"
            
            # Add subtree
            echo -e "  Importing history..."
            if git subtree add --prefix="$repo" "./${repo}_temp" "$branch"; then
                echo -e "${GREEN}  ✓ Success${NC}"
                rm -rf "${repo}_temp"
            else
                echo -e "${RED}  ✗ Failed to add subtree for $repo${NC}"
                echo "  Restoring folder..."
                mv "${repo}_temp" "$repo"
                exit 1
            fi
        else
            echo -e "${BLUE}Skipping $repo (Not a git repository)${NC}"
            # If it's just a folder, we add it as normal files
            git add "$repo"
            git commit -m "feat: add $repo (non-git)" || true
        fi
    fi
done

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run 'dart pub get'"
echo "2. Run 'melos bootstrap'"
