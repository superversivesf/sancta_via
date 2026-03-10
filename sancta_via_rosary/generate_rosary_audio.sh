#!/bin/bash
# Generate Rosary Prayer Audio Files using Chatterbox TTS
# Usage: ./generate_rosary_audio.sh

set -e

API_URL="http://media.lan:4123/audio/speech"
VOICE="eric"
OUTPUT_DIR="${1:-./assets/audio}"

# Create output directory
mkdir -p "$OUTPUT_DIR/prayers"
mkdir -p "$OUTPUT_DIR/mysteries"

echo "Generating Rosary Prayer Audio Files..."
echo "API: $API_URL"
echo "Voice: $VOICE"
echo "Output: $OUTPUT_DIR"
echo ""

# Prayer texts
PRAYERS=(
    "sign_of_cross|In the name of the Father, and of the Son, and of the Holy Spirit. Amen."
    "apostles_creed|I believe in God, the Father Almighty, Creator of heaven and earth, and in Jesus Christ, His only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried. He descended into hell. On the third day He rose again from the dead. He ascended into heaven and is seated at the right hand of God, the Father Almighty. From there He will come to judge the living and the dead. I believe in the Holy Spirit, the Holy Catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen."
    "our_father|Our Father, who art in heaven, hallowed be thy name. Thy kingdom come, thy will be done, on earth as it is in heaven. Give us this day our daily bread, and forgive us our trespasses, as we forgive those who trespass against us. And lead us not into temptation, but deliver us from evil. Amen."
    "hail_mary|Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
    "glory_be|Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen."
    "fatima_prayer|O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to heaven, especially those in most need of thy mercy."
    "hail_holy_queen|Hail, Holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious advocate, thine eyes of mercy toward us, and after this our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary. Pray for us, O holy Mother of God, that we may be made worthy of the promises of Christ. Amen."
    "closing_prayer|O God, whose only begotten Son, by His life, death, and resurrection, has purchased for us the rewards of eternal life, grant, we beseech thee, that meditating upon these mysteries of the Most Holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise. Through the same Christ our Lord. Amen."
)

# Generate prayers
echo "=== Generating Prayers ==="
for prayer in "${PRAYERS[@]}"; do
    IFS='|' read -r name text <<< "$prayer"
    output_file="$OUTPUT_DIR/prayers/${name}.wav"
    
    echo "Generating: $name.wav"
    
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"input\": \"$text\",
            \"voice\": \"$VOICE\",
            \"response_format\": \"wav\"
        }" \
        --output "$output_file" \
        --fail || {
            echo "ERROR: Failed to generate $name"
            exit 1
        }
    
    # Check file was created and has content
    if [ ! -s "$output_file" ]; then
        echo "ERROR: $output_file is empty"
        exit 1
    fi
    
    size=$(du -h "$output_file" | cut -f1)
    echo "  ✓ Created: $size"
done

echo ""
echo "=== Generating Mystery Descriptions ==="

# Joyful Mysteries
JOYFUL=(
    "joyful_1|The First Joyful Mystery: The Annunciation. The Angel Gabriel appears to Mary and asks her to be the Mother of God. Mary humbly accepts, saying, Be it done unto me according to thy word."
    "joyful_2|The Second Joyful Mystery: The Visitation. Mary visits her cousin Elizabeth, who greets her with the words, Blessed art thou among women. The infant John the Baptist leaps for joy in Elizabeth's womb."
    "joyful_3|The Third Joyful Mystery: The Nativity. Jesus is born in Bethlehem, laid in a manger, and adored by shepherds and angels. The Word is made flesh and dwells among us."
    "joyful_4|The Fourth Joyful Mystery: The Presentation. Mary and Joseph present Jesus in the temple. Simeon recognizes Him as the light to enlighten the Gentiles and the glory of Israel."
    "joyful_5|The Fifth Joyful Mystery: The Finding in the Temple. After three days of searching, Mary and Joseph find Jesus in the temple, sitting among the teachers, listening and asking questions."
)

# Sorrowful Mysteries
SORROWFUL=(
    "sorrowful_1|The First Sorrowful Mystery: The Agony in the Garden. Jesus prays in Gethsemane, sweating blood as He contemplates the sins of the world and the suffering He must endure. He asks His Father, if it be possible, let this chalice pass from me. Yet not my will, but thine be done."
    "sorrowful_2|The Second Sorrowful Mystery: The Scourging at the Pillar. Jesus is stripped and whipped at the pillar, bearing the punishment for our sins with patience and love."
    "sorrowful_3|The Third Sorrowful Mystery: The Crowning with Thorns. Soldiers mock Jesus by crowning Him with thorns and dressing Him in purple, hailing Him as King of the Jews."
    "sorrowful_4|The Fourth Sorrowful Mystery: The Carrying of the Cross. Jesus carries the heavy cross through the streets of Jerusalem to Calvary, meeting His sorrowful mother along the way."
    "sorrowful_5|The Fifth Sorrowful Mystery: The Crucifixion. Jesus is nailed to the cross and dies for our salvation. He forgives those who crucify Him and entrusts Mary to John and us to Mary."
)

# Glorious Mysteries
GLORIOUS=(
    "glorious_1|The First Glorious Mystery: The Resurrection. Jesus rises from the dead on the third day, conquering death and opening the gates of heaven for all who believe in Him."
    "glorious_2|The Second Glorious Mystery: The Ascension. Jesus ascends into heaven forty days after His resurrection, returning to the Father and preparing a place for us."
    "glorious_3|The Third Glorious Mystery: The Descent of the Holy Spirit. The Holy Spirit descends upon the apostles at Pentecost, giving them courage and wisdom to preach the Gospel."
    "glorious_4|The Fourth Glorious Mystery: The Assumption. Mary is assumed body and soul into heaven at the end of her earthly life, crowned as Queen of Heaven and Earth."
    "glorious_5|The Fifth Glorious Mystery: The Coronation. Mary is crowned Queen of Heaven and Earth, interceding for us as our loving Mother and Advocate."
)

# Luminous Mysteries
LUMINOUS=(
    "luminous_1|The First Luminous Mystery: The Baptism in the Jordan. Jesus is baptized by John in the Jordan River. The heavens open, the Spirit descends like a dove, and the Father's voice proclaims, This is my beloved Son, in whom I am well pleased."
    "luminous_2|The Second Luminous Mystery: The Wedding at Cana. At Mary's request, Jesus performs His first miracle, turning water into wine at the wedding feast of Cana."
    "luminous_3|The Third Luminous Mystery: The Proclamation of the Kingdom. Jesus preaches the Gospel, calling all to repentance and belief in the Good News. He heals the sick, casts out demons, and welcomes sinners."
    "luminous_4|The Fourth Luminous Mystery: The Transfiguration. Jesus is transfigured before Peter, James, and John on Mount Tabor, revealing His divine glory. Moses and Elijah appear, and the Father again proclaims Jesus as His beloved Son."
    "luminous_5|The Fifth Luminous Mystery: The Institution of the Eucharist. At the Last Supper, Jesus institutes the Eucharist, giving His Body and Blood under the appearance of bread and wine, commanding us to do this in memory of Him."
)

# Combine all mysteries
ALL_MYSTERIES=("${JOYFUL[@]}" "${SORROWFUL[@]}" "${GLORIOUS[@]}" "${LUMINOUS[@]}")

# Generate mystery descriptions
for mystery in "${ALL_MYSTERIES[@]}"; do
    IFS='|' read -r name text <<< "$mystery"
    output_file="$OUTPUT_DIR/mysteries/${name}.wav"
    
    echo "Generating: $name.wav"
    
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"input\": \"$text\",
            \"voice\": \"$VOICE\",
            \"response_format\": \"wav\"
        }" \
        --output "$OUTPUT_DIR/mysteries/$name.wav" \
        --fail || {
            echo "ERROR: Failed to generate $name"
            exit 1
        }
    
    if [ ! -s "$output_file" ]; then
        echo "ERROR: $output_file is empty"
        exit 1
    fi
    
    size=$(du -h "$output_file" | cut -f1)
    echo "  ✓ Created: $size"
done

echo ""
echo "=== Generation Complete! ==="
echo ""
echo "Generated files:"
echo "  - 8 prayers in $OUTPUT_DIR/prayers/"
echo "  - 20 mystery descriptions in $OUTPUT_DIR/mysteries/"
echo ""
echo "Total files: $(find $OUTPUT_DIR -name '*.wav' | wc -l)"
echo "Total size: $(du -sh $OUTPUT_DIR | cut -f1)"
