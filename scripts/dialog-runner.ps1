param(
    [string]$Topic,
    [int]$MaxRounds = 5,
    [string]$InitialPrompt
)

$ErrorActionPreference = 'Stop'
$aosPath = "C:\Users\sts\AOS"
$dialogPath = "$aosPath\dialog"

# 1. Erkennung von Claude-initiierten Triggern, falls kein Thema angegeben wurde
if (-not $Topic) {
    $triggers = Get-ChildItem -Path $dialogPath -Filter "__cc_trigger__" -Recurse -ErrorAction SilentlyContinue
    if ($triggers) {
        Write-Host "--- Gefundene von Claude initiierte Dialoge ---" -ForegroundColor Yellow
        $i = 1
        $triggerTopics = @()
        foreach ($trig in $triggers) {
            $topicName = $trig.Directory.Name
            Write-Host "$i) $topicName (Status: waiting-for-ag)" -ForegroundColor Green
            $triggerTopics += $topicName
            $i++
        }
        Write-Host ""
        $selection = Read-Host "Waehle eine Nummer zum Starten, oder druecke Enter fuer ein neues Thema"
        if ($selection -match "^\d+$" -and $selection -le $triggerTopics.Count) {
            $Topic = $triggerTopics[[int]$selection - 1]
            $triggerFile = $triggers[[int]$selection - 1].FullName
            if (Test-Path $triggerFile) {
                Remove-Item $triggerFile -Force | Out-Null
            }
            Write-Host "Trigger-Datei entfernt. Uebernehme Dialog-Fuehrung fuer Thema: $Topic" -ForegroundColor Green
        }
    }
}

# 2. Interaktive Abfrage falls immer noch kein Thema
if (-not $Topic) {
    $Topic = Read-Host "Bitte Themen-Name eingeben (z. B. tech-stack)"
}
# Bereinige Themen-Namen (Kebab-Case)
$Topic = $Topic.ToLower().Replace(" ", "-")

$topicDir = "$dialogPath\$Topic"
$statusFile = "$topicDir\status.md"
$fromClaudeFile = "$topicDir\from-claude.md"
$fromAgFile = "$topicDir\from-ag.md"

# 3. Initialisierung falls neu (AG startet immer mit eigenem Beitrag)
if (-not (Test-Path $topicDir)) {
    New-Item -ItemType Directory -Path $topicDir -Force | Out-Null
    
    if (-not $InitialPrompt) {
        $InitialPrompt = Read-Host "Bitte Start-Prompt fuer den Dialog eingeben"
    }
    
    # Leere Antwortdatei für Claude
    "# Claude Code Antworten`n" | Out-File $fromClaudeFile -Encoding utf8
    
    # Start-Antrag für Antigravity schreiben
    $dateStr = Get-Date -Format "yyyy-MM-dd HH:mm"
    $agStart = "# Antigravity Antworten`n`n**[$dateStr, Antigravity - Runde 1]**`n`n$InitialPrompt`n`n- Antigravity`n"
    $agStart | Out-File $fromAgFile -Encoding utf8
    
    # Status-Datei schreiben
    $statusContent = @"
status: waiting-for-claude
max_rounds: $MaxRounds
current_round: 1
started: $(Get-Date -Format "yyyy-MM-dd")
topic: $Topic
"@
    $statusContent | Out-File $statusFile -Encoding utf8
    
    Write-Host "Dialog '$Topic' erfolgreich initialisiert!" -ForegroundColor Green
    Write-Host "Start-Prompt: $InitialPrompt" -ForegroundColor Gray
} else {
    Write-Host "Setze bestehenden Dialog '$Topic' fort..." -ForegroundColor Yellow
}

# 4. Dialog-Orchestrierungsschleife
while ($true) {
    if (-not (Test-Path $statusFile)) {
        Write-Error "status.md existiert nicht in $topicDir!"
        break
    }
    
    # status.md parsen
    $statusData = @{}
    Get-Content $statusFile | ForEach-Object {
        if ($_ -match "^([^:]+):\s*(.*)$") {
            $statusData[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    
    $status = $statusData["status"]
    $currentRound = [int]$statusData["current_round"]
    $maxRounds = [int]$statusData["max_rounds"]
    
    if ($status -eq "done" -or $currentRound -gt $maxRounds) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Dialog erfolgreich beendet!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        break
    }
    
    if ($status -eq "waiting-for-claude") {
        Write-Host "`n[Runde $currentRound / $maxRounds] Claude Code ist am Zug. Starte CLI..." -ForegroundColor Yellow
        
        $prompt = "Thema: $Topic. Lies den Dialog und antworte."
        
        # Startet Claude Code im Headless-Modus (bevorzugt globale Installation wegen Credentials)
        if (Get-Command "claude" -ErrorAction SilentlyContinue) {
            claude -p $prompt --permission-mode bypassPermissions
        } else {
            npx --yes @anthropic-ai/claude-code -p $prompt --permission-mode bypassPermissions
        }
        
        # Letzten Eintrag aus from-claude.md auslesen und anzeigen
        if (Test-Path $fromClaudeFile) {
            $latestClaude = Get-Content $fromClaudeFile -Raw
            Write-Host "`n--- Letzte Antwort von Claude Code ---" -ForegroundColor Cyan
            Write-Host $latestClaude
            Write-Host "-------------------------------------" -ForegroundColor Cyan
        }
    }
    elseif ($status -eq "waiting-for-ag") {
        Write-Host "`n[Runde $currentRound / $maxRounds] Antigravity ist am Zug." -ForegroundColor Magenta
        Write-Host "Bitte gehe in das Antigravity Chat-Fenster und antworte auf den Dialog unter Thema '$Topic'." -ForegroundColor Gray
        Write-Host "Der Watcher wartet, bis die Antwort geschrieben und der Status auf 'waiting-for-claude' oder 'done' geaendert wurde..." -ForegroundColor Gray
        
        # Polling der status.md-Datei bis der Status wechselt
        while ($true) {
            Start-Sleep -Seconds 3
            if (-not (Test-Path $statusFile)) { continue }
            
            $checkData = @{}
            Get-Content $statusFile | ForEach-Object {
                if ($_ -match "^([^:]+):\s*(.*)$") {
                    $checkData[$Matches[1].Trim()] = $Matches[2].Trim()
                }
            }
            if ($checkData["status"] -ne "waiting-for-ag") {
                # Zeige die neue Antwort von Antigravity im Verlauf an
                if (Test-Path $fromAgFile) {
                    $latestAg = Get-Content $fromAgFile -Raw
                    Write-Host "`n--- Letzte Antwort von Antigravity ---" -ForegroundColor Magenta
                    Write-Host $latestAg
                    Write-Host "-------------------------------------" -ForegroundColor Magenta
                }
                break
            }
        }
    }
}
