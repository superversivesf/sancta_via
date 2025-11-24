#!/bin/bash

# Script to check git status of all Flutter projects in SanctaVia directory
# Usage: ./check-git-status.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directory containing all projects
BASE_DIR="/Users/jason/Repos/SanctaVia"

echo -e "${BLUE}=== Git Status Check for SanctaVia Projects ===${NC}"
echo -e "${BLUE}Checking projects in: $BASE_DIR${NC}"
echo ""

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}Error: Directory $BASE_DIR does not exist${NC}"
    exit 1
fi

# Counter for summary
total_projects=0
clean_projects=0
dirty_projects=0
non_git_projects=0

# Loop through all subdirectories
for project_dir in "$BASE_DIR"/*; do
    if [ -d "$project_dir" ]; then
        project_name=$(basename "$project_dir")
        total_projects=$((total_projects + 1))
        
        echo -e "${BLUE}📁 $project_name${NC}"
        echo "   Path: $project_dir"
        
        # Check if it's a git repository
        if [ ! -d "$project_dir/.git" ]; then
            echo -e "   ${YELLOW}⚠️  Not a git repository${NC}"
            non_git_projects=$((non_git_projects + 1))
            echo ""
            continue
        fi
        
        # Change to project directory and check git status
        cd "$project_dir" || continue
        
        # Get current branch
        current_branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$current_branch" ]; then
            echo -e "   ${BLUE}Branch: $current_branch${NC}"
        fi
        
        # Check if there are any changes
        if git diff-index --quiet HEAD -- 2>/dev/null; then
            # Check for untracked files
            untracked_files=$(git ls-files --others --exclude-standard)
            if [ -z "$untracked_files" ]; then
                echo -e "   ${GREEN}✅ Clean - no changes${NC}"
                clean_projects=$((clean_projects + 1))
            else
                echo -e "   ${YELLOW}📄 Has untracked files:${NC}"
                echo "$untracked_files" | sed 's/^/      /'
                dirty_projects=$((dirty_projects + 1))
            fi
        else
            echo -e "   ${RED}🔄 Has uncommitted changes:${NC}"
            
            # Show modified files
            modified_files=$(git diff --name-only HEAD)
            if [ -n "$modified_files" ]; then
                echo -e "   ${YELLOW}   Modified files:${NC}"
                echo "$modified_files" | sed 's/^/      /'
            fi
            
            # Show staged files
            staged_files=$(git diff --name-only --cached)
            if [ -n "$staged_files" ]; then
                echo -e "   ${GREEN}   Staged files:${NC}"
                echo "$staged_files" | sed 's/^/      /'
            fi
            
            # Show untracked files
            untracked_files=$(git ls-files --others --exclude-standard)
            if [ -n "$untracked_files" ]; then
                echo -e "   ${YELLOW}   Untracked files:${NC}"
                echo "$untracked_files" | sed 's/^/      /'
            fi
            
            dirty_projects=$((dirty_projects + 1))
        fi
        
        # Check if ahead/behind remote
        upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
        if [ -n "$upstream" ]; then
            ahead=$(git rev-list --count HEAD ^"$upstream" 2>/dev/null)
            behind=$(git rev-list --count "$upstream" ^HEAD 2>/dev/null)
            
            if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                echo -e "   ${YELLOW}🔄 $ahead commits ahead, $behind commits behind $upstream${NC}"
            elif [ "$ahead" -gt 0 ]; then
                echo -e "   ${YELLOW}⬆️  $ahead commits ahead of $upstream${NC}"
            elif [ "$behind" -gt 0 ]; then
                echo -e "   ${YELLOW}⬇️  $behind commits behind $upstream${NC}"
            fi
        fi
        
        echo ""
    fi
done

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total projects: $total_projects"
echo -e "${GREEN}Clean projects: $clean_projects${NC}"
echo -e "${RED}Projects with changes: $dirty_projects${NC}"
echo -e "${YELLOW}Non-git projects: $non_git_projects${NC}"

if [ $dirty_projects -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  $dirty_projects project(s) have uncommitted changes that may need attention${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ All git repositories are clean!${NC}"
    exit 0
fi
