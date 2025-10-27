@echo off

REM 1. Create mac_icon_1024x1024.png and place it in the `source` subdirectory, one level down from `branding`.
REM 2. Run this script in a terminal by entering: `.\icnsicon.bat` from the `branding` directory.
REM Note that re-running this script over-writes files it just created (or any other files of the same names).

@echo on

magick source\mac_icon_1024x1024.png -resize 1.5625%% building_blocks\for_icon_icns\icon_16x16.png
magick building_blocks\for_icon_icns\icon_16x16.png -resize 200%% building_blocks\for_icon_icns\icon_16x16@2x.png

magick source\mac_icon_1024x1024.png -resize 3.125%% building_blocks\for_icon_icns\icon_32x32.png
magick building_blocks\for_icon_icns\icon_32x32.png -resize 200%% building_blocks\for_icon_icns\icon_32x32@2x.png

magick source\mac_icon_1024x1024.png -resize 12.5%% building_blocks\for_icon_icns\icon_128x128.png
magick building_blocks\for_icon_icns\icon_128x128.png -resize 200%% building_blocks\for_icon_icns\icon_128x128@2x.png

magick source\mac_icon_1024x1024.png -resize 25%% building_blocks\for_icon_icns\icon_256x256.png
magick building_blocks\for_icon_icns\icon_256x256.png -resize 200%% building_blocks\for_icon_icns\icon_256x256@2x.png

magick source\mac_icon_1024x1024.png -resize 50%% building_blocks\for_icon_icns\icon_512x512.png
magick building_blocks\for_icon_icns\icon_512x512.png -resize 200%% building_blocks\for_icon_icns\icon_512x512@2x.png

copy source\mac_icon_1024x1024.png building_blocks\for_icon_icns\icon_1024x1024.png
magick building_blocks\for_icon_icns\icon_1024x1024.png -resize 200%% building_blocks\for_icon_icns\icon_1024x1024@2x.png

@echo off

echo.
echo ********************************************************************************************
echo * Review smaller size icons for small detail and any anti-aliasing issues.                 *
echo *      - See `for_icon_icns` directory                                                     *
echo * Consider if smaller sizes need a different variation.                                    *
echo *                                                                                          *
echo * Expect icon*@2x.png icons to look different. They are scaled-up for use in icns creation.*
echo *                                                                                          *
echo * NOTE: Re-running this script over-writes the same files it creates!                      *
echo *                                                                                          *
echo * To creating icon.icns with these file using iconutil on MacOS:                           *
echo *  1. On MacOS, create a folder _on your desktop_ and put the following in it:             *
echo *     icon_16x16.png                                                                       *
echo *     icon_16x16@2x.png                                                                    *
echo *     icon_32x32.png                                                                       *
echo *     icon_32x32@2x.png                                                                    *
echo *     icon_128x128.png                                                                     *
echo *     icon_128x128@2x.png                                                                  *
echo *     icon_256x256.png                                                                     *
echo *     icon_256x256@2x.png                                                                  *
echo *     icon_512x512.png                                                                     *
echo *     icon_512x512@2x.png                                                                  *
echo *     icon_1024x1024.png                                                                   *
echo *     icon_1024x1024@2x.png                                                                *
echo *  2. Rename the folder to: icon.iconset                                                   *
echo *  3. In a terminal enter: `cd Desktop`                                                    *
echo *  4. Then enter: `iconutil -c icns icon.iconset`                                          *
echo *  5. Use the icon.icns file created on your Desktop.                                      *
echo ********************************************************************************************
echo.