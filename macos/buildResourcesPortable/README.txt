%%APP_NAME%%
MacOS %%ARCH%% Portable App

Place all contents of this directory and any subdirectories on any exFAT-formatted drive.

If the zipped version of this portable app was not downloaded from the Internet directly onto a MacOS machine, then it should not be quarantined and should be able to run by a double-click on %%APP_NAME%% in a file browser.

However, if the zipped version of this portable app was downloaded from the Internet directly onto a MacOS machine, then from a terminal run `./unquarantine.sh`. After this, run by double-clicking %%APP_NAME%% in a file browser.

The unquarantine script can be deleted once the portrable app has been run successfully. 

________________________

It is recommended that you run this portable app from removable media like a usb. If placed in your Desktop, Downloads or Documents directory, then in the latest MacOS versions you will get a message that says '"Electron" would like to access files in your download folder.' Select "Allow" to run the portable app from such a location. Some earlier version of MacOS do not present this message rather require users to grant this permission permissions under `Settings > Privacy and Security > Files & Folders > Terminal`.

________________________

If you get a message saying "Not Opened" when double-clicking %%APP_NAME%% in a file browser, click "Done" or "Cancel", then from a terminal run `./unquarantine.sh` one time, and then launch the app by double-clicking %%APP_NAME%% in a file browser.

________________________

If you get "can't open the file" or something else similar, then:
    * Was 'Move to Trash' selected on %%APP_NAME%% on a prior attempt to run? If so, then find it in your trash and 'put back', depending on which of those options you have, then from a terminal run `./unquarantine.sh` one time, then run by double-clicking %%APP_NAME%% in a file browser.

________________________

This portable app will not work with permissions granted through System Settings, which is why `./unquarantine.sh` is provided.

________________________