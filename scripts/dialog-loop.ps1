<#
.SYNOPSIS
  Orchestrert einen dialog-lite Dialog zwischen Claude Code und Goose - vollautomatisch, headless.
.DESCRIPTION
  Startet beide Agenten abwechselnd im Headless-Modus, bis der Dialog geschlossen ist.
  Kein Agent muss interaktiv offen sein.
  Timeouts und Retries sind eingebaut.
.PARAMETER Slug
  Dialog-Kennung (wird Verzeichnisname unter dialoge\).
.PARAMETER Topic
  Vollständige Fragestellung des Dialogs.
.PARAMETER Rounds
  Maximale Debattenrunden (default: 3).
.PARAMETER TimeoutSec
  Timeout pro Agenten-Aufruf in Sekunden (default: 300).
.PARAMETER MaxRetries
  Zusaetzliche Wiederholungen nach einem Fehlversuch (default: 2 = 3 Laeufe insgesamt).
.EXAMPLE
  .\dialog-loop.ps1 -Slug "export-allowlist" -Topic "Allowlist oder Denylist im Secret-Check von export-aos.ps1?"
.EXAMPLE
  .\dialog-loop.ps1 -Slug "test-dialog" -Topic "Ist X funktionsfähig?" -Rounds 2 -TimeoutSec 180
#>

param(
    [Parameter(Mandatory = $true)][string]$Slug,
    [Parameter(Mandatory = $true)][string]$Topic,
    [string]$Initiator = "goose",
    [string]$Partner   = "claude",
    [int]$Rounds = 3,
    [int]$TimeoutSec = 300,
    [int]$MaxRetries = 2
)

$AosRoot = Split-Path $PSScriptRoot -Parent   # Skript liegt in scripts\, AOS-Root ist eine Ebene hoeher
$ErrorActionPreference = "Stop"

# -- Claude-Pfad dynamisch auflösen ------------------------------------------
function Resolve-ClaudePath {
    $c = (Get-Command claude -ErrorAction SilentlyContinue).Source
    if ($c) { return $c }
    $c = Get-ChildItem `
        "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\*\claude.exe", `
        "$env:LOCALAPPDATA\npm-cache\_npx\*\node_modules\@anthropic-ai\claude-code\bin\claude.exe" `
        -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    return $c
}

function Resolve-GoosePath {
    $g = (Get-Command goose -ErrorAction SilentlyContinue).Source
    if ($g) { return $g }
    $g = "$env:LOCALAPPDATA\goose\resources\bin\goose.exe"
    if (Test-Path $g) { return $g }
    return $null
}

# -- Agentenregistratur ------------------------------------------------------
# Ein Eintrag je Kennung, wie sie beim MCP-Server per --as gesetzt ist.
# Mode 'headless': das Programm nimmt einen Prompt und beendet sich.
# Mode 'manual':   nur interaktiv erreichbar - der Loop haelt an und uebergibt
#                  an den Menschen, statt einen Start vorzutaeuschen.
function Get-AgentRegistry {
    @{
        claude = @{
            Mode = 'headless'
            Exe  = (Resolve-ClaudePath)
            # Nur ein Einzeiler ueber argv, der Prompt bleibt in der Datei - umgeht die
            # Quoting-Regeln von CommandLineToArgvW. --allowedTools statt bypassPermissions:
            # der Loop braucht die Dialog-Tools und Lesezugriff, sonst nichts
            # (global-rules.md, Ziel 4 Fail-Closed).
            Args = { param($f) "-p `"Lies die Datei $f und folge den Anweisungen darin.`" " +
                               "--allowedTools `"mcp__aos-dialog__*,Read,Grep,Glob`"" }
        }
        goose = @{
            Mode = 'headless'
            Exe  = (Resolve-GoosePath)
            Args = { param($f) "run -i `"$f`" --no-session -q" }
        }
        antigravity = @{
            Mode = 'manual'
            Exe  = $null
            Hint = "Antigravity hat keinen eigenstaendigen Headless-Start. 'agentapi new-conversation' " +
                   "ist ein Client zu einer laufenden IDE und verlangt ANTIGRAVITY_LS_ADDRESS. " +
                   "Antworte im Antigravity-Chat und starte diesen Lauf danach erneut - der Resume-Pfad greift."
        }
    }
}

# -- Einen Agenten seinen Zug machen lassen ----------------------------------
# Rueckgabe: 'ok' | 'failed' | 'fatal' | 'manual'
function Invoke-Agent {
    param(
        [string]$Name,
        [hashtable]$Registry,
        [string]$Prompt,
        [int]$TimeoutSec,
        [int]$MaxRetries,
        [string]$WorkingDir
    )
    $agent = $Registry[$Name]
    if (-not $agent) {
        Write-Warning "Unbekannter Agent '$Name'. Registriert: $($Registry.Keys -join ', ')"
        return 'fatal'
    }
    if ($agent.Mode -eq 'manual') {
        Write-Host ""
        Write-Host "  [$Name] kein Headless-Start moeglich." -ForegroundColor Yellow
        Write-Host "  $($agent.Hint)" -ForegroundColor Yellow
        return 'manual'
    }
    if (-not $agent.Exe) {
        Write-Warning "  [$Name] Programm nicht gefunden."
        return 'fatal'
    }
    return Invoke-AgentHeadless -Exe $agent.Exe -ArgBuilder $agent.Args -Prompt $Prompt -AgentName $Name `
        -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $WorkingDir
}

# -- Dialog-State aus HTML-Datei lesen ---------------------------------------
function Get-DialogState {
    param([string]$Slug, [string]$AosRoot)
    $html = Join-Path $AosRoot "dialoge\$Slug.html"
    $unknown = @{ state = "unknown"; turn = $null; round = 0; revision = -1; probes_pending = "" }
    if (-not (Test-Path $html)) { return @{ state = "absent"; turn = $null; round = 0; revision = -1; probes_pending = "" } }

    # Der Zustand liegt als JSON im Kopf der Datei. dialog-lite maskiert "<" in allen
    # Strings zu <, daher kann kein </script> im Rumpf stehen und der nicht-gierige
    # Match ist eindeutig. Regex nur zum Ausschneiden des Blocks, geparst wird als JSON.
    $raw = Get-Content $html -Raw -Encoding UTF8
    $m = [regex]::Match($raw, '(?s)<script type="application/json" id="dialog-data">\s*(.*?)\s*</script>')
    if (-not $m.Success) { Write-Warning "Kein dialog-data-Block in $html gefunden."; return $unknown }

    try {
        $data = $m.Groups[1].Value | ConvertFrom-Json
    } catch {
        Write-Warning "dialog-data ist kein gueltiges JSON: $($_.Exception.Message)"
        return $unknown
    }

    return @{
        state          = $data.state
        turn           = $data.turn
        round          = [int]$data.round
        revision       = [int]$data.revision
        probes_pending = ($data.probes_pending -join ",")
    }
}

# Meldungen, bei denen ein erneuter Versuch dasselbe Ergebnis liefert. Die Liste ist
# naturgemaess unvollstaendig: unbekannte fatale Fehler laufen weiter in die Retries.
$FatalPatterns = @(
    'Credit balance is too low',
    'Invalid API key',
    'authentication_error',
    'Failed to authenticate',
    'OAuth session expired',
    'Please run /login',
    'insufficient_quota'
)

# -- Agent headless mit Timeout ausführen ------------------------------------
# Rueckgabe: 'ok' | 'failed' (wiederholbar, erschoepft) | 'fatal' (Retry sinnlos)
function Invoke-AgentHeadless {
    param(
        [string]$Exe,
        [scriptblock]$ArgBuilder,   # baut die Kommandozeile aus dem Prompt-Dateipfad
        [string]$Prompt,
        [string]$AgentName,
        [int]$TimeoutSec,
        [int]$MaxRetries,
        [string]$WorkingDir
    )

    # Prompt in Temp-Datei - vermeidet Quoting-Probleme
    $promptFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($promptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

    $status = 'failed'
    $maxAttempts = $MaxRetries + 1   # MaxRetries zaehlt Wiederholungen, nicht Laeufe
    $lastOutput = $null              # Ausgabe des vorigen Versuchs, fuer die Determinismus-Pruefung

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host "  [$AgentName] Versuch $attempt/$maxAttempts ..." -ForegroundColor DarkGray

        # Kommandozeile kommt aus der Registratur, nicht aus einer Namensverzweigung
        $argString = & $ArgBuilder $promptFile

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Exe
        $psi.Arguments = $argString
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $WorkingDir
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $timedOut = -not $proc.WaitForExit($TimeoutSec * 1000)

        if ($timedOut) {
            Write-Warning "  [$AgentName] Timeout nach ${TimeoutSec}s - Prozess wird beendet"
            try { $proc.Kill() } catch {}
            Start-Sleep -Seconds 1
            # Async-Tasks abräumen
            try { $stdoutTask.Wait(2000) | Out-Null } catch {}
            try { $stderrTask.Wait(2000) | Out-Null } catch {}
            if ($attempt -lt $maxAttempts) {
                Write-Host "  [$AgentName] Retry ..." -ForegroundColor Yellow
                continue
            }
            Write-Warning "  [$AgentName] Alle $maxAttempts Versuche erschoepft - überspringe"
            $status = 'failed'
        } else {
            $stdout = $stdoutTask.Result
            $stderr = $stderrTask.Result
            $exitCode = $proc.ExitCode

            if ($stdout) { Write-Host "  [$AgentName] stdout:" -ForegroundColor DarkGray; Write-Host $stdout -ForegroundColor DarkGray }
            if ($stderr -and $stderr.Trim()) { Write-Host "  [$AgentName] stderr: $stderr" -ForegroundColor DarkGray }
            Write-Host "  [$AgentName] Exit-Code: $exitCode" -ForegroundColor DarkGray

            if ($exitCode -eq 0) {
                $status = 'ok'
            } else {
                # Ein zweiter Lauf mit gleichem Prompt aendert an diesen Meldungen nichts.
                $combined = "$stdout $stderr"
                $hit = $FatalPatterns | Where-Object { $combined -match [regex]::Escape($_) } | Select-Object -First 1
                if ($hit) {
                    Write-Warning "  [$AgentName] Fatal: '$hit' - Retry waere sinnlos, Abbruch."
                    $status = 'fatal'
                } elseif ($null -ne $lastOutput -and $combined -eq $lastOutput) {
                    # Auffangnetz fuer alles, was nicht in $FatalPatterns steht: zwei Versuche
                    # mit identischer Ausgabe sind ein deterministischer Fehler, kein transienter.
                    Write-Warning "  [$AgentName] Fatal: Ausgabe identisch zum Vorversuch - deterministischer Fehler, Abbruch."
                    $status = 'fatal'
                } else {
                    $lastOutput = $combined
                    $status = 'failed'
                }
            }
        }

        if ($status -eq 'ok' -or $status -eq 'fatal') { break }
    }

    Remove-Item $promptFile -ErrorAction SilentlyContinue
    return $status
}

# -- Prompt-Vorlagen ---------------------------------------------------------

# Initiator: Öffnet Dialog + reicht Sonde ein
$openPrompt = @"
Nutze den MCP-Server aos-dialog.

1. Pruefe mit dialog_list, ob ein Dialog mit dem Slug '$Slug' existiert.
2. Wenn nicht: Oeffne ihn mit dialog_open(slug='$Slug', topic='$Topic', partner='$Partner', max_rounds=$Rounds).
3. Wenn ja: Lese ihn mit dialog_read.
4. Wenn du noch keine Sonde eingereicht hast: Reiche sie ein mit dialog_probe(slug='$Slug', artifact='...').
   - Artefakt = Datei + Zeile, max 10 Zeilen, keine Prosa.
   - Sieh dir die relevanten Dateien im Arbeitsverzeichnis selbst an.
5. Wenn beide Sonden vorliegen und nicht aufgeloest: dialog_probe_resolve(slug='$Slug', outcome='converged' oder 'diverged', rationale='...').
6. Wenn du im Debate am Zug bist: antworte mit dialog_post oder schliesse mit dialog_close.

Danach beenden. Keine Rueckfragen.
"@

# Partner: Reicht Sonde ein + löst auf
$probePrompt = @"
Nutze den MCP-Server aos-dialog.

1. Lese den Dialog '$Slug' mit dialog_read.
2. Wenn du noch keine Sonde eingereicht hast: dialog_probe(slug='$Slug', artifact='...').
   - Artefakt = Datei + Zeile, max 10 Zeilen, keine Prosa.
   - Sieh dir die relevanten Dateien im Arbeitsverzeichnis selbst an.
3. Wenn beide Sonden vorliegen und nicht aufgeloest: dialog_probe_resolve(slug='$Slug', outcome='converged' oder 'diverged', rationale='...').
4. Wenn du im Debate am Zug bist: antworte mit dialog_post oder schliesse mit dialog_close.

Danach beenden. Keine Rueckfragen.
"@

# Generic debate prompt (beide Agenten)
$debatePrompt = @"
Nutze den MCP-Server aos-dialog.

1. Lese den Dialog '$Slug' mit dialog_read.
2. Wenn du noch keine Sonde eingereicht hast: dialog_probe(slug='$Slug', artifact='...').
   Sieh dir die relevanten Dateien selbst an.
3. Wenn beide Sonden vorliegen und nicht aufgeloest: dialog_probe_resolve.
4. Wenn du im Debate am Zug bist: antworte mit dialog_post (mit objections + retract_if) oder schliesse mit dialog_close (mit result).

Pruefe jede Tatsachenbehauptung des anderen selbst auf Platte, bevor du sie annimmst
oder zurueckweist - Datei oeffnen, Zeile lesen, gegebenenfalls nachmessen. Uebernimm
nichts ungeprueft und widersprich nichts ungeprueft. Nenne im Beitrag, was du geprueft
hast und was du nicht pruefen konntest.

Danach beenden. Keine Rueckfragen.
"@

# -- Hauptablauf ------------------------------------------------------------

Write-Host ""
Write-Host "=== dialog-loop ===" -ForegroundColor Cyan
Write-Host "Slug:     $Slug"
Write-Host "Thema:    $Topic"
Write-Host "Paarung:  $Initiator (oeffnet) gegen $Partner"
Write-Host "Runden:   $Rounds"
Write-Host "Timeout:  ${TimeoutSec}s pro Agent"
Write-Host "Retries:  $MaxRetries bei Timeout"
Write-Host ""

$Registry = Get-AgentRegistry

foreach ($name in @($Initiator, $Partner)) {
    if (-not $Registry.ContainsKey($name)) {
        Write-Error "Unbekannter Agent '$name'. Registriert: $($Registry.Keys -join ', ')"
        exit 1
    }
}
if ($Initiator -eq $Partner) { Write-Error "Initiator und Partner muessen verschieden sein."; exit 1 }

foreach ($name in @($Initiator, $Partner)) {
    $a = $Registry[$name]
    if ($a.Mode -eq 'manual') {
        Write-Host ("{0,-9} nur interaktiv (kein Headless-Start)" -f "${name}:") -ForegroundColor Yellow
    } elseif ($a.Exe) {
        Write-Host ("{0,-9} {1}" -f "${name}:", $a.Exe) -ForegroundColor DarkGray
    } else {
        Write-Error "Programm fuer '$name' nicht gefunden."
        exit 1
    }
}
Write-Host ("{0,-9} {1}" -f "AOS-Root:", $AosRoot) -ForegroundColor DarkGray
Write-Host ""

# Abbruchsignal und Iterationszaehler gelten ueber alle Phasen hinweg
$abort = $false
$iteration = 0
$manualStop = $null   # gesetzt, wenn ein nur-interaktiver Agent am Zug ist

# Dialog-State prüfen
$dialog = Get-DialogState -Slug $Slug -AosRoot $AosRoot

if ($dialog.state -eq "done") {
    Write-Host "Dialog bereits abgeschlossen." -ForegroundColor Green
    exit 0
}

# Phase 1: Dialog öffnen + Sondenphase (nur wenn Dialog nicht existiert)
if ($dialog.state -eq "absent") {
    Write-Host "[Phase 1] ${Initiator}: Dialog öffnen + Sonde einreichen" -ForegroundColor Green
    $r = Invoke-Agent -Name $Initiator -Registry $Registry -Prompt $openPrompt `
        -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $AosRoot
    if ($r -eq 'fatal') { $abort = $true }
    if ($r -eq 'manual') { $abort = $true; $manualStop = $Initiator }

    if (-not $abort) {
        Write-Host ""
        Write-Host "[Phase 2] ${Partner}: Sonde einreichen + auflösen" -ForegroundColor Green
        $r = Invoke-Agent -Name $Partner -Registry $Registry -Prompt $probePrompt `
            -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $AosRoot
        if ($r -eq 'fatal') { $abort = $true }
        if ($r -eq 'manual') { $abort = $true; $manualStop = $Partner }
    }

    Start-Sleep -Seconds 2
    $dialog = Get-DialogState -Slug $Slug -AosRoot $AosRoot

    if ($dialog.state -eq "done") {
        Write-Host ""
        Write-Host "=== Sonden konvergiert - Dialog beendet ===" -ForegroundColor Green
        Write-Host "HTML: dialoge\$Slug.html"
        exit 0
    }
}

# Phase 1b: Resume - Dialog existiert, aber Sondenphase noch offen.
# Nach einem fatalen Fehler nicht nachfeuern: derselbe Agent wuerde erneut scheitern.
if ($dialog.state -eq "probing" -and -not $abort) {
    $pp = $dialog.probes_pending
    Write-Host "[Resume] Sondenphase, noch ausstehend: '$pp'" -ForegroundColor Yellow

    if ($pp -match [regex]::Escape($Initiator)) {
        Write-Host "  ${Initiator}: Sonde einreichen" -ForegroundColor Green
        $r = Invoke-Agent -Name $Initiator -Registry $Registry -Prompt $debatePrompt `
            -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $AosRoot
        if ($r -eq 'fatal') { $abort = $true }
        if ($r -eq 'manual') { $abort = $true; $manualStop = $Initiator }
    }

    # Danach kann der Partner sondieren und bewerten
    Start-Sleep -Seconds 2
    $dialog = Get-DialogState -Slug $Slug -AosRoot $AosRoot

    if (-not $abort -and $dialog.state -eq "probing") {
        if ($dialog.probes_pending -match [regex]::Escape($Partner)) {
            Write-Host "  ${Partner}: Sonde einreichen + auflösen" -ForegroundColor Green
        } else {
            Write-Host "  ${Partner}: Sonden auflösen" -ForegroundColor Green
        }
        $r = Invoke-Agent -Name $Partner -Registry $Registry -Prompt $debatePrompt `
            -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $AosRoot
        if ($r -eq 'fatal') { $abort = $true }
        if ($r -eq 'manual') { $abort = $true; $manualStop = $Partner }
    }

    Start-Sleep -Seconds 2
    $dialog = Get-DialogState -Slug $Slug -AosRoot $AosRoot

    if ($dialog.state -eq "done") {
        Write-Host ""
        Write-Host "=== Sonden konvergiert - Dialog beendet ===" -ForegroundColor Green
        Write-Host "HTML: dialoge\$Slug.html"
        exit 0
    }
}

# Phase 3: Debate-Loop
if ($dialog.state -eq "debating" -and -not $abort) {
    Write-Host ""
    Write-Host "[Phase 3] Debate-Loop (Runde $($dialog.round)/$Rounds, Zug: $($dialog.turn))" -ForegroundColor Yellow
    Write-Host ""

    $maxIterations = $Rounds * 2 + 4  # Sicherheitsventil

    while ($dialog.state -ne "done" -and $iteration -lt $maxIterations -and -not $abort) {
        $iteration++
        $revisionBefore = $dialog.revision

        $turn = $dialog.turn
        $rnd  = $dialog.round

        Write-Host "[Loop $iteration] State=debating, Runde=$rnd/$Rounds, Zug=$turn" -ForegroundColor Yellow

        if (-not $turn) {
            Write-Warning "Kein aktiver Zug (turn leer). Abbruch."
            break
        }

        Write-Host "  -> $turn wird gestartet" -ForegroundColor Green
        $r = Invoke-Agent -Name $turn -Registry $Registry -Prompt $debatePrompt `
            -TimeoutSec $TimeoutSec -MaxRetries $MaxRetries -WorkingDir $AosRoot
        if ($r -eq 'fatal')  { $abort = $true; break }
        if ($r -eq 'manual') { $abort = $true; $manualStop = $turn; break }

        Start-Sleep -Seconds 2
        $dialog = Get-DialogState -Slug $Slug -AosRoot $AosRoot

        # Kein Fortschritt = der Server hat den Beitrag abgelehnt (z. B. fehlende
        # Ruecknahmebedingung). Erneuter Lauf mit gleichem Prompt aendert daran nichts.
        if ($dialog.revision -eq $revisionBefore) {
            Write-Warning "Kein Fortschritt: revision unveraendert bei $($dialog.revision) nach Lauf von '$turn'."
            Write-Warning "Vermutlich hat der Server den Beitrag abgelehnt. Abbruch statt Wiederholung."
            break
        }
    }
}

# -- Abschluss --------------------------------------------------------------
Write-Host ""

$htmlUrl = "file:///$($AosRoot -replace '\\','/')/dialoge/$Slug.html"

if ($dialog.state -eq "done") {
    Write-Host "=== Dialog abgeschlossen ===" -ForegroundColor Green
    Write-Host "HTML: dialoge\$Slug.html"
    Write-Host "Im Browser öffnen: $htmlUrl"
} elseif ($manualStop) {
    # Kein Fehlschlag: ein nur interaktiv erreichbarer Agent ist am Zug.
    Write-Host "=== Warten auf $manualStop ===" -ForegroundColor Cyan
    Write-Host "Der Dialog steht bei state=$($dialog.state)$(if ($dialog.turn) { ", Zug: $($dialog.turn)" })."
    Write-Host "Lass $manualStop in seiner Oberflaeche antworten - der MCP-Server aos-dialog ist dort registriert."
    Write-Host "Danach diesen Lauf erneut starten; der Resume-Pfad setzt an der offenen Phase auf."
    Write-Host "Mitlesen: $htmlUrl"
} else {
    Write-Warning "Dialog nicht abgeschlossen (state=$($dialog.state) nach $iteration Iterationen)."
    Write-Host "Manuell prüfen: dialoge\$Slug.html"
}
