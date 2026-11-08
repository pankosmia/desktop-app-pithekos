#%%APP_NAME%% %%APP_VERSION%% Windows

For first use of any app built on Pankosmia, simply launch %%APP_NAME%%.

If upgrading from versions prior to 0.4.0-rc1:
  ***************************************************************************************
  * Prior to 0.4.0, local projects were stored inside `~/pankosmia_working`.            *
  * Starting with 0.4.0 they are stored separately in `~/pankosmia_repos`.              *
  ***************************************************************************************
  1. Launch %%APP_NAME%%. That will create a new `~/panksomia_repos/` directory, where "~" is the OS user home directory.
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