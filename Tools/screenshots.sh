#!/bin/bash
#
# screenshots.sh — generates App Store screenshots in EN + ES.
#
# Boots an iPhone 17 Pro Max simulator (correct resolution for the 6.7"
# App Store slot). For each language, sets the simulator's system locale
# globally (more reliable than the `-AppleLanguages` launch arg, which
# doesn't always propagate to SwiftUI's resource lookup). Then for each
# dashboard tab it launches the app with `-MockData YES -StartTab <tab>`
# and captures the screen.
#
# Output:
#   ~/Desktop/livebars-screenshots/
#     en-needs.png en-aspirations.png en-botiquin.png en-agenda.png
#     es-needs.png es-aspirations.png es-botiquin.png es-agenda.png
#
# Usage:
#   chmod +x Tools/screenshots.sh
#   ./Tools/screenshots.sh

set -euo pipefail

BUNDLE_ID="com.mysims.life"
PROJECT="MySimsLife.xcodeproj"
SCHEME="MySimsLife"
SIMULATOR_NAME="iPhone 17 Pro Max"
OUT_DIR="$HOME/Desktop/livebars-screenshots"

mkdir -p "$OUT_DIR"

# iPhone 17 Pro Max simulator dumps PNGs at 1320×2868, but App Store
# Connect's largest iPhone slot (6.7") needs exactly 1284×2778. Aspect
# ratios differ by ~0.4%, so we shave 12 px off the bottom (home indicator
# area, always blank) before resampling — keeps the image undistorted.
resize_for_appstore() {
    local file="$1"
    sips --cropToHeightWidth 2856 1320 "$file" >/dev/null
    sips -z 2778 1284 "$file" >/dev/null
}

echo "▶ Building app for simulator..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -configuration Debug build 2>&1 | grep -E "error:|BUILD" | tail -3

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "MySimsLife.app" \
    -path "*Debug-iphonesimulator*" -not -path "*Index.noindex*" 2>/dev/null | head -1)
echo "▶ App bundle: $APP_PATH"

SIM_UDID=$(xcrun simctl list devices available -j | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print([dev['udid'] for k,v in d['devices'].items() for dev in v if dev['name']=='$SIMULATOR_NAME' and dev.get('isAvailable',False)][0])")
echo "▶ Simulator UDID: $SIM_UDID"

LANGS=("en" "es")
# Dashboard sub-tabs (root tab = Status / Estado)
DASH_TABS=("needs" "aspirations" "botiquin" "agenda")
# Root-level tabs that live OUTSIDE the dashboard
ROOT_TABS=("history" "settings")

set_simulator_locale() {
    local lang="$1"
    local locale="$2"
    echo "  → Setting simulator locale to $locale..."
    xcrun simctl shutdown "$SIM_UDID" 2>/dev/null || true
    sleep 1
    xcrun simctl boot "$SIM_UDID"
    sleep 3
    xcrun simctl spawn "$SIM_UDID" defaults write -g AppleLanguages -array "$lang"
    xcrun simctl spawn "$SIM_UDID" defaults write -g AppleLocale -string "$locale"
}

open -a Simulator || true

for LANG in "${LANGS[@]}"; do
    case "$LANG" in
        en) LOCALE="en_US" ;;
        es) LOCALE="es_ES" ;;
    esac

    echo ""
    echo "═══ Language: $LANG ═══"
    set_simulator_locale "$LANG" "$LOCALE"

    # Dashboard sub-tabs (root tab defaults to Status / Estado)
    for TAB in "${DASH_TABS[@]}"; do
        echo "▶ [$LANG / dash:$TAB] capturing..."

        # Fresh install so MockData re-injects in the right language
        xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl install "$SIM_UDID" "$APP_PATH"

        xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" \
            -MockData YES \
            -StartTab "$TAB" > /dev/null

        sleep 4

        OUTFILE="$OUT_DIR/${LANG}-${TAB}.png"
        xcrun simctl io "$SIM_UDID" screenshot "$OUTFILE"
        resize_for_appstore "$OUTFILE"
        echo "   ✓ $OUTFILE (1284×2778)"

        xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
        sleep 1
    done

    # Root-level tabs (History, Settings) live OUTSIDE the dashboard
    for TAB in "${ROOT_TABS[@]}"; do
        echo "▶ [$LANG / root:$TAB] capturing..."

        xcrun simctl uninstall "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl install "$SIM_UDID" "$APP_PATH"

        xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" \
            -MockData YES \
            -RootTab "$TAB" > /dev/null

        sleep 4

        OUTFILE="$OUT_DIR/${LANG}-${TAB}.png"
        xcrun simctl io "$SIM_UDID" screenshot "$OUTFILE"
        resize_for_appstore "$OUTFILE"
        echo "   ✓ $OUTFILE (1284×2778)"

        xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
        sleep 1
    done
done

echo ""
echo "▶ Done. Screenshots at $OUT_DIR"
