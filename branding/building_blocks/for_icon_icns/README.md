# branding - icon.icns - MacOS Desktop (Applications, Launchpad prior to Tahoe, and Dock icon)
Logo implementation for Panskosmia-related projects

- Once the macicon script is run in a terminal from the branding directory, this folder (`for_icon_icns`) will contain building blocks for icon.icns.

## This folder (`for_icon_icns`)
This folder is a container to house building block images created and used by scripts in the `branding` directory.

With respect to uploading these files to a public github repo, delete them after running those scrips if you do not want to do that. However, consider that the icon.icns distributed with your app will contain a 1024px x 1024px version of the log you use for this icon. So, anyone interesting in a high resolution of your icon will already have easy access that one.

## New Forks from Desktop-App-Template
If this project is a fork from desktop-app-template, then this folder will initially contain building block images from that project. They will be replaced by images applicable to your project once scripts in `branding` are run with your images in `source`. If you do not want these files in your repo, then delete them once everything you need is in `globalBuildResources`.

## icon.icns
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
<span id="additional">&nbsp;</span>
## Additional Detail

### icon.icns - Alternate approaches - MacOS Desktop <sub><sup>...
The support section of [the icns wikipedia article](https://en.wikipedia.org/wiki/Apple_Icon_Image_format#Support) cites several options for creating an icns file. However, avoid Icon Composer. It is unable to create high-resolution icns files used on retina displays.

ImageMagick does not support the icns file format at the time this is being written. Check in on its [latest list of supported format](https://imagemagick.org/script/formats.php#supported) to see if that has changed.  

---
---

## Endnotes <sub><sup>... [↩](#toc)</sup></sub>
[<b id="f1">1</b>] ... ImageMagick tip: See `magick -help`, or `convert -help` on older linux installs. ... [↩](#a1)  
[<b id="f2">2</b>] ... If an icon_16x16.png with a different design from icon_32x32.png is in use, then icon_16x16@2x.png should match the 16px square design at 32px square.  Otherwise icon_16x16@2x.png and icon_32x32.png will be the same with different filenames. Both are needed. ... [↩](#a2)  
[<b id="f3">3</b>] ... If an icon_32x32.png with a different design from the source mac_icon.svg/mac_icon.png, then icon_32x32@2x.png should match the 32px square design at 64px square. ... [↩](#a3)  
[<b id="f4">4</b>] ... If an icon_128x128.png with a different design from icon_256x256.png is in use, then icon_128x128@2x.png should match the 128px square design at 256px square.  Otherwise icon_128x128@2x.png and icon_256x256.png will be the same with different filenames. Both are needed.  ... [↩](#a4)  
[<b id="f5">5</b>] ... If an icon_256x256.png with a different design from icon_512x512.png is in use, then icon_256x256@2x.png should match the 256px square design at 512px square.  Otherwise icon_256x256@2x.png and icon_512x512.png will be the same with different filenames. Both are needed. ... [↩](#a5)  
[<b id="f6">6</b>] ... If an icon_512x512.png with a different design from the source mac_icon.svg/mac_icon.png, then icon_512x512@2x.png should match the 512px square design at 1024px square. ... [↩](#a6)  
