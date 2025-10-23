# <span id="toc">CHANGELOG</span>
- [10 Oct 2025](#10-oct-2025)
- [3 Oct 2025](#3-oct-2025)
- [21 Aug 2025](#21-aug-2025)
- [19 Aug 2025](#19-aug-2025)
- [16 Aug 2025](#16-aug-2025)
- [14 Jul 2025](#14-jul-2025)

## <span id="10-oct-2025">10 Oct 2025</span>  ... [↩](#toc)</sup></sub>
- General:
  - More subtle snackbar colours
  - Better use of MUI themes
  - Resolved horizontal Padauk and Awami Nastaliq collisions 

- Editors:
  - Floating editor tool bar

## <span id="3-oct-2025">3 Oct 2025</span>  ... [↩](#toc)</sup></sub>
- General:
  - Indonesian localization
  - Improved main menu
- Content management:
  - Improved export including zip
  - Improved dashboard
  - Improved language picker
- Remote content:
  - Show remote updates
  - Download manager as modal
  - Version control manager supporting push, pull and merge with control over remotes and branches
- Editors:
  - MUI for shared Scripture editor
  - USFM <=> USJ now uses Proskomma
  - Distraction-free editing mode
  - Fixes to drafting editor
- Build / Development Environment:
  - Electronite Development Viewer (linux)
  - Icon generation for varying build contexts
  - Github Actions and local build process improvements
  - Streamline dev script prompts

## <span id="21-aug-2025">21 Aug 2025</span>  ... [↩](#toc)</sup></sub>
- Electronite Development Viewer (macos)
- Optional script arguments for developers (macos)
- Other dev script improvements

## <span id="19-aug-2025">19 Aug 2025</span>  ... [↩](#toc)</sup></sub>
- Prevent extraneous files from listing in the UI
- New editor for Open Bible Stories (text and audio, basic video generation)
- Optional script arguments for developers (linux)

## <span id="16-aug-2025">16 Aug 2025</span>  ... [↩](#toc)</sup></sub>
- Now built with Electronite (macos and windows)
- New, experimental "by unit of meaning" Scripture editor
- Archiving and quarantining burritos
- Adding and changing remote for local burritos
- Filter proposed workspace resources by project type
- Checksum-based detection of unsaved changes
- Electron-aware "unsaved changes" dialog (currently for OBS only)
- Server-based backup file management
- Improved and more consistent navigation
- Lots of tidying of the UI (more MUI, more use of MUI theme, data grids replace static tables, more consistency)
- Refactoring of server, addition of new endpoints to support new client functionality
- Optional script arguments for developers (windows)
- Electronite Developer Viewer (windows)
- Github actions master build workflow

## <span id="14-jul-2025">14 Jul 2025</span>  ... [↩](#toc)</sup></sub>
### General
- Fix scroll and page height issues
- Make margins/padding more consistent
- Upgrade fonts
- Various server refactoring and tweaking

### Download
- Use data grid instead of table (sort, filter)
- Use blended font
- Show one spinner per download
- Faster/more reliable switching between orgs

### Content
- Use data grid instead of table (sort, filter)
- Filter by language
- Create BCV project (tN, tQ, sQ)
- Create OBS project

### Workspace
- Match heading to tile size
- BCV resource editor (tN, tQ, sQ)
- OBS editor
- OBS viewer
- OBS resource viewers (tN, tW, tQ, sQ)
- Try cards in Masonry layout for resource picker
- Improved BCV viewers including accordion for questions and tW
- Images slideshow (eg FIA images and maps)
- Juxtalinear viewer
- Basic audio "viewer"

### Settings
- Upgrade fonts: Gentium, Gentium Book, Charis, and Andika

###	Desktop App Template
- Setup and Maintenance Scripts (linux, macos, and windows):
  - App setup - as per app config file
  - Clone - all client repos and resources as per app config file
  - Build clients - main branch of all clients as per app config file
  - Sync - keeps forks current with intended differences excluded
- Development Environment Scripts (linux, macos, and windows):
  - Build Server - builds the server and assembles client builds
  - Run - re-assembles client builds and starts the server
  - Clean - removes client builds and cleans the server
  - Bundle - packages the server and client builds
- Github Action Workflows (linux, macos, and windows):
  - Follows app config file
  - Clones all repos
  - Builds all clients
  - Builds server
  - Assembles artifacts (tgz, zip, exe, pkg)
  - Run manually from app repos as needed
