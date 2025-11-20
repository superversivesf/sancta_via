#!/bin/bash
# Script to add timeOfDay field to all prayer JSON files
# Run from the sancta_via_prayer_companion directory

PRAYERS_DIR="assets/prayers"

# Function to add timeOfDay field to a prayer file
add_time_of_day() {
    local file="$1"
    local time="$2"
    
    # Check if file already has timeOfDay
    if grep -q '"timeOfDay"' "$file"; then
        echo "Skipping $file (already has timeOfDay)"
        return
    fi
    
    # Add timeOfDay before the closing brace
    # Using sed to insert before the last }
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/}$/,\n  "timeOfDay": "'"$time"'"\n}/' "$file"
    else
        # Linux
        sed -i 's/}$/,\n  "timeOfDay": "'"$time"'"\n}/' "$file"
    fi
    
    echo "Added timeOfDay: $time to $file"
}

# Morning prayers - these have st_therese_morning_offering which needs morning
add_time_of_day "$PRAYERS_DIR/st_therese_morning_offering.json" "morning"
add_time_of_day "$PRAYERS_DIR/st_patrick_breastplate.json" "morning"
add_time_of_day "$PRAYERS_DIR/veni_creator_spiritus.json" "morning"

# Anytime prayers
add_time_of_day "$PRAYERS_DIR/act_of_contrition.json" "anytime"
add_time_of_day "$PRAYERS_DIR/our_father.json" "anytime"
add_time_of_day "$PRAYERS_DIR/hail_mary.json" "anytime"
add_time_of_day "$PRAYERS_DIR/glory_be.json" "anytime"
add_time_of_day "$PRAYERS_DIR/sign_of_the_cross.json" "anytime"
add_time_of_day "$PRAYERS_DIR/apostles_creed.json" "anytime"
add_time_of_day "$PRAYERS_DIR/nicene_creed.json" "anytime"
add_time_of_day "$PRAYERS_DIR/memorare.json" "anytime"
add_time_of_day "$PRAYERS_DIR/hail_holy_queen.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_francis_peace_prayer.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_st_michael.json" "anytime"
add_time_of_day "$PRAYERS_DIR/eternal_rest.json" "anytime"
add_time_of_day "$PRAYERS_DIR/adoro_te_devote.json" "anytime"
add_time_of_day "$PRAYERS_DIR/agnus_dei.json" "anytime"
add_time_of_day "$PRAYERS_DIR/anima_christi.json" "anytime"
add_time_of_day "$PRAYERS_DIR/christ_has_no_body.json" "anytime"
add_time_of_day "$PRAYERS_DIR/gloria_in_excelsis.json" "anytime"
add_time_of_day "$PRAYERS_DIR/memorial_acclamation_1.json" "anytime"
add_time_of_day "$PRAYERS_DIR/memorial_acclamation_2.json" "anytime"
add_time_of_day "$PRAYERS_DIR/memorial_acclamation_3.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_before_mass.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_for_pope_blessing.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_for_pope_formal.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_of_abandonment.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_immaculate_heart.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_sacred_heart.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_st_joseph.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_st_rita.json" "anytime"
add_time_of_day "$PRAYERS_DIR/prayer_to_st_teresa_intercession.json" "anytime"
add_time_of_day "$PRAYERS_DIR/regina_caeli.json" "anytime"
add_time_of_day "$PRAYERS_DIR/sanctus.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_anthony_lost_things.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_anthony_powerful_intercession.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_ephrem_lenten_prayer.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_francis_san_damiano.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_gertrude_holy_souls.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_jude_glorious_apostle.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_jude_novena.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_teresa_bookmark_prayer.json" "anytime"
add_time_of_day "$PRAYERS_DIR/st_therese_little_flower.json" "anytime"
add_time_of_day "$PRAYERS_DIR/sub_tuum_praesidium.json" "anytime"
add_time_of_day "$PRAYERS_DIR/suscipe_prayer.json" "anytime"

echo "Done updating prayer files!"
