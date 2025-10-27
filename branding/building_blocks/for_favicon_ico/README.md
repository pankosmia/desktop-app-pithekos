# branding - favicon.ico (Browser) / favicon*.png (Electronite)
Logos etc for Panskosmia-related projects

- Once the favicon script is run in a terminal from the branding directory, this folder (`for_favicon_ico`) will contain building blocks for favicon.ico.

## This folder (`for_favicon_ico`)
This folder is a container to house building block images created and used by scripts in the `branding` directory.

With respect to uploading these files to a public github repo, delete them after running those scrips if you do not want to do that. However, consider that the icon.icns distributed with your app will contain a 1024px x 1024px version of the log you use for this icon. So, anyone interesting in a high resolution of your icon will already have easy access that one.

## New Forks from Desktop-App-Template
If this project is a fork from desktop-app-template, then this folder will initially contain building block images from that project. They will be replaced by images applicable to your project once scripts in `branding` are run with your images in `source`. If you do not want these files in your repo, then delete them once everything you need is in `globalBuildResources`.

### favicon.ico / favicon*.png
- Look over both images for things like anti-aliasing issues. They may tend need some pixel-level touch-up with respect to anti-aliasing, or other adjustments.
  - To recreate favicon.ico from custom files, in a terminal from the `building blocks\for_favicon_ico` subdirectory of `branding` run this[ImageMagick](https://imagemagick.org/)<sup id="a1">[[1]](#f1)</sup> command:
    - `magick -verbose favicon_16x16.png favicon_32x32.png favicon.ico`
  - If you make any changes, then replace the `favicon.ico` in the `globalBuildResources` directory with your improved version.
- If `favicon_16x16.png` was improved, then in copy it over `globalBuildResources/favicon.png` (used by Electronite).
- If `favicon_32x32.png` was improved, then copy it over `globalBuildResources/favicon@2x.png` (used by Electronite).  
<br />
---
---
## Additional Detail

### favicon*.png - Electronite Browser Window icon (Windows and Linux) <sub><sup>... [↩](#toc)</sup></sub>
The Electronite Browser Window support displays with different DPI densities at the same through a special naming convention. The first of the following is named in the start up file, and Electron switches it out with other variations where applicable.

| # | Filename | Size (in pixels) | DPI Scale |
| --- | --- | --- | ---- |
| 1. | favicon.png | 16x16 | 100% |
| 2. | favicon<!-- -->@1.25x.png | 20x20 | 125% |
| 3. | favicon<!-- -->@1.5x.png | 24x24 | 150% |
| 4. | favicon<!-- -->@2x.png | 32x32 | 200% |
<span id="endnotes">&nbsp;</span>
## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help` ... [↩](#a1)  