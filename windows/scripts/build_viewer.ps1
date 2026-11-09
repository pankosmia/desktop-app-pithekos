# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\build_viewer.ps1
# Or force a full install with: .\build_viewer.ps1 -f

param(
    [switch]$f
)

$ELECTRON_VER = "..\viewer\project\payload\app\electron\version"

$expected = '37.1.0'
$installElectron = $f.IsPresent

if (-not $installElectron) {
    if (Test-Path -LiteralPath $ELECTRON_VER -PathType Leaf) {
        $content = Get-Content -LiteralPath $ELECTRON_VER -Raw
        if ($content -eq $expected) {
            Write-Host 'The installed viewer Electronite version is'$content', which is correct.'
            Write-Host 'No download is needed. Everything else will be updated.'
            $installElectron = $false
        } else {
            Write-Host 'The installed viewer Electronite version is '$content', however we are not using '$expected'. Please wait for the download and upgrade that will follow...'
            $installElectron = $true
        }
    }
    else {
        'A full viewer install will follow, including download of Electronite. Please wait patiently...'
        $installElectron = $true
    }
} else {
    Write-Host '-f flag detected.'
    Write-Host 'A full viewer install will follow, including download of Electronite. Please wait patiently...'
}

$TEMP_DIR = "..\viewer"
if ($installElectron -and (Test-Path $TEMP_DIR)) {
    Write-Host "Deleting previous viewer build..."
    Remove-Item -Path $TEMP_DIR -Recurse -Force
}

if ($installElectron) {
    Write-Host "*************************************************************************" -f cyan;
    Write-Host "`"Getting Electron release`" downloads an approximately 120 MB file." -f cyan;
    Write-Host "Please wait patiently for the highlighted download process to complete..." -f cyan;
    Write-Host "*************************************************************************" -f cyan;
}

..\install\makeAllInstallsElectronite.ps1 -Dev "Y" -IsGHA "N" -FullInstall:$installElectron
