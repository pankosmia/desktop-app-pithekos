#%%APP_NAME%% %%APP_VERSION%% Linux CLI

For first use of any app built on Pankosmia:
  1. Run the server: `./%%FILE_APP_NAME%%.sh` (Or right-click `%%FILE_APP_NAME%%.sh` in your File Browser, then "Run as Program")
       This will launch localhost at the port utilized in Firefox (if available) or in your default web browser.
  2. Re-connect from your web browser as needed. Look in the terminal window for the link to use.

If upgrading from versions prior to 0.4.0-rc1:
  ***************************************************************************************
  * Prior to 0.4.0, local projects were stored inside `~/pankosmia_working`.            *
  * Starting with 0.4.0 they are stored separately in `~/pankosmia_repos`.              *
  ***************************************************************************************
  1. Launch and open in a web browser as outlined at the top of this README. That will create a new `~/panksomia_repos/` directory, where "~" is the OS user home directory.
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

Best viewed with a Graphite-enabled browser such as Firefox, Zen Browser, LibreWolf or via Electronite.
