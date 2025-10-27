# branding
Logos etc for Panskosmia-related projects

<span id="toc">————————————————————————————</span>

### Contents:
1. [Source Images](#source)
2. [Generate via script from source images](#generate)  
2.1. [favicon.ico / favicon*.png - corner/tab of Viewer/Browser](#generate-favicon)  
2.2. [icon*.png's for icon.icns - MacOS Desktop (Applications, Launchpad, and Dock icon)](#generate-icon-icns)  
2.3. [icon.ico - Windows and Linux Desktop and Start Menu](#generate-icon-ico)  
3. [Additional Detail](#additional)  
3.1. [Which image files are used in this repo's build process?](#used)  
3.2. [favicon*.png - Electronite Browser Window icon (Windows and Linux)](#electron)  
3.3. [icon.icns - Alternate approaches - MacOS Desktop](#alternate-icns)  
3.4. [icon.ico (Windows and Linux desktop and start menu icon)](#icon-ico)  
4. [Endnotes](#endnotes)  

————————————————————————————
<span id="source">&nbsp;</span>
## Source Images <sub><sup>... [↩](#toc)</sup></sub>
Three source images are required. Place these images in the `source` subdirecftory of `branding`:
- favicon_1024x1024.png
- mac_icon_1024x1024.png
  - Transparent margins, with a solid inner square background with rounded corners.
- win_icon_1024x1024.png
  - Small transparent margin, with solid inner background optional.
<span id="generate">&nbsp;</span>
## Generate via script from source images <sub><sup>... [↩](#toc)</sup></sub>
All but the final icns step can be generated from any system
1. Install ImageMagick
  - Linux: [download](https://imagemagick.org/script/download.php#linux)
  - Windows: [download](https://imagemagick.org/script/download.php#windows)
  - MacOS: `brew install imagemagick`
<span id="generate-favicon">&nbsp;</span>
### favicon.ico (Browser) / favicon*.png (Electronite) <sub><sup>... [↩](#toc)</sup></sub>
The following script generates favicon.ico for the Web Browser tab icon and favicon*.png's for the Electronite Browser Window icon (Windows and Linux). It places favicon.ico and favicon*.png in the `globalBuildResources` directory, and it also puts the building blocks it used to build favicon.ico in the `building blocks\for_favicon_ico` subdirectory of `branding`.

1. Create favicon_1024x1024.png and place it in the `source` subdirectory, one level down from `branding`.
2. In a terminal, cd to the new subdirectory.
3. In the terminal enter the following from the `branding` directory:
   - Windows: `.\favicon.bat`
   - Linux/MacOS: `./favicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building blocks/for_favicon_ico` subdirectory of `branding`, look over both images for things like anti-aliasing issues. They may tend need some pixel-level touch-up with respect to anti-aliasing, or other adjustments.
  - To recreate favicon.ico from custom files, in a terminal from the `building blocks/for_favicon_ico` subdirectory of `branding` run:
    - `magick -verbose favicon_16x16.png favicon_32x32.png favicon.ico`
  - If you make any changes, then replace the `favicon.ico` in the `globalBuildResources` directory with your improved version.
- If `favicon_16x16.png` was improved, then copy it over `globalBuildResources/favicon.png` (used by Electron).
- If `favicon_32x32.png` was improved, then copy it over `globalBuildResources/favicon@2x.png` (used by Electron).

<span id="generate-icon-icns">&nbsp;</span>
### icon*.png's for icon.icns - MacOS Desktop (Applications, Launchpad, and Dock icon) <sub><sup>... [↩](#toc)</sup></sub>
The following script generates icon*.png's - for creating .icns for MacOS. It does not creates the actual icns file. However, it does provide png's for use in creating the icns file. It places these icon*.png building blocks in the `building blocks\for_icon_icns` subdirectory of `branding`.

1. Create icon_1024x1024.png and place it in the `source` subdirectory, one level down from `branding`.
2. In the terminal enter the following from the `branding` directory:
   - Windows: `.\macicon.bat`
   - Linux/MacOS: `./macicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building blocks/for_icon_icns` subdirectory of `branding`, look over `icon_16x16.png` and `icon_32x32.png` for things like anti-aliasing issues. They may tend need some pixel-level touch-up with respect to anti-aliasing, or other adjustments.
  - If changes are made to `icon_16x16.png` or `icon_32x32.png` then adjust the upscaled version as well so that it matches. Do this by running the applicable of the following in a terminal from the `building blocks/for_icon_icns` subdirectory of `branding`:
    - `magick icon_16x16.png -resize 200%% icon_16x16@2x.png`  
    - `magick icon_32x32.png -resize 200%% icon_32x32@2x.png`

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
   - icon_1024x1024.png
   - icon_1024x1024<!-- -->@2x.png<sup id="a7">[[7]](#f7)</sup>
2. Rename the folder to: icon.iconset
3. In a terminal enter: `cd Desktop`
4. Then enter: `iconutil -c icns icon.iconset`
5. Use the icon.icns file created on your MacOS Desktop. Place it in the `globalBuildResources` of this repo.
<span id="generate-icon-ico">&nbsp;</span>
### icon.ico - Windows and Linux Desktop and Start Menu <sub><sup>... [↩](#toc)</sup></sub>
Windows desktop and start menu icons leverage multiple sizes for optimal display. Consider 16x16, 32x32, 48x48, and 256x256 pixels. This will support high-DPI displays and desktop shortcuts.

The following script generates icon.ico, placing it in the `globalBuildResources` directory, and puts the building blocks it used to build icon.ico in the `building blocks\for_icon_ico` subdirectory of `branding`.

1. Create win_icon_1024x1024.png and place it in the new subdirectory.
2. In the terminal enter the following from the `branding` directory:
   - Windows: `.\winicon.bat`
   - Linux/MacOS: `./winicon.sh`
   - Note that re-running these script over-writes files it just created (or any other files of the same names).

Review the following after running this script:
- In the `building blocks/for_icon_ico` subdirectory of `branding`, look over `win_icon_16x16.png` and `win_icon_32x32.png` for things like anti-aliasing issues. They may tend need some pixel-level touch-up with respect to anti-aliasing, or other adjustments.
  - To recreate icon.ico from custom files, in a terminal from the `building blocks/for_icon_ico` subdirectory of `branding` run:
    - `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico`
  - If you make any changes, then replace the `icon.ico` in the `globalBuildResources` directory with your improved version.

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
<tr><td>favicon.png<td rowspan="4">Windows and Linux<br />Electronite<br />Browser<br />Window<br /><em>(Not applicable to MacOS)</em></td></tr>
<tr><td>favicon@1.25.png</td></tr>
<tr><td>favicon@1.5x.png</td></tr>
<tr><td>favicon@2x.png</td></tr>
<tr><td>icon.ico</td><td>Windows and Linux desktop and start menu</td></tr>
<tr><td>icon.icns</td><td>MacOS Applications, Launchpad, and Dock</td></tr>
</table>
</blockquote>

<span id="electron">&nbsp;</span>
### favicon*.png - Electronite Browser Window icon (Windows and Linux) <sub><sup>... [↩](#toc)</sup></sub>
The Electronite Browser Window support displays with different DPI densities at the same through a special naming convention. The first of the following is named in the start up file, and Electron switches it out with other variations where applicable.

| # | Filename | Size (in pixels) | DPI Scale |
| --- | --- | --- | ---- |
| 1. | favicon.png | 16x16 | 100% |
| 2. | favicon<!-- -->@1.25x.png | 20x20 | 125% |
| 3. | favicon<!-- -->@1.5x.png | 24x24 | 150% |
| 4. | favicon<!-- -->@2x.png | 32x32 | 200% |
<span id="alternate-icns">&nbsp;</span>
### icon.icns - Alternate approaches - MacOS Desktop <sub><sup>... [↩](#toc)</sup></sub>
The support section of [the icns wikipedia article](https://en.wikipedia.org/wiki/Apple_Icon_Image_format#Support) cites several options for creating an icns file. However, avoid Icon Composer. It is unable to create high-resolution icns files used on retina displays.

ImageMagick does not yet support the icns file format at the time this is being written. Check in on its [latest list of supported format](https://imagemagick.org/script/formats.php#supported) to see if that has changed.
<span id="icon-ico">&nbsp;</span>

---
---

<span id="endnotes">&nbsp;</span>
## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help` ... [↩](#a1)  
[<b id="f2">2</b>] ... This is a scaled-up version, different from icon_32x32.png, e.g., `magick icon_16x16.png -resize 200% icon_16x16@2x.png` ... [↩](#a2)  
[<b id="f3">3</b>] ... `magick icon_32x32.png -resize 200% icon_32x32@2x.png` ... [↩](#a3)  
[<b id="f4">4</b>] ... This is a scaled-up version, different from icon_256x256.png, e.g., `magick icon_128x128.png -resize 200% icon_128x128@2x.png`  ... [↩](#a4)  
[<b id="f5">5</b>] ... This is a scaled-up version, different from icon_512x512.png, e.g., `magick icon_256x256.png -resize 200% icon_256x256@2x.png` ... [↩](#a5)  
[<b id="f6">6</b>] ... This is a scaled-up version, different from icon_1024x1024.png, e.g., `magick icon_512x512.png -resize 200% icon_512x512@2x.png` ... [↩](#a6)  
[<b id="f7">7</b>] ... `magick icon_1024x1024.png -resize 200% icon_1024x1024@2x.png` ... [↩](#a7)  
