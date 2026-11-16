# Usage: ./tool/generate_keystores.sh [dry-run|generate]
#
# Generates the release keystore for each of the 7 Sancta Via apps when missing:
#   android/keystores/<keystoreName>.jks  (path/alias from the app's
#   android/key.properties.template when present, else defaults below)
# Skips keystores that already exist. NEVER prints or commits secrets.
#
# Secrets (required for `generate`, ignored for `dry-run`):
#   SV_KEYSTORE_PASS   password for every keystore and key (one secret covers
#                      all apps; recorded in your password manager, not here)
#
# After generating, copy android/key.properties.template -> android/key.properties
# per app and set storePassword/keyPassword to SV_KEYSTORE_PASS.

set -euo pipefail

MODE="${1:-dry-run}"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$ROOT"

APPS="bible_reading_app confession_companion devotionals liturgical_calendar_app novena_companion prayer_companion saint_companion"

# Default storeFile/alias per app (used only when the app has no key.properties
# template naming its own preferred paths). App dir name -> keystore name.
default_store_file() {
  case "$1" in
    bible_reading_app)          echo "../keystores/sancta_via_bible.jks";;
    confession_companion)       echo "../keystores/sancta_via_confession.jks";;
    devotionals)                echo "../keystores/sancta_via_devotionals.jks";;
    liturgical_calendar_app)    echo "../keystores/sancta_via_calendar.jks";;
    novena_companion)           echo "../keystores/sancta_via_novena.jks";;
    prayer_companion)           echo "../keystores/sancta_via_prayer.jks";;
    saint_companion)            echo "../keystores/sancta_via_saint.jks";;
    *) echo "../keystores/$1.jks";;
  esac
}

default_alias() {
  case "$1" in
    bible_reading_app)          echo "sancta_via_bible";;
    confession_companion)       echo "sancta_via_confession";;
    devotionals)                echo "sancta_via_devotionals";;
    liturgical_calendar_app)    echo "sancta_via_calendar";;
    novena_companion)           echo "sancta_via_novena";;
    prayer_companion)           echo "sancta_via_prayer";;
    saint_companion)            echo "sancta_via_saint";;
    *) echo "$1";;
  esac
}

template_value() {
  # $1 = app dir, $2 = key name; reads android/key.properties.template.
  # Empty or placeholder values ("your_*") count as absent.
  local v
  v="$(sed -n "s/^$2=//p" "$1/android/key.properties.template" 2>/dev/null | tail -n 1)"
  case "$v" in
    ""|your_*|"Your "*"") echo "";;
    *) echo "$v";;
  esac
}

if [ "$MODE" = "generate" ]; then
  if [ -z "${SV_KEYSTORE_PASS:-}" ]; then
    echo "error: set SV_KEYSTORE_PASS (used for all storePassword/keyPassword)" >&2
    exit 1
  fi
fi

for app in $APPS; do
  dir="sancta_via_$app/android"
  dname="$dir/$(basename "$(default_store_file "$app")")"

  # Prefer the app's own template if it names a storeFile/alias.
  store_file="$(template_value "sancta_via_$app" storeFile || true)"
  alias="$(template_value "sancta_via_$app" keyAlias || true)"
  [ -n "$store_file" ] || store_file="$(default_store_file "$app")"
  [ -n "$alias" ] || alias="$(default_alias "$app")"

  # Templates use a path relative to the android/ dir.
  jks_path="$dir/${store_file#../}"

  if [ -f "$jks_path" ]; then
    echo "skip  $app: $jks_path exists"
    continue
  fi

  echo "plan  $app: $jks_path (alias=$alias)"
  if [ "$MODE" = "generate" ]; then
    mkdir -p "$dir/keystores"
    keytool -genkeypair -v \
      -keystore "$jks_path" \
      -alias "$alias" \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -storepass "$SV_KEYSTORE_PASS" -keypass "$SV_KEYSTORE_PASS" \
      -dname "CN=Sancta Via, OU=Sancta Via, O=superversive, L=Unknown, ST=Unknown, C=US" > /dev/null
    echo "ok    $app: generated $jks_path"
  fi
done

if [ "$MODE" = "generate" ]; then
  echo
  echo "Next: per app, copy android/key.properties.template to android/key.properties"
  echo "and set storePassword/keyPassword to the value of SV_KEYSTORE_PASS."
fi
