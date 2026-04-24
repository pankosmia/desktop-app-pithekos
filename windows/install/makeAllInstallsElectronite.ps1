<#
.SYNOPSIS
    Creates Windows installation packages for the application.

.DESCRIPTION
    This script automates the build process for Windows installers:
    - Downloads Electron and zip releases for specified architectures
    - Processes and packages the files
    - Creates installation packages for each supported architecture
    - Currently supports Intel64 architecture (ARM64 support is commented out)

.NOTES
    Requires PowerShell and depends on:
    - getElectronRelease.ps1
    - makeInstallElectronite.ps1

.PARAMETER IsGHA
    Specify -IsGHA "N" when run locally to avoid a failed attempt to list github actions environment variables.
    - Default is "Y"

.PARAMETER Dev
    Specify -Dev "Y" when generating a development viewer.
    - Default is "N"
#>
param(
    [string]$Dev,
    [string]$IsGHA
)

# get environment variables from app_config.env
get-content ..\..\app_config.env | foreach {
  $name, $value = $_.split('=')
  if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('#')) {
    # skip empty or comment line in ENV file
    return
  }
  Set-Variable -Name $name -Value $value
  # Write-Host "Env $name=$value"
}

$env:APP_NAME=$APP_NAME.Trim("'")
$env:APP_VERSION=$APP_VERSION
$env:APP_SHORT_NAME=$APP_SHORT_NAME

if ($IsGHA -ne 'N') {
  # show environment variables defined
  env
}

# Define URLs for different architectures
$ElectronArm64 = "https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-win32-arm64.zip"
$ElectronIntel64 = "https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-win32-x64.zip"

# Loop through architectures
# foreach ($ARCH in @("intel64", "arm64")) {

foreach ($ARCH in @("intel64")) {
    Write-Host "Building for architecture: $ARCH"

    # Set download URLs based on architecture
    $downloadElectronUrl = $ElectronIntel64
    $expectedZip = "*-windows-*.zip"

    if ($ARCH -eq "arm64") {
        $downloadElectronUrl = $ElectronArm64
        $expectedZip = "*-windows-*.zip" # TODO need to set for arm
    }

    # Get Electron release
    Write-Host "Getting Electron release..."
    $electronResult = & "$PSScriptRoot\getElectronRelease.ps1" -downloadUrl $downloadElectronUrl -arch $ARCH -Dev $Dev
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to get Electron release files at $downloadElectronUrl"
        exit 1
    }

    if ($Dev -ne 'Y') {
      # verify zip
      If (-Not (Test-Path ..\..\releases\windows\$expectedZip)) {
          echo "Error: Missing windows .zip release"
          exit 1
      }
    }

    # Run makeInstallElectronite PowerShell script
    Write-Host "`n"
    Write-Host "     *****************************************"
    Write-Host "     * Running makeInstallElectronite.ps1... *"
    Write-Host "     * Wait for the prompt.                  *"
    Write-Host "     *****************************************"
    Write-Host "`n"
    $makeInstallElectronitePath = Join-Path $PSScriptRoot "makeInstallElectronite.ps1"
    if (-not (Test-Path $makeInstallElectronitePath)) {
        Write-Host "Error: makeInstallElectronite.ps1 not found at $makeInstallElectronitePath"
        exit 1
    }

    if ($Dev -eq 'Y') {
      $result = & "$makeInstallElectronitePath" -Dev $Dev -arch $arch
    } else {
      $result = & "$makeInstallElectronitePath" -arch $arch
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: makeInstallElectronite.ps1 failed with exit code $LASTEXITCODE"
        exit 1
    }
}

# Remove temporary electronite files from local dev viewer build.
if ($Dev -eq 'Y') {
  Remove-Item -Path "..\viewer\electron" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "..\viewer\electron.*" -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Local Dev Electronite Viewer has been successfully built."
}

if ($Dev -ne 'Y') {
  Write-Host "All architectures built successfully"
}
