<#
.SYNOPSIS
    Creates a Windows installer package for the application.

.DESCRIPTION
    This PowerShell script prepares and builds a Windows installer for the application using Inno Setup.
    It creates the necessary directory structure, copies required files, and compiles the installer.

.PARAMETER arch
    The target architecture for the installer (e.g., x64, x86).

.PREREQUISITES
    - Inno Setup 6 must be installed at "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    - APP_VERSION environment variable must be set in app_config.env

.OUTPUTS
    Creates an installer at releases\windows\$arch\<app-name>_installer_*.exe

.NOTES
    - Cleans up existing installers before building
    - Creates directory structure in .\windows\$pkgDir\project\payload\<app-name>
    - Copies necessary files including Electron, README, bin, and lib directories
    - Compiles the installer using Inno Setup

.PARAMETER arch
Target architecture for the installer (e.g., x64, x86)

.PARAMETER Dev
Specify -Dev "Y" when generating a development viewer.
- Default is "N"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$arch,

    [Parameter(Mandatory=$false)]
    [string]$Dev
)

# Save the initial working directory
$initialLocation = Get-Location

try {
    # Check if APP_VERSION environment variable is set
    if (-not $env:APP_VERSION) {
        Write-Host "Error: APP_VERSION environment variable is not set."
        Write-Host "Set it in app_config.env"
        exit 1
    }
    
    # Check if APP_NAME environment variable is set
    if (-not $env:APP_NAME) {
        Write-Host "Error: APP_NAME environment variable is not set."
        Write-Host "Set it in app_config.env"
        exit 1
    }
    
    # Check if FILE_APP_NAME environment variable is set
    if (-not $env:FILE_APP_NAME) {
        Write-Host "Warning: FILE_APP_NAME environment variable is not set. Generating..."
        $fileAppName = $env:APP_NAME.ToLower().Replace(" ","-").Replace("'","")   # Use lower case app name in filename and replace spaces with dashes (-) and remove single apostrophes (')
        $env:FILE_APP_NAME = $fileAppName
        echo "FILE_APP_NAME=$env:FILE_APP_NAME"
    }

    Write-Host "Version is $env:APP_VERSION"

    # Needed for local bundles. Not required in GHA but does no harm.
    if ($Dev -ne 'Y') {
        # Clean up any existing installers
        Get-ChildItem -Path "..\..\releases\windows\"$fileAppName"_installer_*.exe" | Remove-Item -Force
    }

    # Change to build directory
    Set-Location -Path "..\build" -ErrorAction Stop

    # Create folder structure for package
    Write-Host "Building folder structure for package..."

    if ($Dev -eq 'Y') {
      $pkgDir = "viewer"
    } else {
        $pkgDir = "temp"
    }

    # Clean up and create project directories -- Needed for local bundles; Not required in GHA but also doesn't hurt anything.
    Remove-Item -Path "..\$pkgDir\project" -Recurse -Force -ErrorAction SilentlyContinue
    $projectPath = "..\$pkgDir\project"
    $payloadPath = Join-Path $projectPath "payload\app"

    New-Item -ItemType Directory -Force -Path $payloadPath | Out-Null

    # Copy appLauncherElectron.bat and find_free_port.bat
    $startupSrc = "..\buildResources\appLauncherElectron.bat"
    $portCheckerSrc = "..\buildResources\find_free_port.bat"
    $startupDest = "$payloadPath"
    if (Test-Path $startupSrc) {
        New-Item -ItemType Directory -Force -Path $startupDest | Out-Null
        Copy-Item -Path $startupSrc -Destination "$startupDest\appLauncherElectron.bat" -Force
        Copy-Item -Path $portCheckerSrc -Destination "$startupDest\find_free_port.bat" -Force
    }

    # Copy electron files
    Write-Host "Copying Electron files..."
    try {
        # Copy all the general electron files
        $electronSrcPath = Join-Path $PSScriptRoot "..\..\buildResources\electron"
        $electronDestPath = Join-Path $payloadPath "electron"
        $electronDestPath = Join-Path $payloadPath "electron"

        Write-Host "Electron source path: $electronSrcPath" -ErrorAction SilentlyContinue
        Write-Host "Electron destination path: $electronDestPath" -ErrorAction SilentlyContinue

        # Ensure source exists
        if (-not (Test-Path $electronSrcPath)) {
            Write-Error "Source path not found: $electronSrcPath"
            exit 1
        }
        
        # Ensure destination parent exists
        $destParent = Split-Path -Parent $electronDestPath
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        # Copy main electron files
        Copy-Item -Path $electronSrcPath -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
        Write-Host "Successfully copied electron files"

        # Copy main electron browser window icon
        $electronIconSrc = Join-Path $PSScriptRoot "..\..\globalBuildResources\favicon*.png"
        Write-Host "Copying favicon*.png to $electronDestPath ..."
        Copy-Item $electronIconSrc -Destination $electronDestPath

        # Determine which startup to use -- dev viewer or production
        if ($Dev -eq "Y") {
          Remove-Item $electronDestPath\electronStartup.js
          Copy-Item $electronDestPath\electronDevStartup.js $electronDestPath\electronStartup.js
          Remove-Item $electronDestPath\electronDevStartup.js
        } else {
          Remove-Item $electronDestPath\electronDevStartup.js
        }
        
        # Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
        (Get-Content $electronDestPath\electronStartup.js).Replace('${APP_NAME}', $env:APP_NAME) | Set-Content $electronDestPath\electronStartup.js
        (Get-Content "$electronDestPath\package.json").Replace('${APP_NAME}', $env:APP_NAME).Replace('${APP_VERSION}', $env:APP_VERSION) | Set-Content "$electronDestPath\package.json"
        
        # Copy architecture-specific files
        $archElectronPath = Join-Path $PSScriptRoot "..\$pkgDir\electron.$arch"
        Write-Host "Electron arch path: $archElectronPath" -ErrorAction SilentlyContinue

        if (Test-Path $archElectronPath) {
            Copy-Item -Path "$archElectronPath\*" -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully copied architecture-specific files"
        } else {
            Write-Warning "Architecture-specific path not found: $archElectronPath"
        }
    }
    catch {
        Write-Error "Failed to copy electron files: $_"
        exit 1
    }

    if ($Dev -ne 'Y') {
        # Copy README
        $readmeSrc = "..\build\README.txt"
        $readmeDest = "$payloadPath"
        if (Test-Path $readmeSrc) {
            New-Item -ItemType Directory -Force -Path $readmeDest | Out-Null
            Copy-Item -Path $readmeSrc -Destination "$readmeDest\README.txt" -Force
        }

        # Copy bin and lib directories from build directory
        if (Test-Path ".\bin") {
            Copy-Item -Path ".\bin" -Destination $payloadPath -Recurse -Force
        }
        if (Test-Path ".\lib") {
            Copy-Item -Path ".\lib" -Destination $payloadPath -Recurse -Force
        }

      # Create and copy scripts if needed
      $scriptsPath = "$projectPath\scripts"
      New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

      # Call Inno Setup to create installer
      Write-Host "Building installer..."

      $innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
      if (-not (Test-Path $innoSetupPath)) {
          Write-Host "Error: Inno Setup not found at $innoSetupPath"
          exit 1
      }

      Set-Location -Path ".."
      $outputPath = "..\releases\windows\$arch"

      # Delete existing exe files from releases directory, only if path exists
      if (Test-Path "$outputPath\*.exe") {
          Get-ChildItem -Path "$outputPath\*.exe" | Remove-Item -Force
      }

      $setupScript = ".\install\makeInstallElectronite.iss"

      Write-Host "Current working directory: $(Get-Location)"

      $process = Start-Process -FilePath $innoSetupPath -ArgumentList "/O`"$outputPath`"", $setupScript -NoNewWindow -Wait -PassThru
      if ($process.ExitCode -ne 0) {
          Write-Host "Error: Inno Setup compilation failed"
          exit 1
      }

      Write-Host "Installation package created successfully"
      exit 0
    }
}

finally {
    # Restore the original working directory
    Set-Location -Path $initialLocation
}