@echo off

REM 1. Create favicon_1024x1024.png and place it in the `source` subdirectory, one level down from `branding`.
REM 2. Run this script in a terminal by entering: `.\favicon.bat` from the `branding` directory.
REM Note that re-running this script over-writes files it just created (or any other files of the same names).

REM favicon.png, favicon@1.25x.png, favicon@1.5x.png, and favicon@2x.png are for Electron
REM favicon_16x16.png and favicon_32x32.png are building blocks for favicon.ico

@echo on

magick source\favicon_1024x1024.png -resize 1.5625%% ..\globalBuildResources\favicon.png
magick source\favicon_1024x1024.png -resize 1.953125%% ..\globalBuildResources\favicon@1.25x.png
magick source\favicon_1024x1024.png -resize 2.34375%% ..\globalBuildResources\favicon@1.5x.png
magick source\favicon_1024x1024.png -resize 3.125%% ..\globalBuildResources\favicon@2x.png
copy ..\globalBuildResources\favicon.png building_blocks\for_favicon_ico\favicon_16x16.png
copy ..\globalBuildResources\favicon@2x.png building_blocks\for_favicon_ico\favicon_32x32.png
magick -verbose building_blocks\for_favicon_ico\favicon_16x16.png building_blocks\for_favicon_ico\favicon_32x32.png ..\globalBuildResources\favicon.ico

@echo off

echo.
echo ***************************************************************************************************
echo * Review smaller size icons for small detail and any anti-aliasing issues.                        *
echo *      - See favicon*.png in the `globalBuildResources` directory                                 *
echo *      - See `for_favicon_ico` directory                                                          *
echo * Consider if smaller sizes need a different variation.                                           *
echo *                                                                                                 *
echo * This script places its final product - `favicon.ico` - in the `globalBuildResources` directory. *
echo *                                                                                                 *
echo * NOTE: Re-running this script over-writes the same files it creates!                             *
echo *                                                                                                 *
echo * To recreate favicon.ico from custom files, run this from the `for_favicon_ico` directory:       *
echo * `magick -verbose favicon_16x16.png favicon_32x32.png favicon.ico`                               *
echo ***************************************************************************************************
echo.