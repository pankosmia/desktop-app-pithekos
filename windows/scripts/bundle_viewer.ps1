# This script uses the APP_VERSION environment variable as defined in app_config.env

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_viewer.ps1
# with the optional arguments of: .\bundle_viewer.ps1 -ServerOff "Y"
# or: .\bundle_viewer.ps1 -ServerOff "y"

param(
    [string]$ServerOff
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

  If (-Not (Test-Path ..\..\local_server\target\release\local_server.exe)) {
    echo "`n"
    echo "   *****************************************************************************************"
    echo "   * IMPORTANT: Build the local server (without the -d argument), then re-run this script! *"
    echo "   *****************************************************************************************"
    echo "`n"
    exit
  }

  $TEMP_DIR = "..\temp"
    if (Test-Path $TEMP_DIR) {
        Write-Host "Deleting previous build..."
        Write-Host "`n"
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

  # The bundle_zip script will ensure the latest is checked out, the clone is installed, and the app_setup script is run
  echo "`n"
  echo "Bundling Zip..."
  echo "  - updates the build environment for the Electronite package build,"
  echo "  - and creates a zip bundle that parallels the Electronite package."
  .\bundle_zip.ps1 -ServerOff "Y"

  echo "`n"
  echo "Version is $APP_VERSION"
  echo "`n"

  Write-Host "`n"
  Write-Host "`n"
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`"Getting Electron release`" downloads an approximately 120 MB file." -f cyan;
  Write-Host "Please wait patiently for the highlighted download process to complete..." -f cyan;
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`n"

  ..\install\makeAllInstallsElectronite.ps1 -IsGHA "N"

} elseif ($answer -eq 'N') {
    echo "`n"
    echo "     Turn the server off by exiting the terminal window in which it is running, then re-run this script while the server is off."
    echo "`n"
} else {
    echo "`n"
    echo """$answer"" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
    .\bundle_viewer.ps1
}