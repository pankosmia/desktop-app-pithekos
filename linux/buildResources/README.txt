#%%APP_NAME%% %%APP_VERSION%% Linux

For first use of any app built on Pankosmia:
  1. Run the server: `.\%%APP_NAME%%` (Or right-click `%%APP_NAME%%` in your File Browser, then "Run as Program")
       This will launch localhost at the port utilized in Firefox (if available) or in your default web browser.
  2. Re-connect from your web browser as needed. Look in the terminal window for the link to use.

If unsure, check to see if `~/panksomia_working/` and/or `~/panksomia_repos/` already exist.
  If neither exists, then follow the "First use" instructions above.
  If `~/panksomia_working/` exists, but not `~/panksomia_repos/`, then follow the "Upgrade from versions prior to 0.4.0-rc1" instructions below.
  If both `~/panksomia_working/` and `~/panksomia_repos/` already exist, then follow the "Upgrade from 0.4.0-rc1 or greater" instructions below.

Upgrade from versions prior to 0.4.0-rc1:
  1. Make a copy of `~/panksomia_working/repos` where "~" is the OS user home directory.
  2. Delete `~/panksomia_working/`
  3. Run the server: `.\%%APP_NAME%%` (Or right-click `%%APP_NAME%%` in your File Browser, then "Run as Program")
     This will launch localhost at the port utilized in Firefox (if available) or in your default web browser.
  4. Restore the backup copy from step 1 to `~/panksomia_repos/` such that the prior immediate subdirectories of `~/panksomia_working/repos` are now immediate subdirectores of `~/panksomia_repos/`.
     The resulting directory structure should be along the lines of the following
     ~
     └───panksomia_repos
         ├───_git.door43.org
         │   └───[...more subdirectories]
         └───_local_
             └───_local_
                 └───[...more subdirectories]
  5. Re-connect from your web browser as needed. Look in the terminal window for the link to use.

Upgrade from 0.4.0-rc1 or greater:
  1. Delete `~/panksomia_working/`
  2. Run the server: `.\%%APP_NAME%%` (Or right-click `%%APP_NAME%%` in your File Browser, then "Run as Program")
       This will launch localhost at the port utilized in Firefox (if available) or in your default web browser.
  3. Restore backup from step 1 to `~/panksomia_working/repos`
  4. Re-connect from your web browser as needed. Look in the terminal window for the link to use.

Best viewed with a Graphite-enabled browser such as Firefox, Zen Browser, LibreWolf or via Electronite.
