#%%APP_NAME%% %%APP_VERSION%% MacOS %%ARCH%%

If this was downloaded over the Internet directly onto a MacOS machine, then it will need to be unquarantined before it can be installed.

If that is not the case, then double-click %%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg to start the installer.

Otherwise:
 * Run `./unquarantine.sh` from a terminal and then double-click %%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg to start the installer.
 * Alternatively, double-click %%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg and...
    * If the installer starts then it is not quarantined.
    * More likely you will get a message saying "Not Opened".
      * Click either "Done" or "Cancel", and avoid clicking on Move to Trash.
      * Then Go to Apple menu > System Settings (Preferences) >  Privacy and Security, and at the bottom where it shows the file that was blocked, click "Open (Allow) Anyway" .
        * In Golden Gate that brings up a confirmation dialog where "Open Anyway" will need to be selected, followed by a password prompt.
        * Some MacOS versions may need double-clicking again on %%FILE_APP_NAME%%-%%APP_VERSION%%-macos-%%ARCH%%.pkg
    * If you get "can't open the file" or something else similar, then:
      * Look under Settings > Privacy and Security > Files & Folders > Terminal, and see if you need to turn on permissions for Desktop, OR, move your %%FILE_APP_NAME%%%% folder to another location or re-unzip in another location and run from there in a terminal.
      * Or, if 'Move to Trash' was selected, then you can find it in your trash and 'put back'.

_______________________________________________________________________________

For first use of any app built on Pankosmia:
  After installation, run %%APP_NAME%% from Applications.

If upgrading from versions prior to 0.4.0-rc1:
  ***************************************************************************************
  * Prior to 0.4.0, local projects were stored inside `~/pankosmia_working`.            *
  * Starting with 0.4.0 they are stored separately in `~/pankosmia_repos`.              *
  ***************************************************************************************
  1. Launch %%APP_NAME%% from Applications. That will create a new `~/panksomia_repos/` directory, where "~" is the OS user home directory.
  2. Copy or move all contents `~/panksomia_working/repos/` into `~/panksomia_repos/`.
     The resulting directory structure should be along the lines of the following
     ~
     └───panksomia_repos
         ├───_git.door43.org
         │   └───[...more subdirectories]
         └───_local_
             └───_local_
                 └───[...more subdirectories]
  3. Delete `~/panksomia_working/` at any time.

This app leverages Graphite-enabled Electronite for font feature support.