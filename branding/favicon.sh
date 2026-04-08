#!/bin/bash

# 1. Create favicon.svg or favicon.png source file ≥ 1024px square, and place it in the `source` subdirectory, one level down from `branding`.
# 2. Run this script in a terminal by entering: `./favicon.sh [inkscape|imagemagick|magick] [svg|png]` from the `branding` directory.
#    - Arguments can be provided in any order
#    - If arguments are not provided, you will be prompted if needed
# Re-running this script over-writes files it just created (or any other files of the same names).

# favicon.png, favicon@1.25x.png, favicon@1.5x.png, and favicon@2x.png are for Electron
# favicon_16x16.png and favicon_32x32.png are building blocks for favicon.ico

SOURCE_FORMAT=""
CONVERSION_TOOL=""

# Parse arguments in any order
for arg in "$@"; do
    # Convert to lowercase manually for bash 3.2 compatibility
    arg_lower=$(echo "$arg" | tr '[:upper:]' '[:lower:]')
    
    case "$arg_lower" in
        png)
            SOURCE_FORMAT="png"
            ;;
        svg)
            SOURCE_FORMAT="svg"
            ;;
        magick|imagemagick)
            CONVERSION_TOOL="magick"
            ;;
        inkscape)
            CONVERSION_TOOL="inkscape"
            ;;
        *)
            echo "Warning: Unknown argument '$arg' ignored"
            ;;
    esac
done

# Detect which tools are installed
MAGICK_INSTALLED=0
INKSCAPE_INSTALLED=0
MAGICK_CMD=""
INKSCAPE_CMD=""
INKSCAPE_PATH=""

# Detect OS
OS_TYPE="$(uname -s)"

# Check for ImageMagick - try 'magick' first, then 'convert' on Linux
if command -v magick >/dev/null 2>&1; then
    MAGICK_INSTALLED=1
    MAGICK_CMD="magick"
elif [ "$OS_TYPE" = "Linux" ] && command -v convert >/dev/null 2>&1; then
    # On Linux, if 'magick' is not found, check for 'convert'
    MAGICK_INSTALLED=1
    MAGICK_CMD="convert"
fi

# Check if inkscape is in PATH first
if command -v inkscape >/dev/null 2>&1; then
    INKSCAPE_INSTALLED=1
    INKSCAPE_CMD="inkscape"
else
    # Inkscape not in PATH - check common installation locations (macOS only)
    if [ "$OS_TYPE" = "Darwin" ]; then
        # Check common macOS installation paths
        if [ -f "/Applications/Inkscape.app/Contents/MacOS/inkscape" ]; then
            INKSCAPE_PATH="/Applications/Inkscape.app/Contents/MacOS/inkscape"
            INKSCAPE_INSTALLED=1
            INKSCAPE_CMD="$INKSCAPE_PATH"
        elif [ -f "$HOME/Applications/Inkscape.app/Contents/MacOS/inkscape" ]; then
            INKSCAPE_PATH="$HOME/Applications/Inkscape.app/Contents/MacOS/inkscape"
            INKSCAPE_INSTALLED=1
            INKSCAPE_CMD="$INKSCAPE_PATH"
        fi
        
        # Notify user if found but not in PATH
        if [ -n "$INKSCAPE_PATH" ]; then
            echo
            echo "Inkscape is not in your PATH, but was found at: $INKSCAPE_PATH"
            echo
            echo "While not necessary for this script, if you want to use Inkscape CLI yourself,"
            echo "you can add it to your PATH by adding this line to your shell profile (~/.zprofile, ~/.bash_profile, or ~/.bashrc):"
            echo "  export PATH=\"/Applications/Inkscape.app/Contents/MacOS:\$PATH\""
            echo
        fi
    fi
fi

PNG_EXISTS=0
SVG_EXISTS=0
[ -f "source/favicon.png" ] && PNG_EXISTS=1
[ -f "source/favicon.svg" ] && SVG_EXISTS=1

if [ -n "$SOURCE_FORMAT" ]; then
    : # SOURCE_FORMAT already set, skip to validation
elif [ $PNG_EXISTS -eq 0 ] && [ $SVG_EXISTS -eq 0 ]; then
    echo "Error: No source file found. Please create either source/favicon.png or source/favicon.svg, ≥ 1024px square."
    exit 1
elif [ $SVG_EXISTS -eq 1 ] && [ $PNG_EXISTS -eq 0 ]; then
    SOURCE_FORMAT="svg"
elif [ $PNG_EXISTS -eq 1 ] && [ $SVG_EXISTS -eq 0 ]; then
    SOURCE_FORMAT="png"
else
    # Both files exist - prompt user
    while true; do
        echo
        echo "Select source format:"
        echo "  1. SVG (default)"
        echo "  2. PNG"
        echo
        read -p "Enter choice (1 or 2, press Enter for default): " FORMAT_CHOICE
        
        if [ -z "$FORMAT_CHOICE" ] || [ "$FORMAT_CHOICE" = "1" ]; then
            SOURCE_FORMAT="svg"
            break
        elif [ "$FORMAT_CHOICE" = "2" ]; then
            SOURCE_FORMAT="png"
            break
        else
            echo "\"$FORMAT_CHOICE\" is not a valid response. Please type 1, 2, or 'Enter' to continue."
        fi
    done
fi

# Validate format
if [ "$SOURCE_FORMAT" != "png" ] && [ "$SOURCE_FORMAT" != "svg" ]; then
    echo "Error: Invalid source format. Must be 'png' or 'svg'."
    exit 1
fi

SOURCE_FILE="source/favicon.$SOURCE_FORMAT"
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file not found: $SOURCE_FILE"
    if [ "$SOURCE_FORMAT" = "png" ]; then
        if [ -f "source/favicon.svg" ]; then
            echo "Note: source/favicon.svg exists. Did you mean to use SVG format?"
        fi
    else
        if [ -f "source/favicon.png" ]; then
            echo "Note: source/favicon.png exists. Did you mean to use PNG format?"
        fi
    fi
    exit 1
fi

if [ -n "$CONVERSION_TOOL" ]; then
    : # CONVERSION_TOOL already set, skip to validation
elif [ "$SOURCE_FORMAT" = "png" ]; then
    # PNG requires ImageMagick
    if [ $MAGICK_INSTALLED -eq 0 ]; then
        echo "Error: ImageMagick is required for PNG sources but is not installed."
        echo "Please install ImageMagick from https://imagemagick.org/"
        exit 1
    fi
    CONVERSION_TOOL="magick"
else
    # SVG source - check what tools are available
    if [ $MAGICK_INSTALLED -eq 0 ] && [ $INKSCAPE_INSTALLED -eq 0 ]; then
        echo "Error: No conversion tools found. Please install at least one of:"
        echo "  - ImageMagick: https://imagemagick.org/"
        echo "  - Inkscape: https://inkscape.org/"
        exit 1
    fi
    if [ $MAGICK_INSTALLED -eq 0 ] && [ $INKSCAPE_INSTALLED -eq 1 ]; then
        echo "Error: Please install ImageMagick. It is used by this script to package a multi-resolution ico file:"
        echo "  - ImageMagick: https://imagemagick.org/"
        exit 1
    fi
    
    # Build menu based on available tools - Inkscape first (preferred for SVG)
    MENU_COUNT=0
    declare -a MENU_OPTIONS
    declare -a TOOL_OPTIONS
    DEFAULT_TOOL=""
    
    if [ $INKSCAPE_INSTALLED -eq 1 ]; then
        MENU_COUNT=$((MENU_COUNT + 1))
        MENU_OPTIONS[$MENU_COUNT]="Inkscape (default - slow, with better rendering quality for complex vector SVGs)"
        TOOL_OPTIONS[$MENU_COUNT]="inkscape"
        DEFAULT_TOOL="inkscape"
    fi
    
    if [ $MAGICK_INSTALLED -eq 1 ]; then
        MENU_COUNT=$((MENU_COUNT + 1))
        MENU_OPTIONS[$MENU_COUNT]="ImageMagick"
        TOOL_OPTIONS[$MENU_COUNT]="magick"
        [ -z "$DEFAULT_TOOL" ] && DEFAULT_TOOL="magick"
    fi
    
    # If only one tool available, auto-select it
    if [ $MENU_COUNT -eq 1 ]; then
        CONVERSION_TOOL="${TOOL_OPTIONS[1]}"
    else
        while true; do
            echo
            echo "Select conversion tool for SVG:"
            for i in $(seq 1 $MENU_COUNT); do
                echo "  $i. ${MENU_OPTIONS[$i]}"
            done
            echo
            read -p "Enter choice (1-$MENU_COUNT, press Enter for default): " TOOL_CHOICE
            
            if [ -z "$TOOL_CHOICE" ]; then
                CONVERSION_TOOL="$DEFAULT_TOOL"
                break
            elif [ "$TOOL_CHOICE" -ge 1 ] 2>/dev/null && [ "$TOOL_CHOICE" -le $MENU_COUNT ] 2>/dev/null; then
                CONVERSION_TOOL="${TOOL_OPTIONS[$TOOL_CHOICE]}"
                break
            else
                if [ $MENU_COUNT -eq 2 ]; then
                    echo "\"$TOOL_CHOICE\" is not a valid response. Please type 1, 2, or 'Enter' to continue."
                else
                    echo "\"$TOOL_CHOICE\" is not a valid response. Please type 1, 2, 3, or 'Enter' to continue."
                fi
            fi
        done
    fi
fi

# Validate that the selected tool is actually installed
if [ "$CONVERSION_TOOL" = "magick" ] && [ $MAGICK_INSTALLED -eq 0 ]; then
    echo "Error: ImageMagick is not installed. Please install it from https://imagemagick.org/"
    exit 1
fi
if [ "$CONVERSION_TOOL" = "inkscape" ] && [ $INKSCAPE_INSTALLED -eq 0 ]; then
    echo "Error: Inkscape is not installed. Please install it from https://inkscape.org/"
    exit 1
fi

if [ "$CONVERSION_TOOL" != "magick" ] && [ "$CONVERSION_TOOL" != "inkscape" ]; then
    echo "Error: Invalid conversion tool. Must be 'magick' or 'inkscape'."
    exit 1
fi

if [ "$SOURCE_FORMAT" = "png" ] && [ "$CONVERSION_TOOL" = "inkscape" ]; then
    echo "Error: Inkscape can only be used with SVG sources. Use 'magick' for PNG sources."
    exit 1
fi

echo
echo "Using source format: $SOURCE_FORMAT"
echo "Using conversion tool: $CONVERSION_TOOL"
if [ -n "$MAGICK_CMD" ]; then
    echo "ImageMagick command: $MAGICK_CMD"
fi
echo "Source file: $SOURCE_FILE"
echo
echo "Generating favicons..."
if [ "$CONVERSION_TOOL" = "inkscape" ]; then
    echo
    echo "Inkscape is a complete GUI application that loads its entire rendering engine, even when run from command line."
    echo "Please wait patiently..."
fi
echo

if [ "$SOURCE_FORMAT" = "png" ]; then
    "$MAGICK_CMD" "$SOURCE_FILE" -filter Lanczos -resize 16x16 ../globalBuildResources/favicon.png
    "$MAGICK_CMD" "$SOURCE_FILE" -filter Lanczos -resize 20x20 ../globalBuildResources/favicon@1.25x.png
    "$MAGICK_CMD" "$SOURCE_FILE" -filter Lanczos -resize 24x24 ../globalBuildResources/favicon@1.5x.png
    "$MAGICK_CMD" "$SOURCE_FILE" -filter Lanczos -resize 28x28 ../globalBuildResources/favicon@1.75x.png
    "$MAGICK_CMD" "$SOURCE_FILE" -filter Lanczos -resize 32x32 ../globalBuildResources/favicon@2x.png
else
    if [ "$CONVERSION_TOOL" = "magick" ]; then
        "$MAGICK_CMD" -background none MSVG:"$SOURCE_FILE" -filter Lanczos -resize 16x16 ../globalBuildResources/favicon.png
        "$MAGICK_CMD" -background none MSVG:"$SOURCE_FILE" -filter Lanczos -resize 20x20 ../globalBuildResources/favicon@1.25x.png
        "$MAGICK_CMD" -background none MSVG:"$SOURCE_FILE" -filter Lanczos -resize 24x24 ../globalBuildResources/favicon@1.5x.png
        "$MAGICK_CMD" -background none MSVG:"$SOURCE_FILE" -filter Lanczos -resize 28x28 ../globalBuildResources/favicon@1.75x.png
        "$MAGICK_CMD" -background none MSVG:"$SOURCE_FILE" -filter Lanczos -resize 32x32 ../globalBuildResources/favicon@2x.png
    elif [ "$CONVERSION_TOOL" = "inkscape" ]; then
        "$INKSCAPE_CMD" "$SOURCE_FILE" --export-filename=../globalBuildResources/favicon.png --export-width=16 --export-height=16
        "$INKSCAPE_CMD" "$SOURCE_FILE" --export-filename=../globalBuildResources/favicon@1.25x.png --export-width=20 --export-height=20
        "$INKSCAPE_CMD" "$SOURCE_FILE" --export-filename=../globalBuildResources/favicon@1.5x.png --export-width=24 --export-height=24
        "$INKSCAPE_CMD" "$SOURCE_FILE" --export-filename=../globalBuildResources/favicon@1.75x.png --export-width=28 --export-height=28
        "$INKSCAPE_CMD" "$SOURCE_FILE" --export-filename=../globalBuildResources/favicon@2x.png --export-width=32 --export-height=32
    fi
fi

cp ../globalBuildResources/favicon.png building_blocks/for_favicon_ico/favicon_16x16.png
cp ../globalBuildResources/favicon@2x.png building_blocks/for_favicon_ico/favicon_32x32.png
"$MAGICK_CMD" building_blocks/for_favicon_ico/favicon_16x16.png building_blocks/for_favicon_ico/favicon_32x32.png ../globalBuildResources/favicon.ico

echo
echo "***************************************************************************************************"
echo "* Review rendering quality of smaller size icons                                                  *"
echo "*      - See favicon*.png in the \`globalBuildResources\` directory                                 *"
echo "*      - See \`for_favicon_ico\` directory                                                          *"
echo "* Consider if smaller sizes need a different variation.                                           *"
echo "*                                                                                                 *"
echo "* This script places its final product - \`favicon.ico\` - in the \`globalBuildResources\` directory. *"
echo "*                                                                                                 *"
echo "* NOTE: Re-running this script over-writes the same files it creates!                             *"
echo "*                                                                                                 *"
echo "* To recreate favicon.ico from custom files, run this from the \`for_favicon_ico\` directory:       *"
if [ "$MAGICK_CMD" = "convert" ]; then
    echo "* \`convert favicon_16x16.png favicon_32x32.png favicon.ico\`                                      *"
else
    echo "* \`magick favicon_16x16.png favicon_32x32.png favicon.ico\`                                        *"
fi
echo "***************************************************************************************************"
echo
