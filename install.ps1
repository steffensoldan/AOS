# install.ps1 - UAOS Installer fuer VM / Zweitsysteme
$ErrorActionPreference = 'Stop'

Write-Host "=== UAOS Installation gestartet ===" -ForegroundColor Cyan

# 1. Sicherheits- Ingegritätsprüfung (Prüfung gegen eingepackte Secrets)
$badFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Include "*.env","*.env.*","secrets.json","credentials.json","*.key","*.pem" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "\.(example|template|sample)$" }

if ($badFiles) {
    Write-Error "ABORT: Integritätsverletzung - Secrets im Installationspaket entdeckt:"

    $badFiles | ForEach-Object { Write-Error "  $($_.FullName)" }
    Write-Error "Bitte bereinigen Sie die Quelle und erstellen Sie den Export neu."
    exit 1
}
Write-Host "Integritätsprüfung: OK" -ForegroundColor Green

# 1.5 Validierung verschachtelter CLAUDE.md auf relative Pfad-Hop-Verstöße (Option C+A)
Write-Host "Prüfe verschachtelte CLAUDE.md auf Pfad-Hops..." -ForegroundColor Cyan
$nestedClaudes = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "CLAUDE.md" -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -ne $PSScriptRoot -and $_.DirectoryName -ne "$HOME\.claude" }

foreach ($file in $nestedClaudes) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "@\.\./") {
        Write-Warning "WARNUNG: Relative Pfad-Hop-Direktive in verschachtelter CLAUDE.md gefunden:"
        Write-Warning "  $($file.FullName)"
        Write-Warning "  Bitte vermeiden Sie relative Imports mit '../' in Sub-Projekten (Option C+A)."
        Write-Warning "  Nutzen Sie stattdessen die Vererbung oder erstellen Sie separate Rules ohne relative Hops."
    }
}


# 2. Entwicklermodus pruefen
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if ($null -eq $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Warning "Der Windows-Entwicklermodus scheint nicht aktiv zu sein."
    Write-Warning "Dies kann dazu fuehren, dass Symbolische Links nicht ohne Administratorrechte erstellt werden koennen."
    Write-Warning "Bitte aktiviere den Entwicklermodus in den Windows-Systemeinstellungen, falls Fehler auftreten."
}

# 3. Verzeichnisse anlegen
$paths = @(
    "$HOME\.claude\commands",
    "$HOME\.claude\hooks",
    "$HOME\.gemini\config\plugins\agos-core\skills"
)

foreach ($path in $paths) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Ordner erstellt: $path" -ForegroundColor Green
    }
}

# 4. Claude Commands verknuepfen (Idempotent)
$commands = Get-ChildItem -Path "$PSScriptRoot\commands" -Filter "*.md"
foreach ($cmd in $commands) {
    $targetLink = "$HOME\.claude\commands\$($cmd.Name)"
    $sourceFile = $cmd.FullName
    
    if (-not (Test-Path $targetLink)) {
        New-Item -ItemType SymbolicLink -Path $targetLink -Value $sourceFile -Force | Out-Null
        Write-Host "Symbolischer Link fuer Claude erstellt: $targetLink" -ForegroundColor Green
    } else {
        Write-Host "Claude Command bereits verknuepft: $($cmd.Name)" -ForegroundColor Gray
    }
}

# 5. Safety Hooks verknuepfen (Idempotent)
$hookSource = Resolve-Path "$PSScriptRoot\hooks\block-dangerous.sh" -ErrorAction SilentlyContinue
$hookTarget = "$HOME\.claude\hooks\block-dangerous.sh"
if ($hookSource -and -not (Test-Path $hookTarget)) {
    New-Item -ItemType SymbolicLink -Path $hookTarget -Value $hookSource.Path -Force | Out-Null
    Write-Host "Safety Hook fuer Claude verknuepft: $hookTarget" -ForegroundColor Green
} else {
    Write-Host "Claude Safety Hook bereits verknuepft." -ForegroundColor Gray
}

# 6. Gemini Skills registrieren (idempotent ueber add-skill.ps1)
if (Test-Path "$PSScriptRoot\scripts\add-skill.ps1") {
    Write-Host "Registriere Skills in Antigravity (Gemini)..." -ForegroundColor Cyan
    foreach ($cmd in $commands) {
        $cmdName = $cmd.BaseName
        $geminiSkillDir = "$HOME\.gemini\config\plugins\agos-core\skills\$cmdName"
        $geminiSkillFile = "$geminiSkillDir\SKILL.md"
        
        if (-not (Test-Path $geminiSkillFile)) {
            # Rufe das add-skill Skript auf
            & "$PSScriptRoot\scripts\add-skill.ps1" -CommandName $cmdName | Out-Null
            Write-Host "Skill registriert: $cmdName" -ForegroundColor Green
        } else {
            Write-Host "Gemini Skill bereits registriert: $cmdName" -ForegroundColor Gray
        }
    }
}

# 7. Entpackte CLAUDE.md aus dem ZIP anwenden (falls vorhanden)
$zipClaudeMd = Join-Path $PSScriptRoot ".claude\CLAUDE.md"
if (Test-Path $zipClaudeMd) {
    $claudeGlobalDir = "$HOME\.claude"
    if (-not (Test-Path $claudeGlobalDir)) { New-Item -ItemType Directory -Path $claudeGlobalDir -Force | Out-Null }
    Copy-Item -Path $zipClaudeMd -Destination $claudeGlobalDir -Force
    Write-Host "Globale CLAUDE.md aus Export-Paket installiert." -ForegroundColor Green
}

# 8. global-rules.md in globale CLAUDE.md eintragen (idempotent und bereinigt)
$claudeMdPath = "$HOME\.claude\CLAUDE.md"
$globalRulesRef = "@$($PSScriptRoot)\memory\global-rules.md"

# Bereinige eventuelle veraltete Pfade zu global-rules.md aus dem Export-Paket
if (Test-Path $claudeMdPath) {
    $content = Get-Content $claudeMdPath
    # Entferne alle Zeilen, die ein Include von global-rules.md enthalten
    $cleanedContent = $content | Where-Object { $_ -notmatch '@.*\\memory\\global-rules\.md' }
    
    # Schreibe bereinigten Inhalt ohne BOM zurück
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllLines($claudeMdPath, $cleanedContent, $utf8NoBom)
}

$existingContent = if (Test-Path $claudeMdPath) { Get-Content $claudeMdPath -Raw } else { "" }
if ($existingContent -notmatch [regex]::Escape($globalRulesRef)) {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::AppendAllText($claudeMdPath, "`r`n$globalRulesRef`r`n", $utf8NoBom)
    Write-Host "global-rules.md in CLAUDE.md verknüpft." -ForegroundColor Green
}


Write-Host "=== UAOS Installation abgeschlossen ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "NAECHSTE SCHRITTE FUER DIE VM (MOBILE DISPATCHER):" -ForegroundColor Yellow
Write-Host "1. Führe 'claude login' in der PowerShell der VM aus, um Claude Code zu autorisieren." -ForegroundColor White
Write-Host "2. Starte die Koppelung: Gib 'claude' im VM-Terminal ein." -ForegroundColor White
Write-Host "3. Öffne die mobile App 'Claude Desktop' auf dem Handy und kopple es per Koppelungscode." -ForegroundColor White
Write-Host "4. Detaillierte Infos zu Timeouts und dem Git-Workflow finden Sie in der neuen MOBILE.md im AOS-Root." -ForegroundColor White
