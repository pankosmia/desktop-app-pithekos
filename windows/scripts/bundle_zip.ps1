# This script uses the APP_VERSION environment variable as defined in app_config.env

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_zip.ps1
# with the optional arguments of: `.\bundle_zip.ps1 -ServerOff "Y"` or: `.\bundle_zip.ps1 -ServerOff "y"`
# and: `.\bundle_zip.ps1 -IsGHA "Y"` or: `.\bundle_zip.ps1 -IsGHA "y"`

# This script is also used with gh action runner with the -ServerOff switch set to yes and -IsGHA set to yes. All three of `app_setup.bat` and `npm ci` and 'node build.js` have already run in earlier steps in windows-build-steps.yml

param(
    [string]$ServerOff,
    [string]$IsGHA
)

if ($ServerOff -eq 'Y') {
  $answer = $ServerOff
} else {
  echo "`n"
  $answer = Read-Host "     Is the server off? [Y/n]: "
}

if ($answer -eq 'Y' -Or $answer -eq '') {
    echo "`n"
    echo "Continuing..."
    echo "`n"

  get-content ..\..\app_config.env | foreach {
    $name, $value = $_.split('=')
    if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('#')) {
      # skip empty or comment line in ENV file
      return
    }
    Set-Variable -Name $name -Value $value
  }

  if ($IsGHA -ne 'Y') {
    cd ..\..\
    # echo "checkout main"
    # git checkout main | Out-Null
    # echo "pull"
    # git pull
    # echo "npm ci"
    # npm ci
    echo "`n"
    echo "Running app_setup to ensure version number consistency between buildSpec.json and this build bundle:"
    cd windows\scripts
    .\app_setup.bat
  }

  echo "`n"
  echo "Version is $APP_VERSION"
  echo "`n"

  if ($IsGHA -ne 'Y') {
    cd ..\..\
    If (Test-Path releases\windows\*.zip) {
      echo "A previous windows .zip release exists. Removing..."
      Remove-Item releases\windows\*.zip
    }
    cd windows\scripts
    if (Test-Path ..\build) {
      echo "Removing last build environment"
      rm ..\build -r -force
    }
    echo "Assembling build environment"
    node build.js
  }

  cd ..\build
  echo "`n"
  echo "   *****************************************************************************************"
  echo "   *                                                                                       *"
  echo "   *                                          =====                                        *"
  echo "   * Bundling. Wait for the powershell prompt AFTER the compression progress bar finishes. *"
  echo "   *                                          =====                                        *"
  echo "   *                                                                                       *"
  echo "   *****************************************************************************************"
  echo "`n"

  # Use lower case app name in filename and replace spaces with dashes (-) and remove single apostrophes (')
  $APP_NAME = $APP_NAME.ToLower().Replace(" ","-").Replace("'","")
  Compress-Archive * ..\..\releases\windows\$APP_NAME-windows-$APP_VERSION.zip

if ($IsGHA -ne 'Y') {
  cd ..\scripts
} else {
  cd ..\install
}

} elseif ($answer -eq 'N') {
    echo "`n"
    echo "     Exiting..."
    echo "`n"
    echo "     If the server is on, turn it off by exiting the terminal window in which it is running, then re-run this script.";
    echo "`n"
} else {
    echo "`n"
    echo """$answer"" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
    .\bundle_zip.ps1
}