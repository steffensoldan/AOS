<#
.SYNOPSIS
  Installiert das dialog-start-Recipe in Goose, damit es in Goose Desktop
  in der Recipe-Liste erscheint.
.DESCRIPTION
  Der Weg ueber einen goose://-Deeplink funktioniert fuer dieses Recipe nicht:
  Goose bettet die vollstaendige Konfiguration base64-kodiert in den Link ein,
  der damit rund 3.900 Zeichen lang wird. Eine Windows-.url-Verknuepfung reicht
  ihn nicht unverkuerzt durch, und Goose meldet
  "Failed to decode recipe deeplink".

  Kopiert wird deshalb direkt in den Recipe-Ordner von Goose. Danach taucht das
  Recipe unter seinem Titel in Goose Desktop auf.
.EXAMPLE
  powershell .\scripts\install-goose-recipe.ps1
#>

$ErrorActionPreference = "Stop"
$AosRoot = Split-Path $PSScriptRoot -Parent

$source = Join-Path $AosRoot "recipes\dialog-start.yaml"
$targetDir = Join-Path $env:APPDATA "Block\goose\config\recipes"
$target = Join-Path $targetDir "aos-dialog-starten.yaml"

if (-not (Test-Path $source)) { Write-Error "Recipe nicht gefunden: $source"; exit 1 }

$goose = (Get-Command goose -ErrorAction SilentlyContinue).Source
if (-not $goose) { $goose = "$env:LOCALAPPDATA\goose\resources\bin\goose.exe" }
if (Test-Path $goose) {
    & $goose recipe validate $source
    if ($LASTEXITCODE -ne 0) { Write-Error "Recipe ist ungueltig - nicht installiert."; exit 1 }
} else {
    Write-Warning "Goose nicht gefunden - Recipe wird ohne Validierung kopiert."
}

if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
Copy-Item -Path $source -Destination $target -Force

Write-Host "Installiert: $target" -ForegroundColor Green
Write-Host "In Goose Desktop erscheint es als 'AOS Dialog starten'." -ForegroundColor Green
Write-Host "Goose Desktop danach neu starten, damit die Liste neu gelesen wird." -ForegroundColor Yellow
