# branding - icon.ico - Windows and Linux Desktop
Logos etc for Panskosmia-related projects

- Once the winicon script is run in a terminal from the branding directory, this folder (`for_icon_ico`) will contain building blocks for icon.ico.

## This folder (`for_icon_ico`)
This folder is a container to house building block images created and used by scripts in the `branding` directory.

With respect to uploading these files to a public github repo, delete them after running those scrips if you do not want to do that. However, consider that the icon.icns distributed with your app will contain a 1024px x 1024px version of the log you use for this icon. So, anyone interesting in a high resolution of your icon will already have easy access that one.

## New Forks from Desktop-App-Template
If this project is a fork from desktop-app-template, then this folder will initially contain building block images from that project. They will be replaced by images applicable to your project once scripts in `branding` are run with your images in `source`. If you do not want these files in your repo, then delete them once everything you need is in `globalBuildResources`.

### icon.ico
Windows desktop and start menu icons leverage multiple sizes for optimal display. Consider 16x16, 32x32, 48x48, and 256x256 pixels. This will support high-DPI displays and desktop shortcuts.

Review the following:
- In the `building blocks/for_icon_ico` subdirectory of `branding`, look over `win_icon_16x16.png` and `win_icon_32x32.png` for things like anti-aliasing issues. They may tend need some pixel-level touch-up with respect to anti-aliasing, or other adjustments.
  - To recreate icon.ico from custom files, in a terminal from the `building blocks/for_icon_ico` subdirectory of `branding` run this [ImageMagick](https://imagemagick.org/)<sup id="a1">[[1]](#f1)</sup> command:
    - `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico`
  - If you make any changes, then replace the `icon.ico` in the `globalBuildResources` directory with your improved version.  
<br />
---
---

<span id="endnotes">&nbsp;</span>
## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help` ... [↩](#a1)  