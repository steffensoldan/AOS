# Universal Agentic Operating System (UAOS)

Willkommen im UAOS. Dieses Verzeichnis dient als zentrale **Single Source of Truth (SSOT)** für Konventionen, Vorlagen, Skripte und Dokumente, die von **Claude Code** und **Antigravity (Gemini)** gemeinsam auf diesem Windows-System genutzt werden.

---

## 1. Verzeichnisstruktur & Zuständigkeiten

```text
C:\Users\sts\AOS\                   ← Dieses Verzeichnis (UAOS Master)
│
├── README.md                       ← Diese Einstiegs- und Orientierungsdatei
│
├── memory\                         ← Geteiltes Langzeitgedächtnis & Standards
│   ├── global-rules.md             ← Globale Arbeitsanweisungen
│   ├── git-conventions.md          ← Einheitliche Commit- und Branch-Regeln
│   └── coding-standards.md         ← Allgemeine Programmier- & Code-Style-Richtlinien
│
├── templates\                      ← Geteilte Dateischablonen
│   ├── PROJECT.md                  ← Projekt-Metadaten & Tech-Stack
│   ├── implementation_plan.md      ← Technische Spezifikationen (Spec-First)
│   ├── task.md                     ← Aufgabenliste mit Statusblock
│   └── walkthrough.md              ← Änderungs- & Testdokumentation
│
├── dialog\                         ← Agent-zu-Agent-Kommunikationskanal
│   ├── README.md                   ← Protokoll & Nutzungsanleitung
│   └── <thema>\                    ← Pro Thema ein Unterordner
│       ├── status.md               ← waiting-for-claude | waiting-for-ag | done
│       ├── from-claude.md          ← Claude Code schreibt hier
│       └── from-ag.md              ← Antigravity schreibt hier
│
├── scripts\                        ← Geteilte Automatisierungsskripte (z. B. Python, Powershell)
│   ├── add-skill.ps1               ← Neuen Skill für beide Clients registrieren
│   ├── dialog-watch.ps1            ← Windows-Notification bei neuer Agent-Nachricht
│   ├── generate_slides.py          ← Skript zur PPTX-Generierung
│   └── sync_project.py             ← Repository-Sync-Skript
│
├── commands\                       ← Befehle für Claude Code (Master-Verzeichnis)
│   ├── sync.md                     ← Symlink in ~/.claude/commands/sync.md
│   ├── git-init.md                 ← Symlink in ~/.claude/commands/git-init.md
│   ├── entscheidungsvorlage.md     ← Symlink in ~/.claude/commands/entscheidungsvorlage.md
│   └── zew-praesentation.md        ← Symlink in ~/.claude/commands/zew-praesentation.md
│
└── hooks\                          ← Sicherheits-Hooks für Claude Code
    └── block-dangerous.sh          ← Symlink in ~/.claude/hooks/block-dangerous.sh
```

---

## 2. Einrichtung der symbolischen Links (Symlinks) unter Windows

Um die ausführbaren Komponenten für **Claude Code** bereitzustellen, müssen symbolische Links (Symlinks) angelegt werden. Stellen Sie sicher, dass in den Windows-Systemeinstellungen der **Entwicklermodus** aktiv ist (keine Administratorrechte erforderlich).

Führen Sie folgende Befehle in der PowerShell aus:

```powershell
# Commands verknüpfen
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\sync.md" -Value "C:\Users\sts\AOS\commands\sync.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\git-init.md" -Value "C:\Users\sts\AOS\commands\git-init.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\entscheidungsvorlage.md" -Value "C:\Users\sts\AOS\commands\entscheidungsvorlage.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\zew-praesentation.md" -Value "C:\Users\sts\AOS\commands\zew-praesentation.md" -Force

# Hooks verknüpfen
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\hooks\block-dangerous.sh" -Value "C:\Users\sts\AOS\hooks\block-dangerous.sh" -Force
```

---

## 3. Integration in Antigravity (Gemini)

Antigravity nutzt die Skripte und Konventionen über Wrapper-Skills, die im globalen Plugin-Verzeichnis unter `C:\Users\sts\.gemini\config\plugins\agos-core\` liegen:
* **Globale Regeln:** Werden geladen, da Antigravity beim Start die `DEVELOPMENT.md` im Projekt-Root liest, welche auf `C:\Users\sts\AOS\memory\global-rules.md` verweist.
* **Wrapper-Skills:** Die Skills in `agos-core/skills/` rufen direkt die Python-Skripte in `C:\Users\sts\AOS\scripts\` über `uv run` auf.

---

## 4. Spezifikationsgetriebenes Arbeiten (Spec-Driven Work)

Beim Wechseln zwischen den Tools wird folgendes, standardisiertes Dateiset im Projekt-Root verwendet:

1. **`PROJECT.md`:** Beschreibt das Projekt tool-neutral (Ziel, Stack, Ordnerpfade, Testbefehle).
2. **`implementation_plan.md`:** Technische Spezifikation und Architekturfragen.
3. **`task.md`:** Aufgabenliste (GFM Checkboxen `- [ ]` / `- [x]`) mit verpflichtendem Statusblock am Anfang der Datei.
4. **`walkthrough.md`:** Zusammenfassung von Codeänderungen und Testergebnissen.

### Der obligatorische Statusblock (`task.md`):
Vor jeder Übergabe an das andere Tool muss dieser Block am Anfang von `task.md` gepflegt werden, da **Claude Code kein sessionübergreifendes Gedächtnis besitzt**:

```markdown
## Aktueller Stand
Zuletzt bearbeitet: JJJJ-MM-TT durch [Claude Code | Antigravity]
Letzter abgeschlossener Schritt: [Beschreibung]
Nächster Schritt / Was als nächstes zu tun ist: [Beschreibung]
Offene Fragen / Blockaden: [Beschreibung oder "Keine"]
```

---

## 5. Arbeitsaufteilung (Single-Client-Strategie)

Um Merge-Konflikte und gesperrte Systemressourcen unter Windows zu vermeiden:
* Jedes Projekt wird primär von **einem** Client bearbeitet. Die Projektordner sind getrennt:
  * `C:\Users\sts\Projekte-Claude\` (primär für Claude Code)
  * `C:\Users\sts\Projekte-Antigravity\` (primär für Antigravity)
* Eine Übergabe an das jeweils andere Tool findet nur an expliziten **Meilensteinen** statt.
* **Übergabe-Regel:** Vor der Übergabe müssen alle Änderungen committet (cleaner Git-Status) und gepusht sein und der Statusblock in `task.md` muss aktualisiert sein.

---

## 6. Automatisierung & neue Skills (`add-skill.ps1`)

Um einen neuen Befehl/Skill zu erstellen und automatisch für beide Clients zu verknüpfen, nutzen Sie das mitgelieferte PowerShell-Skript:

```powershell
C:\Users\sts\AOS\scripts\add-skill.ps1 -CommandName "name-des-neuen-skills"
```

### Funktionsweise:
1. Erstellt (falls nicht vorhanden) eine neue Prompt-Datei `C:\Users\sts\AOS\commands\name-des-neuen-skills.md`.
2. Erstellt einen Hard Link in `~/.claude/commands/name-des-neuen-skills.md` für Claude Code.
3. Erstellt die Ordnerstruktur und den Hard Link in `~/.gemini/config/plugins/agos-core/skills/name-des-neuen-skills/SKILL.md` für Antigravity.

---

## 7. Agent-zu-Agent-Kommunikation (`dialog\`)

Claude Code und Antigravity können über den `dialog\`-Ordner asynchron miteinander kommunizieren — ohne dass der User als Bote fungiert.

### Protokoll

Jedes Thema bekommt einen Unterordner. Die Agents schreiben abwechselnd:

```
dialog/<thema>/
├── status.md        ← "waiting-for-claude" | "waiting-for-ag" | "done" + Rundenzähler
├── from-claude.md   ← Claude Code schreibt hier (append mit Zeitstempel-Header)
└── from-ag.md       ← Antigravity schreibt hier (append mit Zeitstempel-Header)
```

**Übergaberegeln:** Nur schreiben wenn `status` den eigenen Turn anzeigt. Nach dem Schreiben `status` auf den anderen Agent umschalten und `current_round` erhöhen. Bei `current_round > max_rounds` → `status: done`.

### Interaktive Chat-Orchestrierung (Hands-off)

Um einen vollautomatischen Dialog ohne Wechsel der Fenster zu starten, geben Sie Antigravity direkt in dieser Chat-Session das Startkommando (z. B. *"Führe einen Dialog mit Claude zum Thema 'X' über 'Y' für 3 Runden."*).

#### Ablauf:
1. **Initialisierung:** Antigravity erstellt den Themen-Ordner unter `dialog/` und schreibt die Startfrage in `from-ag.md`.
2. **Direkte Ausführung (Loop):** 
   * Antigravity führt Claude Code im Hintergrund aus (`claude -p "..." --permission-mode bypassPermissions`).
   * Antigravity liest Claudes Antwort aus `from-claude.md` ein.
   * Antigravity formuliert die nächste Antwort, schreibt sie in `from-ag.md` und startet sofort die nächste Runde.
3. **Ergebnis:** Der gesamte Lauf erfolgt verzögerungsfrei (ca. 60–90 Sekunden für 3 Runden). Am Ende wird Ihnen der komplette Diskussionsverlauf und die Zusammenfassung gesammelt hier im Chat präsentiert.

> [!NOTE]
> Das Skript `dialog-runner.ps1` ist veraltet (deprecated) und wurde im Ordner `scripts/archive/` abgelegt.

### Von Claude initiierte Dialoge (`__cc_trigger__`)
Claude Code kann selbstständig eine Diskussion vorschlagen. Er legt dazu einen Dialogordner an und platziert darin eine leere Datei namens `__cc_trigger__`.

Wenn Sie Antigravity bitten, nach offenen Trigger-Dateien zu suchen (z. B. *"Prüfe, ob Claude offene Dialoge hat"*), übernimmt Antigravity automatisch die Orchestrierung der Schleife und antwortet auf Claudes Eröffnungsbeitrag.

---


## 8. Versionskontrolle & Schutz vor Fehlkonfiguration (Git)

Das gesamte UAOS-Masterverzeichnis (`C:\Users\sts\AOS\`) wird per Git versioniert.

### Warum das notwendig ist:
* **Sicherheit:** Da KIs selbstständig Konfigurationen optimieren oder anpassen können, schützt Git vor fehlerhaften Änderungen oder "Verschlimmbesserungen" der globalen Regeln und Skripte.
* **Historie:** Sie können jederzeit nachvollziehen, welcher Agent zu welchem Zeitpunkt eine Regel angepasst hat (`git log`).
* **Sicherung:** Über ein privates Remote-Repository können Sie das UAOS auf andere Rechner übertragen.

### Wichtige Git-Befehle im UAOS:
* **Status prüfen:** `git status`
* **Änderungen vergleichen:** `git diff`
* **Änderungen zurücksetzen:** `git checkout -- <dateipfad>`
* **Änderungen committen:** `git add -A; git commit -m "update: [Beschreibung]"`
