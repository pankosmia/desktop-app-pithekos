<#
.SYNOPSIS
    Creates a Windows installer package for the application.

.DESCRIPTION
    This PowerShell script prepares and builds a Windows installer for the application using Inno Setup.
    It creates the necessary directory structure, copies required files, and compiles the installer.

.PARAMETER arch
    The target architecture for the installer (e.g., x64, arm64, x86).

.PREREQUISITES
    - Inno Setup 6 must be installed at "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    - APP_VERSION environment variable must be set in app_config.env

.OUTPUTS
    Creates an installer at releases\windows\<appname>-<version>-win-<arch>.exe

.NOTES
    - Cleans up existing installers before building
    - Creates directory structure in .\windows\$pkgDir\project\payload\<app-name>
    - Copies necessary files including Electron, README, bin, and lib directories
    - Compiles the installer using Inno Setup

.PARAMETER arch
Target architecture for the installer (e.g., x64, arm64, x86)

.PARAMETER Dev
Specify -Dev "Y" when generating a development viewer.
- Default is "N"

.PARAMETER FullInstall
    Specify -FullInstall $true for installing Electronite too; -FullInstall $false for updating all but Electronite (e.g., a development environment viewer update)
    - Default is $true

.PARAMETER -p
    Specify -p for Portable App
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$arch,
    [string]$Dev = "N",
    [bool]$FullInstall = $true,
    [switch]$p,
    [switch]$pi
)

# Save the initial working directory
$initialLocation = Get-Location

$eMsg = "environment variable is not set in makeInstallElectronite.ps1."

try {
    # Check if APP_VERSION environment variable is set
    if (-not $env:APP_VERSION) {
        Write-Host "Error: APP_VERSION $eMsg"
        Write-Host "Set it in app_config.env"
        exit 1
    }
    
    # Check if APP_NAME environment variable is set
    if (-not $env:APP_NAME) {
        Write-Host "Error: APP_NAME $eMsg"
        Write-Host "Set it in app_config.env"
        exit 1
    }

    # Check if FILE_APP_NAME environment variable is set
    if (-not $env:FILE_APP_NAME) {
        Write-Host "FILE_APP_NAME $eMsg. Generating..."
        $fileAppName = $env:APP_NAME.ToLower().Replace(" ","-").Replace("'","")   # Use lower case app name in filename and replace spaces with dashes (-) and remove single apostrophes (')
        $env:FILE_APP_NAME = $fileAppName
        echo "FILE_APP_NAME=$env:FILE_APP_NAME"
    }

    # Check if APP_SHORT_NAME environment variable is set
    if (-not $env:APP_SHORT_NAME) {
        Write-Host "Error: APP_SHORT_NAME $eMsg"
        Write-Host "Set it in app_config.env"
        exit 1
    }

    Write-Host "Version is $env:APP_VERSION"

    # Needed for local bundles. Not required in GHA but does no harm.
    if ($Dev -ne 'Y') {
        # Clean up any existing installers
        Remove-Item -Path "..\..\releases\windows\$($env:FILE_APP_NAME)-*-win-$arch.exe" -Force -ErrorAction SilentlyContinue
    }

    # Change to build directory
    Set-Location -Path "..\build" -ErrorAction Stop

    # Create folder structure for package
    if ($FullInstall) {
      Write-Host "Building folder structure for package..."
    }

    if ($Dev -eq 'Y') {
      $pkgDir = "viewer"
    } else {
        $pkgDir = "temp"
    }

    # Clean up and create project directories -- Needed for local bundles; Not required in GHA but also doesn't hurt anything.

    # Use full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText()  
    $projectPath = Join-Path (Get-Location).Path "..\$pkgDir\project" 
    $payloadPath = Join-Path $projectPath "payload\app"

    if ($FullInstall -or $Dev -ne 'Y') {
        Remove-Item -Path $projectPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Force -Path $payloadPath | Out-Null

    # Copy Rocket.toml and appLauncherElectron.bat
    $rocketConfig = "..\..\Rocket.toml"
    $startupSrc = "..\buildResources\appLauncherElectron.bat"
    $startupDest = "$payloadPath"
    if (Test-Path $startupSrc) {
        New-Item -ItemType Directory -Force -Path $startupDest | Out-Null
        Copy-Item -Path $rocketConfig -Destination "$startupDest\Rocket.toml" -Force
        Copy-Item -Path $startupSrc -Destination "$startupDest\appLauncherElectron.bat" -Force
    }

    # Copy electron files
    if ($FullInstall) {
      Write-Host "Preparing Electron files..."
    } else {
      Write-Host "Preparing viewer update..."
    }
    try {
        $electronSrcPath = Join-Path $PSScriptRoot "..\..\buildResources\electron\*"
        $electronDestPath = Join-Path $payloadPath "electron"

        if ($FullInstall) {
          Write-Host "Electron source path: $electronSrcPath" -ErrorAction SilentlyContinue
          Write-Host "Electron destination path: $electronDestPath" -ErrorAction SilentlyContinue
        }

        # Ensure destination parent exists
        $destParent = Split-Path -Parent $electronDestPath
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        # Ensure source exists
        if (-not (Test-Path $electronSrcPath)) {
            Write-Error "Source path not found: $electronSrcPath"
            exit 1
        }

        # Explicitly create electron destination directory if not found 
        if (-not (Test-Path $electronDestPath)) {
            New-Item -ItemType Directory -Path $electronDestPath -Force | Out-Null
        }

        # Copy all app-specific electron files
        Copy-Item -Path $electronSrcPath -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
        Write-Host "Successfully copied app-specific electron files"
        if (-not (Test-Path $electronDestPath)) {
            Write-Error "Electron destination path not found for app-specific files: $electronDestPath"
            exit 1
        }

        # Copy main electron browser window icon
        $electronIconSrc = Join-Path $PSScriptRoot "..\..\globalBuildResources\favicon*.png"
        Write-Host "Copying favicon*.png to $electronDestPath ..."
        Copy-Item $electronIconSrc -Destination $electronDestPath -Force

        # Copy required modules and dependencies
        $nodeModulesSrc = Join-Path $PSScriptRoot "..\..\node_modules"
        $nodeModulesDest = Join-Path $electronDestPath "node_modules"

        # Explicitly create node_modules if not found
        if (-not (Test-Path $nodeModulesDest)) {
            New-Item -ItemType Directory -Path $nodeModulesDest -Force | Out-Null
        }

        # 7zip-min (full directory) -- Windows only
        $7zipMinDest = Join-Path $nodeModulesDest "7zip-min"
        New-Item -ItemType Directory -Path $7zipMinDest -Force | Out-Null
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-min\*") -Destination $7zipMinDest -Recurse -Force -ErrorAction Stop

        # 7zip-bin (selective: index.js, package.json, and arch-specific binary) -- Windows only
        $7zipBinDest = Join-Path $nodeModulesDest "7zip-bin"
        $7zipBinWinArchDest = Join-Path $7zipBinDest "win\$arch"
        New-Item -ItemType Directory -Path $7zipBinWinArchDest -Force | Out-Null
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\index.js") -Destination $7zipBinDest -Force -ErrorAction Stop
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\package.json") -Destination $7zipBinDest -Force -ErrorAction Stop
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\win\$arch\*") -Destination $7zipBinWinArchDest -Recurse -Force -ErrorAction Stop

        # Copy required modules and dependencies -- all OSes
        $allOsModules = @(
            "puppeteer-core",
            "@puppeteer\browsers",
            "chromium-bidi",
            "debug",
            "devtools-protocol",
            "ms",
            "typed-query-selector",
            "webdriver-bidi-protocol",
            "ws",
            "semver",
            "proxy-agent",
            "lru-cache",
            "agent-base",
            "proxy-from-env",
            "progress",
            "mitt"
        )

        foreach ($mod in $allOsModules) {
            $modDest = Join-Path $nodeModulesDest $mod
            New-Item -ItemType Directory -Path $modDest -Force | Out-Null
            Copy-Item -Path (Join-Path $nodeModulesSrc "$mod\*") -Destination $modDest -Recurse -Force -ErrorAction Stop
        }

        Write-Host "Successfully copied node_modules dependencies"

        # $electronDestPath is full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText() 

        # Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
        $esPath = "$electronDestPath\electronStartup.js"
        $esText = [System.IO.File]::ReadAllText($esPath).Replace('${APP_NAME}', $env:APP_NAME)
        [System.IO.File]::WriteAllText($esPath, $esText, [System.Text.UTF8Encoding]::new($false))

        $pkgPath = "$electronDestPath\package.json"
        $pkgText = [System.IO.File]::ReadAllText($pkgPath).Replace('${APP_NAME}', $env:APP_NAME).Replace('${APP_VERSION}', $env:APP_VERSION)
        [System.IO.File]::WriteAllText($pkgPath, $pkgText, [System.Text.UTF8Encoding]::new($false))
        
        if ($FullInstall) {
            # Copy architecture-specific files
            $archElectronPath = Join-Path $PSScriptRoot "..\$pkgDir\electron.$arch"
            Write-Host "Electron arch path: $archElectronPath" -ErrorAction SilentlyContinue

            if (Test-Path $archElectronPath) {
                Copy-Item -Path "$archElectronPath\*" -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully copied architecture-specific files"
            } else {
                Write-Warning "Architecture-specific path not found: $archElectronPath"
            }
        } else {
            Write-Host "Skipping architecture-specific electron file copy (not needed)."
        }
    }
    catch {
        Write-Error "Failed to prepare electron files: $_"
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

        # Portable app uses a virtual path for repo_dir
        if ($p.IsPresent) {
            $user_settings = Join-Path $payloadPath "lib\templates\user_settings.json"
            $usText = [System.IO.File]::ReadAllText($user_settings).Replace('"repo_dir": "%%HOMEDIR%%/pankosmia_repos",', '"repo_dir": "..\pankosmia_repos",')
            [System.IO.File]::WriteAllText($user_settings, $usText, [System.Text.UTF8Encoding]::new($false))
        }

        # Create and copy scripts if needed
        $scriptsPath = "$projectPath\scripts"
        New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

        # Map internal arch token to output naming
        $env:ARCH = $arch

        Set-Location -Path ".."
        $outputPath = "..\releases\windows"

        New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

        $packageBaseName = "$($env:FILE_APP_NAME)-$($env:APP_VERSION)-win-$arch"

        if ($p.IsPresent) {
            Write-Host "Building portable ZIP..."

            # These are the same sources used by install\makeInstallElectronite.iss.
            $payloadSource = ".\temp\project\payload\app"
            $iconSource = "..\globalBuildResources\icon.ico"

            # Stage the portable app under a top-level folder named after the app.
            # Use full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText()
            $portableStage = Join-Path (Get-Location).Path 'temp\project\portable-package'
            $portableAppDirName = $env:APP_NAME
            $portableAppStage = Join-Path $portableStage $portableAppDirName
            $portableZipPath = Join-Path $outputPath "$packageBaseName-portable.zip"

            if (-not (Test-Path $payloadSource)) {
                Write-Error "Portable payload directory not found: $payloadSource"
                exit 1
            }

            if (-not (Test-Path $iconSource)) {
                Write-Error "Portable icon not found: $iconSource"
                exit 1
            }

            Remove-Item -Path $portableStage -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $portableAppStage -Force | Out-Null

            # Equivalent to:
            # Source: "..\temp\project\payload\app\*"; DestDir: "{app}"
            Copy-Item `
                -Path (Join-Path $payloadSource "*") `
                -Destination $portableAppStage `
                -Recurse `
                -Force `
                -ErrorAction Stop

            # Equivalent to:
            # Source: "..\..\globalBuildResources\icon.ico"; DestDir: "{app}"
            Copy-Item `
                -Path $iconSource `
                -Destination (Join-Path $portableAppStage "icon.ico") `
                -Force `
                -ErrorAction Stop
            
            # Copy configured helper files to the ZIP root.
            $helpersSource = ".\buildResourcesPortable"
            $startAppBatDestination = Join-Path $portableStage "start.bat"
            $readMeDestination = Join-Path $portableStage "README.txt"

            $helperFiles = @(
                "start.bat",
                "README.txt"
            )

            foreach ($fileName in $helperFiles) {
                $source = Join-Path $helpersSource $fileName

                $destinationFileName = switch ($fileName) {
                    default         { $fileName }
                }

                $destination = Join-Path $portableStage $destinationFileName

                if (-not (Test-Path $source)) {
                    Write-Error "Portable helper files not found: $source"
                    exit 1
                }

                Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop

                # Replace placeholders only in the staged ZIP copy.
                $content = Get-Content -Path $destination -Raw
                $content = $content.Replace('%%APP_NAME%%', $env:APP_NAME)
                $content = $content.Replace('%%APP_SHORT_NAME%%', $env:APP_SHORT_NAME)
                $content = $content.Replace('%%ARCH%%', $env:ARCH)

                Set-Content -Path $destination -Value $content -NoNewline
            }

            # Remove the win desktop app readme that is not applicable to the portable app.
            $readmeToDel = Join-Path $portableAppStage "README.txt"
            Remove-Item -Path $readmeToDel -Force -ErrorAction SilentlyContinue

            function Update-FileText {
                param(
                    [Parameter(Mandatory)] [string] $Path,
                    [Parameter(Mandatory)] [string] $Find,     # uses `n newlines
                    [Parameter(Mandatory)] [string] $Replace   # uses `n newlines
                )

                $raw  = [System.IO.File]::ReadAllText($Path)
                $norm = $raw -replace "`r`n", "`n" -replace "`r", "`n"

                if ($norm.Contains($Replace)) {
                    Write-Host "$Path was not updated by this run; '$Replace' already present."
                    exit 1
                }
                if (-not $norm.Contains($Find)) {
                    Write-Host "Expected original text was not found in $Path ; no change made."
                    exit 1
                }

                $updated = $norm.Replace($Find, $Replace)
                [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
            }

            # $portableStage is full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText() 

            # $serverFile  = Join-Path $electronDestPath 'core\server.js'
            $serverFile = Join-Path $portableStage "$env:APP_NAME\electron\core\server.js"
            
            # $startupFile = Join-Path $electronDestPath 'electronStartup.js'
            $startupFile = Join-Path $portableStage "$env:APP_NAME\electron\electronStartup.js"

            # --- server.js ---
            $serverFind    = 'spawn(SERVER_EXECUTABLE_PATH, []'
            $serverReplace = "spawn(SERVER_EXECUTABLE_PATH, [`'../pankosmia/$env:APP_SHORT_NAME`']"
            Update-FileText -Path $serverFile -Find $serverFind -Replace $serverReplace

            # --- electronStartup.js ---
            $startupFind    = "if (START_SERVER) {`n  app.setName('$env:APP_NAME');`n} else {"
            $startupReplace = "if (START_SERVER) {`n  app.setName('$env:APP_NAME');`n  app.setPath('userData', path.resolve(process.cwd(), './pankosmia/AppData', '$env:APP_SHORT_NAME'));`n} else {"
            Update-FileText -Path $startupFile -Find $startupFind -Replace $startupReplace

            Remove-Item -Path $portableZipPath -Force -ErrorAction SilentlyContinue

            # Archive a single top-level directory named after the application.
            Compress-Archive `
                -Path $portableAppStage, $startAppBatDestination, $readMeDestination `
                -DestinationPath $portableZipPath `
                -CompressionLevel Optimal `
                -Force

            if (-not (Test-Path $portableZipPath)) {
                Write-Error "Portable ZIP was not created: $portableZipPath"
                exit 1
            }

            Write-Host "Portable package created successfully: $portableZipPath"
        }

        # Delete existing exe files from releases directory, only if path exists
        Get-ChildItem -Path $outputPath -Filter "*.exe" -ErrorAction SilentlyContinue |
            Remove-Item -Force

        # Call Inno Setup to create installer
        Write-Host "Building installer..."

        $innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        if (-not (Test-Path $innoSetupPath)) {
            Write-Host "Error: Inno Setup not found at $innoSetupPath"
            exit 1
        }

        $setupScript = ".\install\makeInstallElectronite.iss"

        Write-Host "Current working directory: $(Get-Location)"

        $process = Start-Process `
            -FilePath $innoSetupPath `
            -ArgumentList "/O`"$outputPath`"", $setupScript `
            -NoNewWindow `
            -Wait `
            -PassThru

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