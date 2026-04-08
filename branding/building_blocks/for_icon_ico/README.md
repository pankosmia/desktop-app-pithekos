# branding - icon.ico and linux_icon.png - Windows desktop and start menu and Linux (Ubuntu) application menu
Logo implementation for Panskosmia-related projects

- Once the winicon script is run in a terminal from the branding directory, this folder (`for_icon_ico`) will contain building blocks for icon.ico.

## This folder (`for_icon_ico`)
This folder is a container to house building block images created and used by scripts in the `branding` directory.

With respect to uploading these files to a public github repo, delete them after running those scrips if you do not want to do that. However, consider that the icon.icns distributed with your app will contain a 1024px x 1024px version of the log you use for this icon. So, anyone interesting in a high resolution of your icon will already have easy access that one.

## New Forks from Desktop-App-Template
If this project is a fork from desktop-app-template, then this folder will initially contain building block images from that project. They will be replaced by images applicable to your project once scripts in `branding` are run with your images in `source`. If you do not want these files in your repo, then delete them once everything you need is in `globalBuildResources`.

### icon.ico
Windows desktop and start menu icons leverage multiple sizes for optimal display. Consider 16x16, 32x32, 48x48, and 256x256 pixels. This will support high-DPI displays and desktop shortcuts.

The Linux (Ubuntu) application menu is currently set to use a 256x256 pixel image. Manually change linux_icon.png in globalBuildResources if a different resolution is preferred. Multiple png resolutions or svg are not supported by workflow scripts as currently provided.

Review the following:
- In the `building_blocks/for_icon_ico` subdirectory of `branding`, look over the rendering quality of `win_icon_16x16.png` and `win_icon_32x32.png` at 100% resolution. They may require customization. See [Design Tips](#design-tips).
  - To recreate icon.ico from custom files, in a terminal from the `building blocks/for_icon_ico` subdirectory of `branding` run:
    - `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico` 
  - If you make any changes and run the script in the line immediately above, then also replace the `icon.ico` in the `globalBuildResources` directory with your improved version.
  - Replace "magick" with "convert" on older linux installs.
<br />
---
---

<span id="endnotes">&nbsp;</span>
## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help`, or `convert -help` on older linux installs. ... [↩](#a1) 