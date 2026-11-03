%%APP_NAME%%
MacOS %%ARCH%% Portable App

Place all contents of this directory and any subdirectories on any exFAT-formatted drive.

If you did not download the zipped version of this portable app from the Internet directly onto a MacOS machine, then it is not quarantined and you can run it by double-clicking %%APP_NAME%% in a file browser.

However, if you did download the zipped version of this portable app from the Internet directly onto a MacOS machine, then from a terminal run `./unquarantine.sh` one time, then run by double-clicking %%APP_NAME%% in a file browser.

Once a quarantined app has been unquarantined, then it should stay unquarantined, with that script not needing to be run again.
________________________

It is recommended that you run this portable app from removable media like a usb. If run from a location like your Desktop or Downloads or Documents, then in the latest MacOS versions you will get a message that says '"Electron" would like to access files in your download folder.' You must choose Allow to run the portable app from such a location. Some earlier version of MacOS do not present this message rather require users to grant this permission permissions under `Settings > Privacy and Security > Files & Folders > Terminal`.

________________________

If you get a message saying "Not Opened" when double-clicking %%APP_NAME%% in a file browser, then click "Done" or "Cancel", then from a terminal run `./unquarantine.sh` one time, then run by double-clicking %%APP_NAME%% in a file browser.

________________________

If you get "can't open the file" or something else similar, then:
    * Was 'Move to Trash' selected on %%APP_NAME%% on a prior attempt to run? If so, then find it in your trash and 'put back', depending on which of those options you have, then from a terminal run `./unquarantine.sh` one time, then run by double-clicking %%APP_NAME%% in a file browser.

________________________

From the MacOS version Golden Gate (and possibly others), this portable app will not work with permissions granted through System Settings, which is why `./unquarantine.sh` is provided.

________________________