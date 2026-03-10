#!/bin/bash
# Generate mystery audio files

API_URL="http://media.lan:4123/audio/speech"
VOICE="eric"
OUTPUT_DIR="/Users/jason/Repos/sancta_via/sancta_via_rosary/assets/audio/mysteries"

cd "$OUTPUT_DIR"

# Joyful Mysteries
echo "Generating Joyful mysteries..."
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The First Joyful Mystery: The Annunciation. The Angel Gabriel appears to Mary and asks her to be the Mother of God. Mary humbly accepts, saying, Be it done unto me according to thy word.", "voice": "eric", "response_format": "wav"}' --output joyful_1.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Second Joyful Mystery: The Visitation. Mary visits her cousin Elizabeth, who greets her with the words, Blessed art thou among women. The infant John the Baptist leaps for joy in Elizabeth womb.", "voice": "eric", "response_format": "wav"}' --output joyful_2.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Third Joyful Mystery: The Nativity. Jesus is born in Bethlehem, laid in a manger, and adored by shepherds and angels. The Word is made flesh and dwells among us.", "voice": "eric", "response_format": "wav"}' --output joyful_3.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fourth Joyful Mystery: The Presentation. Mary and Joseph present Jesus in the temple. Simeon recognizes Him as the light to enlighten the Gentiles and the glory of Israel.", "voice": "eric", "response_format": "wav"}' --output joyful_4.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fifth Joyful Mystery: The Finding in the Temple. After three days of searching, Mary and Joseph find Jesus in the temple, sitting among the teachers, listening and asking questions.", "voice": "eric", "response_format": "wav"}' --output joyful_5.wav &

# Sorrowful Mysteries
echo "Generating Sorrowful mysteries..."
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The First Sorrowful Mystery: The Agony in the Garden. Jesus prays in Gethsemane, sweating blood as He contemplates the sins of the world. He asks His Father, if it be possible, let this chalice pass from me. Yet not my will, but thine be done.", "voice": "eric", "response_format": "wav"}' --output sorrowful_1.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Second Sorrowful Mystery: The Scourging at the Pillar. Jesus is stripped and whipped at the pillar, bearing the punishment for our sins with patience and love.", "voice": "eric", "response_format": "wav"}' --output sorrowful_2.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Third Sorrowful Mystery: The Crowning with Thorns. Soldiers mock Jesus by crowning Him with thorns and dressing Him in purple, hailing Him as King of the Jews.", "voice": "eric", "response_format": "wav"}' --output sorrowful_3.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fourth Sorrowful Mystery: The Carrying of the Cross. Jesus carries the heavy cross through the streets of Jerusalem to Calvary, meeting His sorrowful mother along the way.", "voice": "eric", "response_format": "wav"}' --output sorrowful_4.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fifth Sorrowful Mystery: The Crucifixion. Jesus is nailed to the cross and dies for our salvation. He forgives those who crucify Him and entrusts Mary to John.", "voice": "eric", "response_format": "wav"}' --output sorrowful_5.wav &

# Glorious Mysteries
echo "Generating Glorious mysteries..."
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The First Glorious Mystery: The Resurrection. Jesus rises from the dead on the third day, conquering death and opening the gates of heaven for all who believe in Him.", "voice": "eric", "response_format": "wav"}' --output glorious_1.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Second Glorious Mystery: The Ascension. Jesus ascends into heaven forty days after His resurrection, returning to the Father and preparing a place for us.", "voice": "eric", "response_format": "wav"}' --output glorious_2.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Third Glorious Mystery: The Descent of the Holy Spirit. The Holy Spirit descends upon the apostles at Pentecost, giving them courage and wisdom to preach the Gospel.", "voice": "eric", "response_format": "wav"}' --output glorious_3.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fourth Glorious Mystery: The Assumption. Mary is assumed body and soul into heaven at the end of her earthly life, crowned as Queen of Heaven and Earth.", "voice": "eric", "response_format": "wav"}' --output glorious_4.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fifth Glorious Mystery: The Coronation. Mary is crowned Queen of Heaven and Earth, interceding for us as our loving Mother and Advocate.", "voice": "eric", "response_format": "wav"}' --output glorious_5.wav &

# Luminous Mysteries
echo "Generating Luminous mysteries..."
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The First Luminous Mystery: The Baptism in the Jordan. Jesus is baptized by John in the Jordan River. The heavens open, the Spirit descends like a dove, and the Fathers voice proclaims, This is my beloved Son.", "voice": "eric", "response_format": "wav"}' --output luminous_1.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Second Luminous Mystery: The Wedding at Cana. At Marys request, Jesus performs His first miracle, turning water into wine at the wedding feast of Cana.", "voice": "eric", "response_format": "wav"}' --output luminous_2.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Third Luminous Mystery: The Proclamation of the Kingdom. Jesus preaches the Gospel, calling all to repentance and belief in the Good News. He heals the sick, casts out demons, and welcomes sinners.", "voice": "eric", "response_format": "wav"}' --output luminous_3.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fourth Luminous Mystery: The Transfiguration. Jesus is transfigured before Peter, James, and John on Mount Tabor, revealing His divine glory. Moses and Elijah appear.", "voice": "eric", "response_format": "wav"}' --output luminous_4.wav &
curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d '{"input": "The Fifth Luminous Mystery: The Institution of the Eucharist. At the Last Supper, Jesus institutes the Eucharist, giving His Body and Blood under the appearance of bread and wine.", "voice": "eric", "response_format": "wav"}' --output luminous_5.wav &

wait
echo "All mystery audio files generated!"
ls -la "$OUTPUT_DIR"/*.wav | wc -l
echo "files created"
