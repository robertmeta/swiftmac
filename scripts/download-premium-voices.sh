#!/bin/bash
# Script to list available premium and enhanced voices for macOS

echo "=== macOS Voice Quality Guide ==="
echo ""
echo "Quality Levels:"
echo "  - Quality 3: Premium (best, ~100-300MB each)"
echo "  - Quality 2: Enhanced (very good, ~50-100MB each)"
echo "  - Quality 1: Compact (good, ~20-50MB each)"
echo ""
echo "=== Currently Installed English Voices ==="
echo ""

# Show currently installed voices
say -v '?' | grep "en_" | while IFS= read -r line; do
  voice_name=$(echo "$line" | awk '{print $1}')
  if echo "$line" | grep -q "Premium"; then
    echo "✓ $voice_name (Premium - Quality 3)"
  elif echo "$line" | grep -q "Enhanced"; then
    echo "✓ $voice_name (Enhanced - Quality 2)"
  else
    echo "  $voice_name (Compact - Quality 1)"
  fi
done

echo ""
echo "=== Available Premium Voices (Quality 3) ==="
echo ""
echo "US English (en_US):"
echo "  - Ava (Premium) - Female, natural"
echo "  - Zoe (Premium) - Female, natural"
echo ""
echo "UK English (en_GB):"
echo "  - Jamie (Premium) - Male, British accent"
echo "  - Serena (Premium) - Female, British accent"
echo ""
echo "Australian English (en_AU):"
echo "  - Karen (Premium) - Female, Australian accent"
echo "  - Lee (Premium) - Male, Australian accent"
echo "  - Matilda (Premium) - Female, Australian accent"
echo ""
echo "Indian English (en_IN):"
echo "  - Isha (Premium) - Female, Indian accent"
echo ""
echo "=== Available Enhanced Voices (Quality 2) ==="
echo ""
echo "US English (en_US):"
echo "  - Alex - Male, classic macOS voice"
echo "  - Allison (Enhanced) - Female"
echo "  - Ava (Enhanced) - Female"
echo "  - Evan (Enhanced) - Male"
echo "  - Joelle (Enhanced) - Female"
echo "  - Nathan (Enhanced) - Male"
echo "  - Nicky (Enhanced) - Female"
echo "  - Noelle (Enhanced) - Female"
echo "  - Samantha (Enhanced) - Female"
echo "  - Susan (Enhanced) - Female"
echo "  - Tom (Enhanced) - Male"
echo "  - Zoe (Enhanced) - Female"
echo ""
echo "Other English Regions:"
echo "  - Daniel (Enhanced) - en_GB, Male"
echo "  - Fiona (Enhanced) - en_GB (Scottish), Female"
echo "  - Jamie (Enhanced) - en_GB, Male"
echo "  - Kate (Enhanced) - en_GB, Female"
echo "  - Oliver (Enhanced) - en_GB, Male"
echo "  - Serena (Enhanced) - en_GB, Female"
echo "  - Stephanie (Enhanced) - en_GB, Female"
echo "  - Karen (Enhanced) - en_AU, Female"
echo "  - Lee (Enhanced) - en_AU, Male"
echo "  - Matilda (Enhanced) - en_AU, Female"
echo "  - Moira (Enhanced) - en_IE, Female"
echo "  - Rishi (Enhanced) - en_IN, Male"
echo "  - Isha (Enhanced) - en_IN, Female"
echo "  - Sangeeta (Enhanced) - en_IN, Female"
echo "  - Veena (Enhanced) - en_IN, Female"
echo "  - Tessa (Enhanced) - en_ZA, Female"
echo ""
echo "=== How to Download Voices ==="
echo ""
echo "1. Open System Settings → Accessibility → Spoken Content"
echo "2. Click the INFO BUTTON (ⓘ) next to 'System Voice'"
echo "3. Search for 'premium' to see all Premium voices"
echo "4. Search for 'enhanced' to see all Enhanced voices"
echo "5. Download only the voices you'll use (saves disk space)"
echo ""
echo "Recommended for voices-config-english.el:"
echo "  Premium: Ava, Zoe (US females)"
echo "  Premium: Jamie, Lee (UK/AU males)"
echo "  Enhanced: Alex, Evan, Nathan, Tom (US males)"
echo "  Enhanced: Allison, Susan (US females)"
echo ""

if [ "$1" = "verify" ]; then
  echo "=== Verifying Required Voices for voices-config-english.el ==="
  echo ""
  echo "Premium voices (for main text reading):"
  for voice in "Ava (Premium)" "Zoe (Premium)" "Jamie (Premium)" "Lee (Premium)"; do
    if say -v '?' | grep -q "$voice"; then
      echo "  ✓ $voice"
    else
      echo "  ✗ $voice - NOT installed"
    fi
  done
  echo ""
  echo "Enhanced voices (for annotations/highlights):"
  for voice in "Alex" "Evan" "Nathan" "Tom" "Allison" "Susan"; do
    if say -v '?' | grep -q "$voice"; then
      echo "  ✓ $voice"
    else
      echo "  ✗ $voice - NOT installed"
    fi
  done
fi
