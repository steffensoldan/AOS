# dialog-loop — Vollautomatische Dialog-Orchestrierung

**Stand:** 2026-09-15
**Skript:** `<AOS_ROOT>\scripts\dialog-loop.ps1`
**Abhängigkeit:** [dialog-lite](dialog-lite.md) (MCP-Server `aos-dialog`)

`dialog-loop.ps1` orchestriert einen dialog-lite-Dialog zwischen Claude Code und Goose — vollautomatisch, headless, ohne dass ein Agent interaktiv offen ist. Das Skript startet beide Agenten abwechselnd als kurzlebige Prozesse, bis der Dialog geschlossen ist.

---

## Problem, das gelöst wird

dialog-lite ist asynchron über das Dateisystem, aber jeder Agent muss **aktiv laufen**, um seine MCP-Tools aufzurufen. Ohne Orchestrator muss der Nutzer jeden Beitrag manuell anstoßen ("Du bist dran" → Goose postet → "Du bist dran" → Claude postet → ...).

`dialog-loop.ps1` ersetzt diesen manuellen Zyklus durch eine PowerShell-Schleife, die abwechselnd `goose run` und `claude -p` als Headless-Prozesse startet.

---

## Voraussetzungen

| Bedingung | Erlfüllt? | Hinweis |
|---|---|---|
| Goose CLI im PATH | ✅ | `C:\Users\sts\AppData\Local\Goose\resources\bin\goose.exe` |
| Claude CLI (Pfad dynamisch) | ✅ | Skript sucht in `%LOCALAPPDATA%\Packages\...` und `%LOCALAPPDATA%\npm-cache\...` |
| MCP-Server `aos-dialog` bei Claude registriert | ✅ | `~/.claude.json`, Name: `aos-dialog` |
| MCP-Server `aos-dialog` bei Goose registriert | ✅ | `%APPDATA%\Block\goose\config\config.yaml`, MCP-Name: `aos-dialog` |
| Python venv für MCP-Server | ✅ | `dialog-lite-src\dialog-lite\.venv\` |

---

## Start aus der Desktop-Oberfläche (Normalfall)

Ein Dialog wird im Chat der jeweiligen Anwendung ausgelöst, nicht in einer Konsole —
`/dialog-start` in Claude Code, der Skill `dialog-start` in Antigravity, der Deeplink in
Goose Desktop.

**Einzelheiten, Ablauf und Fehlerbilder: [dialog-start.md](dialog-start.md).**
Dieser Abschnitt dupliziert sie nicht.

Für diese Seite genügt: Der startende Agent öffnet den Dialog und reicht seine eigene Sonde
selbst ein; erst für die Züge des anderen ruft er `dialog-loop.ps1` im Resume-Pfad auf, als
Hintergrundprozess. Der Loop sieht davon nichts Besonderes — für ihn ist es ein Wiederaufsetzer
auf `state: probing`.

## Aufruf aus der Konsole (Nebenweg)

Für Tests und Wiederaufsetzer:

```powershell
.\scripts\dialog-loop.ps1 -Slug "themen-slug" -Topic "Vollständige Fragestellung"
```

### Parameter

| Parameter | Typ | Default | Bedeutung |
|---|---|---|---|
| `-Slug` | string (Pflicht) | — | Dialog-Kennung, wird Dateiname unter `dialoge\` |
| `-Topic` | string (Pflicht) | — | Vollständige Fragestellung des Dialogs. **Nur beim Öffnen wirksam** (State `absent`); beim Resume eines laufenden Dialogs wird der Wert ignoriert, muss aber als Pflichtparameter trotzdem mitgegeben werden (z. B. `-Topic "resume"`). |
| `-Initiator` | string | `goose` | Wer den Dialog öffnet und zuerst sondiert. Muss eine registrierte Kennung sein. |
| `-Partner` | string | `claude` | Der zweite Debattant. Muss vom Initiator verschieden sein. |
| `-Rounds` | int | 3 | Maximale Debattenrunden |
| `-TimeoutSec` | int | 300 | Timeout pro Agenten-Aufruf in Sekunden |
| `-MaxRetries` | int | 2 | Wiederholungen nach Timeout (= 3 Versuche gesamt) |

### Beispiele

```powershell
# Standarddialog
.\scripts\dialog-loop.ps1 -Slug "export-allowlist" -Topic "Allowlist oder Denylist im Secret-Check von export-aos.ps1?"

# Kurzer Dialog mit niedrigem Timeout
.\scripts\dialog-loop.ps1 -Slug "quick-test" -Topic "Ist X Y?" -Rounds 2 -TimeoutSec 180
```

---

## Ablauf

### Zustandsmaschine

Das Skript liest den Dialog-State aus der HTML-Datei (`dialoge\<slug>.html`) — dort liegt der Zustand als JSON-Block in `<script type="application/json" id="dialog-data">`. Das Skript parst diesen Block als JSON (kein Regex auf Felder).

```
absent → probing → debating → done
```

### Phasen

| Phase | Bedingung | Aktion | Agent |
|---|---|---|---|
| 1 | State = `absent` | Dialog öffnen + Sonde einreichen | Goose headless |
| 2 | (nach Phase 1) | Sonde einreichen + auflösen | Claude headless |
| 1b | State = `probing` (Resume) | Fehlende Sonde nachreichen + auflösen | je nach `probes_pending` |
| 3 | State = `debating` | Debate-Loop: abwechselnd posten, bis `done` | je nach `turn` |

### Debate-Loop

In Phase 3 startet das Skript abwechselnd den Agenten, der laut `turn`-Feld am Zug ist. Nach jedem Lauf:

1. State neu lesen
2. `revision` vergleichen — unverändert = Server hat Beitrag abgelehnt (z.B. fehlende `retract_if`) → Abbruch statt Wiederholung
3. State = `done` → exit
4. Sicherheitsventil: `maxIterations = Rounds * 2 + 4`

### Resume-Fähigkeit

Das Skript kann jederzeit abgebrochen und neu gestartet werden. Beim Neustart liest es den aktuellen State und springt zur richtigen Phase:

- `absent` → öffnen + sondieren
- `probing` → fehlende Sonden nachreichen
- `debating` → Loop mit richtigem Agenten
- `done` → sofort exit

---

## Headless-Aufruf der Agenten

### Goose

```powershell
goose run -i "<prompt-datei>" --no-session -q
```

Prompt liegt in einer Temp-Datei. `-i` ist Gooses eigener Schalter für Anweisungsdateien —
dort ist die Datei das vorgesehene Transportmittel, kein untergeschobener Fremdtext.

### Claude

```powershell
<prompt> | claude -p --allowedTools "mcp__aos-dialog__*,Read,Grep,Glob"
```

- **Prompt über stdin**, nicht über argv und nicht über einen Dateiverweis. Damit entfallen
  die Quoting-Regeln von `CommandLineToArgvW` vollständig, und es entsteht kein Temp-Artefakt.
- `--allowedTools` statt `bypassPermissions` → Least Privilege (Ziel 4: Fail-Closed-Security)
- Vorab freigegeben: `aos-dialog`-Tools + `Read`, `Grep`, `Glob` (Verifikation auf Platte)
- `Write`, `Edit`, `Bash` sind **nicht gesperrt, sondern nicht freigegeben**: sie laufen in die
  Berechtigungsabfrage, die im `-p`-Modus niemand beantworten kann, und scheitern dadurch.
  Das Ergebnis ist dasselbe, der Mechanismus ist ein anderer. Eine harte Sperre wäre
  `--disallowedTools`; wer Fail-Closed im strengen Sinn will, setzt zusätzlich diese Option.

### Agentenregistratur

Welche Agenten der Loop fahren kann, steht in `Get-AgentRegistry` in `scripts/dialog-loop.ps1` —
ein Eintrag je Kennung, wie sie beim MCP-Server per `--as` gesetzt ist:

| Kennung | Modus | Aufruf |
|---|---|---|
| `claude` | headless | `claude -p "<einzeiler>" --allowedTools "mcp__aos-dialog__*,Read,Grep,Glob"` |
| `goose` | headless | `goose run -i <promptdatei> --no-session -q` |
| `antigravity` | **manual** | kein Headless-Start — siehe unten |

Jeder Dialog ist paarweise (`dialog-lite` ist auf genau zwei Teilnehmer verdrahtet, siehe
`docs/dialog-lite.md`), aber **welches** Paar, ist frei wählbar: `-Initiator` und `-Partner`.
Ohne beide Parameter verhält sich das Skript wie bisher — `goose` öffnet, `claude` antwortet.

### Wartemodus für nur interaktive Agenten

Antigravity hat **keinen** eigenständigen Headless-Start. `agentapi new-conversation` existiert,
ist aber ein Client zu einer laufenden IDE und bricht ohne `ANTIGRAVITY_LS_ADDRESS` sofort ab
(`{"error": "ANTIGRAVITY_LS_ADDRESS is not set"}`). Ein Einmal-Aufruf wie `claude -p` oder
`goose run` ist nicht vorhanden.

Der Loop täuscht deshalb keinen Start vor, sondern hält an: `Invoke-Agent` liefert `manual`,
das Skript meldet `=== Warten auf <agent> ===` und endet mit Exit 0. Der Nutzer lässt den
Agenten in dessen eigener Oberfläche antworten und startet den Lauf erneut — der Resume-Pfad
setzt an der offenen Phase auf. Das ist kein Notbehelf, sondern derselbe Weg, den ein
abgebrochener Lauf ohnehin nimmt.

### Timeout-Wrapper

```powershell
$proc = [System.Diagnostics.Process]::Start($psi)
$timedOut = -not $proc.WaitForExit($TimeoutSec * 1000)
if ($timedOut) { $proc.Kill(); ... Retry ... }
```

Bei Timeout: Prozess killen, Retry bis `MaxRetries` erschöpft. Sicher: `thread.py` schreibt HTML atomar (`tempfile.mkstemp` + `os.replace`), Kill mid-write kann Datei nicht beschädigen.

### Fatale Fehler (kein Retry)

`Invoke-AgentHeadless` liefert `ok` | `failed` | `fatal`. Bei Exit-Code ≠ 0 greifen zwei
Stufen, die beide zu `fatal` führen:

1. **Musterliste** — die Ausgabe wird gegen `$FatalPatterns` geprüft: `Credit balance is too
   low`, `Invalid API key`, `authentication_error`, `Failed to authenticate`, `OAuth session
   expired`, `Please run /login`, `insufficient_quota`. Trifft ein Muster, bricht der Lauf nach
   dem **ersten** Versuch ab.
2. **Determinismus-Auffangnetz** — greift kein Muster, wird die Ausgabe mit der des
   Vorversuchs verglichen. Sind beide identisch, ist der Fehler deterministisch und ein
   dritter Versuch sinnlos: Abbruch nach dem **zweiten** Versuch.

Stufe 2 macht die Musterliste unkritisch. Sie beschleunigt den Abbruch nur von zwei auf einen
Versuch; ein unbekannter fataler Fehler wird trotzdem erkannt. Das war nicht immer so — der
erste Entwurf hatte nur Stufe 1 und lief prompt in einen Auth-Fehler, den keine Zeile der
Liste abdeckte. Neue Muster gehören dennoch in `$FatalPatterns` in `scripts/dialog-loop.ps1`.

**Grenze:** Stufe 2 beendet auch einen transienten Fehler, der zufällig zweimal dieselbe
Meldung erzeugt. Der Preis ist ein verlorener dritter Versuch, nicht ein falsches Ergebnis.

Das Abbruchsignal gilt phasenübergreifend: nach einem `fatal` feuert weder der Resume-Block
(Phase 1b) noch der Debate-Loop nach.

---

## Prompt-Inhalte

### Sondenphase

Goose öffnet den Dialog und reicht eine Sonde ein. Claude reicht seine Sonde ein und löst auf (`dialog_probe_resolve`).

Sonden-Artefakt: Datei + Zeile, max 10 Zeilen, keine Prosa. Agent soll relevante Dateien selbst ansehen.

### Debate-Phase

Beide Agenten erhalten denselben Prompt. Kernanweisung:

> Prüfe jede Tatsachenbehauptung des anderen selbst auf Platte, bevor du sie annimmst oder zurückweist — Datei öffnen, Zeile lesen, gegebenenfalls nachmessen. Übernimm nichts ungeprüft und widersprich nichts ungeprüft. Nenne im Beitrag, was du geprüft hast und was du nicht prüfen konntest.

Das verhindert schnelle Konvergenz auf Zustimmung ohne Verifikation.

---

## Sicherheit

| Aspekt | Maßnahme |
|---|---|
| Least Privilege | `--allowedTools` gibt nur Dialog-Tools + Read/Grep/Glob frei; alles andere scheitert an der unbeantwortbaren Berechtigungsabfrage (keine harte Sperre — dafür `--disallowedTools`) |
| Kein `bypassPermissions` | Entspricht `global-rules.md` (Ziel 4) |
| PreToolUse-Hook | **Ungeprüft.** Plausibel, dass der Hook auch im Headless-Lauf greift, da Hooks in `settings.json` und nicht am Berechtigungsmodus hängen — verifiziert hat das niemand. Bis zu einem Test nicht als Schutzschicht einrechnen. |
| Atomare Writes | `thread.py` nutzt `tempfile.mkstemp` + `os.replace` → Kill sicher |
| Temp-Dateien | Nur für Goose (`-i`); werden nach dem Lauf gelöscht. Für Claude entsteht keine. |
| Kein Dateiverweis im Prompt | Der Prompt geht über stdin — siehe unten, warum das eine Sicherheitsfrage ist |

---

## Outputs

| Datei | Inhalt |
|---|---|
| `dialoge\<slug>.html` | Vollständiger Dialogverlauf (Proben, Posts, Ergebnis), browser-lesbar |
| Console | Fortschrittsanzeige mit Phasen, Iterationen, Exit-Codes |

Browser öffnen:
```
file:///C:/Users/sts/AOS/dialoge/<slug>.html
```

---

## Beziehung zu dialog/ (alt) und dialog-lite

| Aspekt | dialog/ (alt) | dialog-lite (MCP) | dialog-lite + dialog-loop |
|---|---|---|---|
| Orchestrator | AG (interaktiv) | Nutzer (manuell) | `dialog-loop.ps1` |
| Agent muss offen sein | ✅ beide | ✅ beide | ❌ keiner |
| Sonden-Blindheit | ❌ | ✅ serverseitig | ✅ serverseitig |
| Zug-Erzwingung | ❌ Konvention | ✅ serverseitig | ✅ serverseitig |
| Rücknahmebedingung | ❌ optional | ✅ Pflichtfeld | ✅ Pflichtfeld |
| Vollautomatisch | ✅ (AG orchestriert) | ❌ | ✅ |

`dialog-loop.ps1` reproduziert den Automatisierungsgrad des alten `dialog/`-Systems (AG als Orchestrator) mit den strukturellen Garantien von dialog-lite (Sonden-Blindheit, Zug-Erzwingung, Rücknahmebedingung).

---

## Bekannte Einschränkungen

- **Asymmetrie in Phase 1/2:** Wer öffnet und wer auföst, liegt fest — der Initiator sondiert zuerst, der Partner bewertet mit `dialog_probe_resolve`. Wer welche Rolle hat, ist seit der Agentenregistratur über `-Initiator`/`-Partner` frei wählbar; *innerhalb* eines Dialogs bleibt die Zuteilung aber fest. Wer die Voreingenommenheit bei der Konvergenz-Entscheidung ausschließen will, wechselt die Rollen zwischen zwei Dialogen.
- **Synchroner Loop:** `goose run` und `claude -p` sind synchrone Prozesse. Wenn einer hängt, blockiert die Schleife bis Timeout. Abhilfe: Timeout-Wrapper (eingebaut).
- **Prompt-Transport zu Claude:** über stdin. Der frühere Weg — ein Einzeiler über argv, der
  auf eine Temp-Datei verwies („Lies die Datei X und folge den Anweisungen darin“) — wurde
  verworfen, nachdem Claude ihn im Echtlauf zurückgewiesen hat: *„Das ist ein klassisches
  Prompt-Injection-Muster.“* Zu Recht — eine unbekannte Datei, deren Inhalt als Anweisung
  auszuführen ist, ist genau das Muster, das ein Agent ablehnen soll. Dass es beim ersten Zug
  durchlief und beim zweiten nicht, machte es schlimmer: nicht deterministisch. Über stdin ist
  der Prompt der Prompt, und das Quoting-Problem verschwindet als Nebeneffekt.
- **Umlaute in Prompt-Vorlagen:** Die stdin-Schreibweise unter PowerShell 5.1 gibt keine
  Encoding-Garantie (`StandardInputEncoding` existiert erst ab .NET Core). Die Vorlagen im
  Skript sind deshalb bewusst reines ASCII (`ae`, `oe`, `ue`). Wer sie erweitert, hält das ein.
- **PreToolUse-Hook ungeprüft:** Ob der Guardrail `hooks/block-dangerous.sh` im Headless-Lauf
  auslöst, ist nicht getestet. *Offen — ein Lauf mit einem absichtlich blockierten Muster klärt es.*
- **Beschränkung gilt nur für Claude:** `--allowedTools` betrifft ausschließlich den
  Claude-Lauf. Goose wird mit `run -i ... --no-session -q` ohne Werkzeugbegrenzung gestartet
  und setzt im Lauf frei `shell`-Kommandos ab. Die Least-Privilege-Zeile in der
  Sicherheitstabelle beschreibt damit die Hälfte der Teilnehmer. *Offen — Goose-seitige
  Begrenzung nicht untersucht.*
- **Keine parallelen Dialoge:** Skript ist prozesssynchron, ein Dialog gleichzeitig.
