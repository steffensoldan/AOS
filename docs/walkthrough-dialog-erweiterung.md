# Dokumentation & Walkthrough: Dialog-Erweiterung (Vorspann, Desktop-Start, dritter Agent)

**Datum:** 2026-09-16
**Anlass:** Drei Lücken im Betrieb des MCP-Dialogs — die HTML-Seite erklärte sich nicht selbst,
ein Dialog ließ sich nur aus der Konsole starten, und es gab nur zwei feste Teilnehmer.

---

## 1. Durchgeführte Änderungen

### Paket A — Verfahrens-Vorspann in der HTML-Seite

Im Fremdrepo `dialog-lite-src/dialog-lite` (eigener Commit `0d4e376`, als Patch gesichert):

* **[MODIFY]** `src/dialog_lite/render.py`: Konstanten `PROCEDURE_STEPS` (Zustand, Titel,
  Werkzeuge, Beschreibung) und `PROCEDURE_RULES`; `_procedure_html(state)` rendert einen
  zugeklappten `<details>`-Block und hebt die aktuelle Phase hervor; CSS-Block `.procedure`.
* **[MODIFY]** `src/dialog_lite/server.py`: `INSTRUCTIONS` wird über `_instructions()` aus
  denselben Konstanten aufgebaut, statt den Verfahrenstext ein zweites Mal zu führen.
* **[NEW]** `docs/dialog-lite-vorspann.patch`: der Commit als `format-patch`, damit die lokale
  Abweichung ein Upstream-Update übersteht (`git am`).

### Paket B — Start aus der Desktop-Oberfläche

* **[NEW]** `commands/dialog-start.md`: Slash-Command für die Claude-Code-Desktop-App.
* **[NEW]** `recipes/dialog-start.yaml`: Goose-Recipe mit den Parametern `slug`, `topic`,
  `partner`.
* **[NEW]** `recipes/dialog-start.deeplink.txt`: erzeugter Deeplink für Goose Desktop.
* **[NEW]** `~/.gemini/config/plugins/agos-core/skills/dialog-start/SKILL.md` (außerhalb des
  Repos): Skill für Antigravity.

Alle drei folgen demselben Ablauf: Der startende Agent ruft `dialog_open` und seine eigene
`dialog_probe` direkt über MCP auf und übergibt erst danach an `dialog-loop.ps1` im
Resume-Pfad, als Hintergrundprozess.

### Paket C — Antigravity als austauschbarer Debattant

* **[NEW]** `~/.gemini/config/mcp_config.json` (außerhalb des Repos): Registrierung des
  MCP-Servers mit `--as antigravity`, `--dir <AOS_ROOT>\dialoge`. Die Datei existierte, war
  aber 0 Bytes groß.
* **[MODIFY]** `scripts/dialog-loop.ps1`:
  * `Get-AgentRegistry` ersetzt die feste Paar-Verdrahtung — ein Eintrag je Kennung mit
    `Mode` (`headless`/`manual`), `Exe` und einem `Args`-Scriptblock.
  * `Invoke-Agent` als Dispatcher; `Invoke-AgentHeadless` nimmt jetzt einen `ArgBuilder`
    statt auf den Agentennamen zu verzweigen.
  * Neue Parameter `-Initiator` und `-Partner` (Defaults `goose`/`claude`).
  * Wartemodus: Ein Agent im `Mode = manual` führt zu Rückgabe `manual`, Meldung
    `=== Warten auf <agent> ===` und Exit 0 statt eines vorgetäuschten Starts.
  * `Resolve-GoosePath` analog zu `Resolve-ClaudePath`.

### Dokumentation

* **[NEW]** `docs/README.md`: Index des Ordners samt Zuständigkeitsregel (eine Quelle je Sache).
* **[NEW]** `docs/dialog-start.md`: die drei Einstiegspunkte, Ablauf, Fehlerbilder.
* **[MODIFY]** `docs/dialog-loop.md`: Agentenregistratur, Wartemodus, `-Initiator`/`-Partner`;
  der Start-Abschnitt wurde auf einen Verweis reduziert, nachdem `dialog-start.md` entstand.
* **[MODIFY]** `docs/dialog-lite.md`: Zwei-Teilnehmer-Grenze mit Belegstellen, alle drei
  Registrierungen, Abschnitt zur lokalen Abweichung vom Upstream.
* **[MODIFY]** `.gitignore`: `dialoge/*.probe-*.json` und `dialog-lite-src/` ausgeschlossen.
* **[DELETE]** `hello.txt`: Testartefakt im Stammverzeichnis (Workspace-Hygiene).

---

## 2. Testergebnisse & Verifizierung

### Automatisiert

* **PowerShell-Parser** (`[Parser]::ParseFile`, PS 5.1.26100.8875): keine Syntaxfehler nach
  jedem Patch-Schritt. Keine Reste der alten Verdrahtung (`$gooseExe`, `$claudeExe`,
  `$gooseOpenPrompt`, `$claudeProbePrompt`): 0 Treffer.
* **Rendering aller vier Zustände** (`probing`, `probe_review`, `debating`, `done`): Vorspann
  vorhanden, genau eine markierte Phase je Zustand, Block vor der Sondenphase, Verfahrenstext
  genau einmal im Dokument.
* **`goose recipe validate`**: „✓ recipe file is valid".
* **Registratur-Test**: `claude` und `goose` mit aufgelöstem Pfad und korrekter Kommandozeile,
  `antigravity` als `manual` ohne Programmstart, unbekannter Agent → `fatal`.

### Manuell

* **Regression**: Aufruf ohne die neuen Parameter verhält sich unverändert
  (`goose (oeffnet) gegen claude`, Dialog bereits abgeschlossen, Exit 0).
* **Neue Paarung**: `-Initiator claude -Partner antigravity` wird angenommen, Antigravity im
  Banner als „nur interaktiv (kein Headless-Start)" ausgewiesen.
* **Fehlerfall**: unbekannter Agent wird vor jedem Prozessstart abgewiesen, Exit 1.
* **Browser**: Vorspann zugeklappt und aufgeklappt geprüft, Platzierung korrekt.

### Nicht verifiziert — ausdrücklich offen

* **`--allowedTools` mit `mcp__aos-dialog__*`**: weiterhin unbestätigt. Kein Lauf kam bisher
  bis zum ersten MCP-Aufruf des headless gestarteten Claude; die Läufe scheiterten vorher an
  Authentifizierung und Guthaben.
* **Dark Mode des Vorspanns**: nicht visuell geprüft — der Vorschau-Pane rendert lokale
  Dateien immer hell. Alle neuen Farben laufen über bestehende Tokens, die im
  `prefers-color-scheme: dark`-Block umdefiniert sind; der Schluss ist konstruktiv, nicht
  gemessen.
* **Vollautomatischer Durchlauf von dialog-lite**: bisher keiner. Der Dialog
  `aos-funktionalitaet` wurde manuell gefahren.

---

## 3. Visuelle Änderungen & Layout

Betroffen ist nur `dialoge/<slug>.html`.

* **Layout-Typ:** einspaltig, `main` mit `max-width: 820px`, zentriert. Der Vorspann sitzt
  zwischen der Metazeile (Slug, Status-Pille, Runde, Teilnehmer, Stand) und der Überschrift
  „Sondenphase".
* **Farbpalette:** über CSS-Variablen, hell und dunkel nach `prefers-color-scheme`. Hell:
  Grund `#f3f3f0`, Karten `#fff`, Schrift `#191b20`, Akzent `#1f5aa6`. Dunkel: Grund
  `#14161a`, Karten `#1c1f25`, Schrift `#e7e7e2`, Akzent `#7faadf`.
* **Komponenten-Beschreibung:**
  * *Vorspann (neu):* `<details>`-Element mit Rahmen in `--rule` auf `--card`. Zugeklappt eine
    graue Zeile „Wie dieser Dialog funktioniert" mit Dreieck-Marker. Aufgeklappt eine
    nummerierte Liste der vier Schritte; je Schritt fetter Titel, dahinter die zuständigen
    Werkzeuge in Monospace-Grau, darunter der Beschreibungstext. Der Schritt, der dem
    aktuellen Zustand entspricht, steht in Akzentfarbe und trägt die Marke „← HIER" in
    Kapitälchen. Darunter, eingeleitet durch eine graue Zeile, eine Aufzählung der drei
    Regeln, die der Server erzwingt.
  * *Übrige Seite:* unverändert — Sondenphase als Karten mit Monospace-Artefakten, Verlauf als
    Beiträge mit Einwänden an linker Akzentlinie, Ergebnis in umrandeter Box, Footer mit
    Hinweis auf das eingebettete JSON.
* **Wirkungsgrenze:** Gerendert wird bei jedem Schreibvorgang. Abgeschlossene Dialoge sind
  terminal und werden nie neu gerendert — `dialoge/aos-funktionalitaet.html` bleibt ohne
  Vorspann.
