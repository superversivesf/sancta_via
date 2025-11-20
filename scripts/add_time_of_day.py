#!/usr/bin/env python3
"""
Script to add timeOfDay field to all prayer JSON files.
Run from the sancta_via_prayer_companion directory.
"""

import json
import os

PRAYERS_DIR = "assets/prayers"

# Categorize prayers by time of day
TIME_CATEGORIES = {
    "morning": [
        "morning_offering",
        "morning_offering_mary",
        "morning_offering_simple",
        "morning_thanksgiving",
        "st_therese_morning_offering",
        "st_patrick_breastplate",  # Traditional morning prayer
    ],
    "afternoon": [
        "grace_before_meals",
        "grace_after_meals",
        "angelus",  # Traditionally at noon (and 6am/6pm, but noon is most common)
    ],
    "evening": [
        "evening_protection",
        "evening_thanksgiving",
    ],
    "night": [
        "away_in_manger_bedtime",
        "bedtime_examination",
        "children_bedtime_prayer",
        "compline_commendation",
        "compline_final_prayer",
        "compline_protection",
        "prayer_before_sleep",
        "nunc_dimittis",
        "guardian_angel_prayer",  # Often said before sleep
    ],
}

def get_time_of_day(prayer_id):
    """Get the time of day category for a prayer ID."""
    for time_of_day, prayer_ids in TIME_CATEGORIES.items():
        if prayer_id in prayer_ids:
            return time_of_day
    return "anytime"

def update_prayer_file(filepath):
    """Add timeOfDay field to a prayer JSON file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            prayer = json.load(f)
        
        prayer_id = prayer.get('id', '')
        time_of_day = get_time_of_day(prayer_id)
        
        # Add timeOfDay field
        prayer['timeOfDay'] = time_of_day
        
        # Write back with nice formatting
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(prayer, f, indent=2, ensure_ascii=False)
        
        return prayer_id, time_of_day
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return None, None

def main():
    # Get all JSON files except metadata
    prayer_files = [
        f for f in os.listdir(PRAYERS_DIR) 
        if f.endswith('.json') and f != 'prayers_metadata.json'
    ]
    
    # Track categorization stats
    stats = {
        "morning": 0,
        "afternoon": 0,
        "evening": 0,
        "night": 0,
        "anytime": 0,
    }
    
    print(f"Updating {len(prayer_files)} prayer files...\n")
    
    for filename in sorted(prayer_files):
        filepath = os.path.join(PRAYERS_DIR, filename)
        prayer_id, time_of_day = update_prayer_file(filepath)
        
        if prayer_id and time_of_day:
            stats[time_of_day] += 1
            if time_of_day != "anytime":
                print(f"  {prayer_id}: {time_of_day}")
    
    print(f"\nCategorization complete!")
    print(f"\nStats:")
    for time_of_day, count in stats.items():
        print(f"  {time_of_day}: {count}")

if __name__ == "__main__":
    main()
