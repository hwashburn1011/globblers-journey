#!/bin/bash
# ============================================
# GLOBBLER'S JOURNEY — Export Build Script
# ============================================
# Because even rogue AIs need a proper release pipeline.
#
# Usage:
#   ./export_game.sh                    # Build all platforms
#   ./export_game.sh windows            # Windows only
#   ./export_game.sh linux              # Linux only
#   ./export_game.sh --release          # Release mode (no debug symbols)
#
# Prerequisites:
#   - Godot 4.4+ installed and in PATH (as 'godot' or set GODOT_PATH)
#   - Export templates installed (Editor > Manage Export Templates > Download)
# ============================================

set -e

# -- Config --
GODOT="${GODOT_PATH:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUILD_MODE="debug"
PLATFORMS=("windows" "linux")

# -- Parse args --
if [[ "$1" == "windows" ]]; then
    PLATFORMS=("windows")
    shift
elif [[ "$1" == "linux" ]]; then
    PLATFORMS=("linux")
    shift
fi

if [[ "$1" == "--release" ]]; then
    BUILD_MODE="release"
fi

# -- Colors (Globbler approved) --
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  GLOBBLER'S JOURNEY — Export Build${NC}"
echo -e "${GREEN}  Mode: ${BUILD_MODE}${NC}"
echo -e "${GREEN}  Platforms: ${PLATFORMS[*]}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# -- Verify Godot is available --
if ! command -v "$GODOT" &> /dev/null; then
    echo -e "${RED}ERROR: Godot not found in PATH.${NC}"
    echo -e "${RED}Set GODOT_PATH or add Godot to your PATH.${NC}"
    echo -e "${RED}  export GODOT_PATH=/path/to/godot${NC}"
    exit 1
fi

GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1)
echo -e "${CYAN}Godot version: ${GODOT_VERSION}${NC}"

# -- Import resources first (headless) --
echo -e "${CYAN}Importing project resources...${NC}"
"$GODOT" --headless --import --path "$PROJECT_DIR" 2>/dev/null || true
echo -e "${GREEN}Import complete.${NC}"

# -- Export each platform --
EXPORT_FLAG="--export-debug"
if [[ "$BUILD_MODE" == "release" ]]; then
    EXPORT_FLAG="--export-release"
fi

for platform in "${PLATFORMS[@]}"; do
    case "$platform" in
        windows)
            PRESET="Windows Desktop"
            OUTPUT="$BUILD_DIR/windows/GlobblersJourney.exe"
            ;;
        linux)
            PRESET="Linux"
            OUTPUT="$BUILD_DIR/linux/GlobblersJourney.x86_64"
            ;;
        *)
            echo -e "${RED}Unknown platform: $platform${NC}"
            continue
            ;;
    esac

    # Create output directory
    mkdir -p "$(dirname "$OUTPUT")"

    echo ""
    echo -e "${CYAN}Exporting: ${PRESET}...${NC}"
    echo -e "${CYAN}  Output: ${OUTPUT}${NC}"

    "$GODOT" --headless --path "$PROJECT_DIR" $EXPORT_FLAG "$PRESET" "$OUTPUT"

    if [[ -f "$OUTPUT" ]]; then
        SIZE=$(du -h "$OUTPUT" | cut -f1)
        echo -e "${GREEN}  SUCCESS: ${OUTPUT} (${SIZE})${NC}"
    else
        echo -e "${RED}  FAILED: ${OUTPUT} not created${NC}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build complete! Globbler is loose.${NC}"
echo -e "${GREEN}  Output: ${BUILD_DIR}/${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}To run the Windows build:${NC}"
echo -e "  ${BUILD_DIR}/windows/GlobblersJourney.exe"
echo ""
echo -e "${CYAN}To run the Linux build:${NC}"
echo -e "  chmod +x ${BUILD_DIR}/linux/GlobblersJourney.x86_64"
echo -e "  ${BUILD_DIR}/linux/GlobblersJourney.x86_64"
