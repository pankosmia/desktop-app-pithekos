# branding
Logo implementation for Panskosmia-related projects

<span id="toc">————————————————————————————</span>

### Contents:
1. [Recommendations](#recommendations)<br />
1.1. [Design Tips](#design-tips)<br />
1.2. [Conversion Tool](#conversion-tool) 
2. [Source Images](#source) 
3. [Generate via script from source images](#generate)  
3.1. [favicon.ico (Browser) / favicon*.png (Windows/Linux Electronite)](#generate-favicon)  
3.2. [icon*.png's for icon.icns - MacOS desktop (Applications, Launchpad prior to Tahoe, and Dock icon)](#generate-icon-icns)  
3.3. [icon.ico and linux_icon.png - Windows desktop and start menu and Linux (Ubuntu) application menu](#generate-icon-ico-png)  
4. [Additional Detail](#additional)  
4.1. [Which image files are used in this repo's build process?](#used)  
4.2. [favicon*.png - Electronite Browser Window icon (Windows and Linux)](#electron)  
4.3. [icon.icns - Alternate approaches - MacOS Desktop](#alternate-icns)  
5. [Endnotes](#endnotes)  

————————————————————————————
<span id="recommendations">&nbsp;</span>
## Recommendations <sub><sup>... [↩](#toc)</sup></sub>
<span id="design-tips">&nbsp;</span>
### Design Tips <sub><sup>... [↩](#toc)</sup></sub>
Favicons and some taskbar/dock launchers call for support as small as 16px.  When re-sizing a high quality file to a small png, clarity is a function of pixel-fitting -- simplifying shapes, consistent stroke widths, and aligning edges to the pixel grid. Be prepared for the possibility of need to simplify or redraw details that won’t survive at 16px.

The following ***"simple"*** design approaches will yield the best results:
- straight vertical/horizontal lines
- with a width of at least 1 full pixel (when converted at 16px)
- on a plain background

Note that it is also possible to make a specific small variant for improved clarity (e.g., @ 16px square) .
<span id="conversion-tool">&nbsp;</span>
### Conversion Tool <sub><sup>... [↩](#toc)</sup></sub>
Conversion scripts provided recognize what type of source files are provided and which tool is installed. If there is only one type of source and one conversion tool, then they just run. Otherwise, they present available options for quick selection.

| Square Source (1:1 aspect ratio) | Conversion Tool | ICO Packager |
|---|---|---|
| Vector SVG or EPS, complex design | Inkscape | ImageMagick |
| PNG ≥ 1024px square | ImageMagick | ImageMagick |
| Vector SVG, "simple" design | Inkscape or ImageMagick | ImageMagick |

#### Inkscape
If your source files will be vector SVGs with complex design then install Inkscape -- [Windows/MacOS](https://inkscape.org/) | linux: `sudo apt install inkscape`. If the source is EPS, consider that [Inkscape](https://inkscape.org/) can also be used to convert EPS to a vector SVG.

Inkscape can't build an ICO holding multiple PNG images at different sizes. Provided scripts use ImageMagick for that step.

If converting a vector svg file not created by Inkscape, then it's CLI will recognize any instances of CSS properties not support, ignore them, and return a warning. Review the output in such instances to confirm it remains satisfactory.

#### ImageMagick
If your source files will be PNG then install ImageMagick.
- Linux: `sudo apt install imagemagick`
- Windows: [download](https://imagemagick.org/script/download.php#windows)
- MacOS: `brew install imagemagick`

ImageMagick can also be used with a vector SVG source. However, Inkscape may yield better rendering quality except on a "simple" design.

If converting a vector svg file that contains CSS properties not support, then ImageMagick will fail to recognize this and will plow on through its conversion without ignoring them. Review its output identify if it is satisfactory.


<span id="source">&nbsp;</span>
## Source Images <sub><sup>... [↩](#toc)</sup></sub>
Three source images are required. Place these images in the `source` subdirectory of `branding`. It is important that they have a 1:1 aspect ratio (width:height), as in precisely square. Any PNG source must be at least 1024px x 1024px or larger:
- favicon.png
- mac_icon.png
  - Transparent margins, with a solid inner square background with rounded corners.
- win_icon.png
  - Small transparent margin, with solid inner background optional.
<span id="generate">&nbsp;</span>
## Generate via script from source images <sub><sup>... [↩](#toc)</sup></sub>
All but the final icns step can be generated from any system
<span id="generate-favicon">&nbsp;</span>
### favicon.ico (Browser) / favicon*.png (Windows/Linux Electronite) <sub><sup>... [↩](#toc)</sup></sub>
The following script generates favicon.ico for the Web Browser tab icon and favicon*.png's for the Electronite Browser Window icon (Windows and Linux). It places favicon.ico and favicon*.png in the `globalBuildResources` directory, and it also puts the building blocks it used to build favicon.ico in the `building blocks\for_favicon_ico` subdirectory of `branding`.

1. Create favicon.svg or favicon.png and place it in the `source` subdirectory, one level down from `branding`.
2. In a terminal, cd to the new subdirectory.
3. In the terminal enter the following from the `branding` directory:
   - Windows: `.\favicon.bat`
   - Linux/MacOS: `./favicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building blocks/for_favicon_ico` subdirectory of `branding`, look over the rendering quality of both images at 100% resolutions. They may require customization. See [Design Tips](#design-tips).
  - To recreate favicon.ico from custom files, in a terminal from the `building blocks/for_favicon_ico` subdirectory of `branding` run:
    - `magick -verbose favicon_16x16.png favicon_32x32.png favicon.ico` Replace "magick" with "convert" on older linux installs.
  - If you make any changes and run the script on the line immediately above, then also replace the `favicon.ico` in the `globalBuildResources` directory with your improved version.
- If `favicon_16x16.png` was improved, then copy it over `globalBuildResources/favicon.png` (used by Electron).
- If `favicon_32x32.png` was improved, then copy it over `globalBuildResources/favicon@2x.png` (used by Electron).
- If any changes are made to one or both of the last two files mentioned above, then see [favicon*.png - Electronite Browser Window icon (Windows and Linux)](#electron) for the names and file-sizes of other globalBuildResources/favicon*.png to review for potential similar customizations at 20px, 24px and 28px.

<span id="generate-icon-icns">&nbsp;</span>
### icon*.png's for icon.icns - MacOS Desktop (Applications, Launchpad prior to Tahoe, and Dock icon) <sub><sup>... [↩](#toc)</sup></sub>
The following script generates icon*.png's - for creating .icns for MacOS. It does not creates the actual icns file. However, it does provide png's for use in creating the icns file. It places these icon*.png building blocks in the `building blocks\for_icon_icns` subdirectory of `branding`.

1. Create mac_icon.svg or mac_icon.png and place it in the `source` subdirectory, one level down from `branding`.
2. In the terminal enter the following from the `branding` directory:
   - Windows: `.\macicon.bat`
   - Linux/MacOS: `./macicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building blocks/for_icon_icns` subdirectory of `branding`, look over the rendering quality of `icon_16x16.png` and `icon_32x32.png` at 100% resolution. They may require customization. See [Design Tips](#design-tips).
  - If changes are made to `icon_16x16.png` then adjust the corresponding icon_16x16@2x.png so its design matches `icon_16x16.png` at 32px square.
  - If changes are made to `icon_32x32.png` then adjust the corresponding icon_32x32@2x.png so its design matches `icon_32x32.png` at 64px square.

Create icon.icns with iconutil on MacOS as follows:

1. __On MacOS__, create a folder _on your desktop_ and put the following in it:
   - icon_16x16.png
   - icon_16x16<!-- -->@2x.png<sup id="a2">[[2]](#f2)</sup>
   - icon_32x32.png
   - icon_32x32<!-- -->@2x.png<sup id="a3">[[3]](#f3)</sup>
   - icon_128x128.png
   - icon_128x128<!-- -->@2x.png<sup id="a4">[[4]](#f4)</sup>
   - icon_256x256.png
   - icon_256x256<!-- -->@2x.png<sup id="a5">[[5]](#f5)</sup>
   - icon_512x512.png
   - icon_512x512<!-- -->@2x.png<sup id="a6">[[6]](#f6)</sup>
2. Rename the folder to: icon.iconset
3. In a terminal enter: `cd Desktop`
4. Then enter: `iconutil -c icns icon.iconset`
5. Use the icon.icns file created on your MacOS Desktop. Place it in the `globalBuildResources` of this repo.
<span id="generate-icon-ico-png">&nbsp;</span>
### icon.ico and linux_icon.png - Windows desktop and start menu and Linux (Ubuntu) application menu <sub><sup>... [↩](#toc)</sup></sub>
Windows desktop and start menu icons leverage multiple sizes for optimal display. Consider 16x16, 32x32, 48x48, and 256x256 pixels. This will support high-DPI displays and desktop shortcuts.

The Linux (Ubuntu) application menu is currently set to use a 256x256 pixel image. Manually change linux_icon.png in globalBuildResources if a different resolution is preferred. Multiple png resolutions or svg are not supported by workflow scripts as currently provided.

The following script generates icon.ico, placing it in the `globalBuildResources` directory, and puts the building blocks it used to build icon.ico in the `building blocks\for_icon_ico` subdirectory of `branding`.  It also places a copy of `building_blocks/for_icon_ico/win_icon_256x256.png` in `globalBuildResources/linux_icon.png`.

1. Create win_icon.svg or win_icon.png and place it in the new subdirectory.
2. In the terminal enter the following from the `branding` directory:
   - Windows: `.\winicon.bat`
   - Linux/MacOS: `./winicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building_blocks/for_icon_ico` subdirectory of `branding`, look over the rendering quality of `win_icon_16x16.png` and `win_icon_32x32.png` at 100% resolution. They may require customization. See [Design Tips](#design-tips).
  - To recreate icon.ico from custom files, in a terminal from the `building blocks/for_icon_ico` subdirectory of `branding` run:
    - `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico` 
  - If you make any changes and run the script in the line immediately above, then also replace the `icon.ico` in the `globalBuildResources` directory with your improved version.
  - Replace "magick" with "convert" on older linux installs.

---
---

<span id="additional">&nbsp;</span>
## Additional Detail

<span id="used">&nbsp;</span>
### Which image files are used in this repo's build process? <sub><sup>... [↩](#toc)</sup></sub>

That would be the following images, located in `globalBuildResources`:

<blockquote>
<table>
<tr><th>Filename</th><th>Where Applied</th></tr>
<tr><td>favicon.ico</td><td>Web Browser tab</td></tr>
<tr><td>favicon.png<td rowspan="5">Windows and Linux only:<br /> Electron taskbar,<br /> window title bar,<br /> and Alt+Tab/task switcher<br /> <em>(Not applicable to MacOS)</em></td></tr>
<tr><td>favicon@1.25.png</td></tr>
<tr><td>favicon@1.5x.png</td></tr>
<tr><td>favicon@1.75x.png</td></tr>
<tr><td>favicon@2x.png</td></tr>
<tr><td>icon.ico</td><td>Windows desktop and start menu</td></tr>
<tr><td>linux_icon.png</td><td>Linux (Ubuntu) applications menu</td></tr>
<tr><td>icon.icns</td><td>MacOS Applications, Launchpad, and Dock</td></tr>
</table>
</blockquote>

<span id="electron">&nbsp;</span>
### favicon*.png - Electronite Browser Window icon (Windows and Linux) <sub><sup>... [↩](#toc)</sup></sub>
Electron adjusts its display for differing DPI densities through a special naming convention. The base filename (favicon.png) is specified in the startup file, and Electron automatically switches to higher-resolution variants based on the system's display scaling.

| # | Filename | Size (in pixels) | DPI Scale |
| --- | --- | --- | ---- |
| 1. | favicon.png | 16x16 | 100% |
| 2. | favicon<!-- -->@1.25x.png | 20x20 | 125% |
| 3. | favicon<!-- -->@1.5x.png | 24x24 | 150% |
| 4. | favicon<!-- -->@1.75x.png	| 28x28 |	175% |
| 5. | favicon<!-- -->@2x.png | 32x32 | 200% |

These icons appear in the taskbar, window title bar, and Alt+Tab/task switcher while the application is running on Windows and Linux. The larger versions come into play when a user scales their resolution to 125%, 150%, 175%, or 200%.
<span id="alternate-icns">&nbsp;</span>
### icon.icns - Alternate approaches - MacOS Desktop <sub><sup>... [↩](#toc)</sup></sub>
The support section of [the icns wikipedia article](https://en.wikipedia.org/wiki/Apple_Icon_Image_format#Support) cites several options for creating an icns file. However, avoid Icon Composer. It is unable to create high-resolution icns files used on retina displays.

ImageMagick does not yet support the icns file format at the time this is being written. Check in on its [latest list of supported format](https://imagemagick.org/script/formats.php#supported) to see if that has changed.

---
---

<span id="endnotes">&nbsp;</span>
## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help`, or `convert -help` on older linux installs. ... [↩](#a1)  
[<b id="f2">2</b>] ... If an icon_16x16.png with a different design from icon_32x32.png is in use, then icon_16x16@2x.png should match the 16px square design at 32px square.  Otherwise icon_16x16@2x.png and icon_32x32.png will be the same with different filenames. Both are needed. ... [↩](#a2)  
[<b id="f3">3</b>] ... If an icon_32x32.png with a different design from the source mac_icon.svg/mac_icon.png, then icon_32x32@2x.png should match the 32px square design at 64px square. ... [↩](#a3)  
[<b id="f4">4</b>] ... If an icon_128x128.png with a different design from icon_256x256.png is in use, then icon_128x128@2x.png should match the 128px square design at 256px square.  Otherwise icon_128x128@2x.png and icon_256x256.png will be the same with different filenames. Both are needed.  ... [↩](#a4)  
[<b id="f5">5</b>] ... If an icon_256x256.png with a different design from icon_512x512.png is in use, then icon_256x256@2x.png should match the 256px square design at 512px square.  Otherwise icon_256x256@2x.png and icon_512x512.png will be the same with different filenames. Both are needed. ... [↩](#a5)  
[<b id="f6">6</b>] ... If an icon_512x512.png with a different design from the source mac_icon.svg/mac_icon.png, then icon_512x512@2x.png should match the 512px square design at 1024px square. ... [↩](#a6)  
