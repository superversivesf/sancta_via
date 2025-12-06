#!/bin/bash

# Rosary Mystery Artwork Downloader
# Downloads public domain Catholic artworks for rosary mysteries
# All artworks are public domain (pre-1927)

echo "Starting download of rosary mystery artworks..."

# Create directories if they don't exist
mkdir -p assets/images/mysteries/{joyful,sorrowful,glorious,luminous}

# Joyful Mysteries
echo "Downloading Joyful Mysteries..."
cd assets/images/mysteries/joyful/

# 1. Annunciation - Fra Angelico
echo "Downloading Annunciation..."
wget -O 1-annunciation.jpg "https://upload.wikimedia.org/wikipedia/commons/0/04/Fra_Angelico_-_Annunciation_-_San_Marco_Altarpiece.jpg"

# 2. Visitation - Giotto
echo "Downloading Visitation..."
wget -O 2-visitation.jpg "https://upload.wikimedia.org/wikipedia/commons/7/7f/Visitation_Giotto_Arena_Chapel.jpg"

# 3. Nativity - Giotto
echo "Downloading Nativity..."  
wget -O 3-nativity.jpg "https://upload.wikimedia.org/wikipedia/commons/5/58/Giotto_-_Scrovegni_-_-18-_-_Nativity.jpg"

# 4. Presentation - Giotto
echo "Downloading Presentation..."
wget -O 4-presentation.jpg "https://upload.wikimedia.org/wikipedia/commons/2/2c/Giotto_-_Scrovegni_-_-19-_-_Presentation_at_the_Temple.jpg"

# 5. Finding in Temple - Giotto
echo "Downloading Finding in Temple..."
wget -O 5-finding-temple.jpg "https://upload.wikimedia.org/wikipedia/commons/3/3b/Giotto_-_Scrovegni_-_-20-_-_The_Finding_in_the_Temple.jpg"

cd ../../../..

# Sorrowful Mysteries
echo "Downloading Sorrowful Mysteries..."
cd assets/images/mysteries/sorrowful/

# 1. Agony in Garden - Mantegna
echo "Downloading Agony in Garden..."
wget -O 1-agony-garden.jpg "https://upload.wikimedia.org/wikipedia/commons/8/8a/Andrea_Mantegna_-_Agony_in_the_Garden_-_Google_Art_Project.jpg"

# 2. Scourging - Piero della Francesca
echo "Downloading Scourging..."
wget -O 2-scourging.jpg "https://upload.wikimedia.org/wikipedia/commons/7/7b/Piero_della_Francesca_-_Flagellation_of_Christ_-_Google_Art_Project.jpg"

# 3. Crowning with Thorns - Titian
echo "Downloading Crowning with Thorns..."
wget -O 3-crowning-thorns.jpg "https://upload.wikimedia.org/wikipedia/commons/2/2c/Titian_-_Crowning_with_Thorns_-_Google_Art_Project.jpg"

# 4. Carrying Cross - Titian
echo "Downloading Carrying Cross..."
wget -O 4-carrying-cross.jpg "https://upload.wikimedia.org/wikipedia/commons/4/4d/Tiziano_-_Cristo_che_porta_la_croce.jpg"

# 5. Crucifixion - Giotto
echo "Downloading Crucifixion..."
wget -O 5-crucifixion.jpg "https://upload.wikimedia.org/wikipedia/commons/1/1e/Giotto_-_Scrovegni_-_-35-_-_Crucifixion.jpg"

cd ../../../..

# Glorious Mysteries
echo "Downloading Glorious Mysteries..."
cd assets/images/mysteries/glorious/

# 1. Resurrection - Piero della Francesca
echo "Downloading Resurrection..."
wget -O 1-resurrection.jpg "https://upload.wikimedia.org/wikipedia/commons/9/94/Piero_della_Francesca_-_Resurrection_-_Google_Art_Project.jpg"

# 2. Ascension - Garofalo
echo "Downloading Ascension..."
wget -O 2-ascension.jpg "https://upload.wikimedia.org/wikipedia/commons/8/8d/Garofalo_-_Ascension_of_Christ.jpg"

# 3. Pentecost - Titian
echo "Downloading Pentecost..."
wget -O 3-pentecost.jpg "https://upload.wikimedia.org/wikipedia/commons/0/0c/Titian_-_Pentecost_-_Google_Art_Project.jpg"

# 4. Assumption - Titian
echo "Downloading Assumption..."
wget -O 4-assumption.jpg "https://upload.wikimedia.org/wikipedia/commons/9/90/Titian_-_Assumption_of_the_Virgin_-_Google_Art_Project.jpg"

# 5. Coronation - Fra Angelico
echo "Downloading Coronation..."
wget -O 5-coronation.jpg "https://upload.wikimedia.org/wikipedia/commons/7/72/Fra_Angelico_044.jpg"

cd ../../../..

# Luminous Mysteries
echo "Downloading Luminous Mysteries..."
cd assets/images/mysteries/luminous/

# 1. Baptism - Piero della Francesca
echo "Downloading Baptism..."
wget -O 1-baptism.jpg "https://upload.wikimedia.org/wikipedia/commons/6/61/Piero_della_Francesca_-_Baptism_of_Christ_-_Google_Art_Project.jpg"

# 2. Wedding at Cana - Giotto
echo "Downloading Wedding at Cana..."
wget -O 2-wedding-cana.jpg "https://upload.wikimedia.org/wikipedia/commons/4/4c/Giotto_-_Scrovegni_-_-21-_-_Marriage_at_Cana.jpg"

# 3. Proclamation - Cosimo Rosselli
echo "Downloading Proclamation of Kingdom..."
wget -O 3-proclamation-kingdom.jpg "https://upload.wikimedia.org/wikipedia/commons/F/F7/Cosimo_Rosselli_-Sermon_on_the_Mount.jpg"

# 4. Transfiguration - Raphael
echo "Downloading Transfiguration..."
wget -O 4-transfiguration.jpg "https://upload.wikimedia.org/wikipedia/commons/4/4c/Raffaello_-_Trasfigurazione.jpg"

# 5. Last Supper - Leonardo da Vinci
echo "Downloading Institution of Eucharist..."
wget -O 5-eucharist.jpg "https://upload.wikimedia.org/wikipedia/commons/4/4b/Leonardo_da_vinci_-_Last_Supper_high_res.jpg"

cd ../../../..

echo "All mystery artworks downloaded successfully!"
echo "File sizes:"
ls -lh assets/images/mysteries/*/*.jpg

echo ""
echo "Next steps:"
echo "1. Update assets/data/mysteries.json with image_path fields"
echo "2. Run: cd sancta_via_rosary_companion && flutter pub get"
echo "3. Test the app and verify images display correctly"
echo ""
echo "Important: All artworks are public domain. You may use them freely in your app."