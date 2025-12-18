@echo off

REM 1. Create win_icon_1024x1024.png and place it in the `source` subdirectory, one level down from `branding.
REM 2. Run this script in a terminal by entering: `.\winicon.bat` from the `branding` directory.
REM Note that re-running this script over-writes files it just created (or any other files of the same names).

@echo on

magick source\win_icon_1024x1024.png -resize 1.5625%% building_blocks\for_icon_ico\win_icon_16x16.png
magick source\win_icon_1024x1024.png -resize 3.125%% building_blocks\for_icon_ico\win_icon_32x32.png
magick source\win_icon_1024x1024.png -resize 4.6875%% building_blocks\for_icon_ico\win_icon_48x48.png
magick source\win_icon_1024x1024.png -resize 25%% building_blocks\for_icon_ico\win_icon_256x256.png
magick -verbose building_blocks\for_icon_ico\win_icon_16x16.png building_blocks\for_icon_ico\win_icon_32x32.png building_blocks\for_icon_ico\win_icon_48x48.png building_blocks\for_icon_ico\win_icon_256x256.png ..\globalBuildResources\icon.ico

REM For Linux
copy building_blocks\for_icon_ico\win_icon_256x256.png ..\globalBuildResources\linux_icon.png


@echo off

echo.
echo ************************************************************************************************************
echo * Review smaller size icons for small detail and any anti-aliasing issues.                                 *
echo *      - See `for_icon_ico` directory                                                                      *
echo * Consider if smaller sizes need a different variation.                                                    *
echo *                                                                                                          *
echo * This script places its final product - `icon.ico` - in the `globalBuildResources` directory.             *
echo *                                                                                                          *
echo * NOTE: Re-running this script will over-write the same files it creates!                                  *
echo *                                                                                                          *
echo * To recreate icon.ico from custom files, run this from the `for_icon_ico` directory:                      *
echo * `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico` *
echo *                                                                                                          *
echo * To recreate linux Application Menu/Desktop png, manually change globalBuildResources\linux_icon.png      *
echo *      - The script has set that at 256x256 pixels.  Use a different resolution if preferred.              *
echo *      -  Multiple png resolutions or svg are not supported by workflow scripts as currently provided.     *
echo ************************************************************************************************************
echo.