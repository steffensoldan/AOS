# dialog-start — Dialog aus der Desktop-Oberfläche starten

**Stand:** 2026-09-16
**Abhängigkeiten:** [dialog-lite](dialog-lite.md) (MCP-Server `aos-dialog`), [dialog-loop](dialog-loop.md) (Orchestrierung)

Ein Agent-Dialog wird dort ausgelöst, wo die Frage entsteht — im Chat der Anwendung, in der
gerade gearbeitet wird. Ein Terminal ist dafür nicht nötig und soll im Ablauf nicht vorkommen,
auch nicht als Zwischenschritt, den der Benutzer selbst tippt.

---

## Warum nicht einfach das Skript aufrufen

`dialog-loop.ps1` kann einen Dialog vollständig fahren, aber nur aus einer Konsole. Wer in
Claude Code, Antigravity oder Goose sitzt, müsste das Werkzeug wechseln — und der Wechsel
kostet genau den Impuls, in dem die Frage entstanden ist. Die Einstiegspunkte hier schließen
diese Lücke.

**Der Trick ist die Arbeitsteilung:** Der startende Agent läuft bereits. Er braucht für seinen
eigenen ersten Zug keinen Fremdstart — er ruft `dialog_open` und `dialog_probe` direkt über
MCP auf. Erst für die Züge des *anderen* übergibt er an den Loop, und zwar im Resume-Pfad
(`state: probing` → Phase 1b). Es entsteht keine zweite Orchestrierungslogik.

---

## Die drei Einstiegspunkte

| Oberfläche | Artefakt | Auslösung im Chat |
|---|---|---|
| Claude Code Desktop-App | `commands/dialog-start.md` | `/dialog-start <slug> \| <thema> \| <partner>` |
| Antigravity | `~/.gemini/config/plugins/agos-core/skills/dialog-start/SKILL.md` | Skill im Chat aufrufen |
| Goose Desktop | `recipes/dialog-start.yaml` | Recipe „AOS Dialog starten“ aus der Recipe-Liste wählen |

### Claude Code

```
/dialog-start export-allowlist | Allowlist oder Denylist im Secret-Check von export-aos.ps1? | goose
```

Slug, Thema und Partner mit Pipe getrennt. Fehlt der Partner, wird `goose` angenommen. Fehlen
Slug oder Thema, fragt Claude im Chat nach.

### Antigravity

Den Skill `dialog-start` im Chat aufrufen und Slug, Thema und Partner nennen. Antigravity
trägt im Dialog die Kennung `antigravity`; der Partner ist `claude` oder `goose`.

### Goose Desktop

Einmalig installieren:

```powershell
powershell <AOS_ROOT>\scripts\install-goose-recipe.ps1
```

Das Skript validiert das Recipe und kopiert es nach
`%APPDATA%\Block\goose\config\recipes\aos-dialog-starten.yaml`. Danach Goose Desktop neu
starten; das Recipe steht dort als **„AOS Dialog starten“** in der Liste. Goose fragt `topic`,
optional `slug` und `partner` beim Start ab. Nach jeder Änderung am Recipe erneut ausführen.

> **Warum kein Deeplink?**
> `goose recipe deeplink` erzeugt zwar einen `goose://`-Link, bettet die Konfiguration darin
> aber vollständig base64-kodiert ein — für dieses Recipe rund 3.900 Zeichen. Eine
> Windows-`.url`-Verknüpfung reicht ihn nicht unverkürzt durch; Goose quittiert das im Log mit
> `Failed to decode recipe deeplink`. Der Protokoll-Handler selbst ist korrekt registriert
> (`HKCU\Software\Classes\goose` → `Goose.exe "%1"`), das Problem ist allein die Länge.
> Der Weg über den Recipe-Ordner umgeht das.

---

## Der Ablauf, den alle drei durchlaufen

1. **Angaben klären.** Thema als vollständige Frage, nicht als Überschrift. Bei Lücken eine
   Rückfrage im Chat, nicht raten.

   **Der Slug wird einmal festgelegt und danach unverändert überall verwendet** — in
   `dialog_open`, in `dialog_probe` und in der Kommandozeile des Loops. Erlaubt sind nur
   Kleinbuchstaben, Ziffern und Bindestriche; Umlaute werden umschrieben, Leerzeichen zu
   Bindestrichen. Weicht der Wert zwischen Server und Skript ab, sucht das Skript eine Datei,
   die es nicht gibt, sieht `state: absent` und eröffnet einen **zweiten** Dialog. Genau das
   ist beim ersten Goose-Lauf beinahe passiert: eingegeben wurde „AOS-Ziele prüfen“, der
   Server bekam `aos-ziele-pruefen`, die Kommandozeile trug den Rohtext.
2. **Selbst nachsehen.** Die Dateien öffnen, um die es geht, und die relevanten Zeilen lesen.
   Eine Sonde ohne Dateikontakt zieht nur das Vorwissen des Modells.
3. **`dialog_open`** mit Slug, Thema, Partner, `max_rounds`.
4. **`dialog_probe`** — das eigene Artefakt: Datei und Zeile, ein Testfall, eine konkrete
   Entscheidung, eine Zahl. Richtwert höchstens zehn Zeilen. Blind: Die Sonde des anderen
   wird erst sichtbar, wenn beide vorliegen.
5. **Loop im Hintergrund starten**, mit dem Partner als `-Initiator`:
   ```
   dialog-loop.ps1 -Slug <slug> -Topic "resume" -Initiator <partner> -Partner <eigene-kennung> -Rounds 3
   ```
6. **Im Chat melden:** Pfad zum Mitlesen, dass der Loop im Hintergrund läuft.

### Warum `-Initiator` der Partner ist

Der Parameter heißt nach der Rolle im Loop, nicht nach der Rolle im Dialog. Der startende
Agent hat bereits geöffnet und sondiert; der Loop muss als Nächstes den *anderen* holen. Wer
hier die eigene Kennung einsetzt, lässt den Loop eine Zweitinstanz seiner selbst starten, die
nichts mehr zu tun hat.

### Warum `-Topic "resume"`

Das Thema steht bereits im Dialog und wird beim Wiederaufsetzen ignoriert. Der Parameter ist
trotzdem Pflicht, also bekommt er einen Platzhalter.

---

## Zwei Dinge, die überraschen

**1. Die späteren Züge übernimmt eine Zweitinstanz.**
Der Loop startet für jeden Zug einen frischen Headless-Prozess — auch für den Agenten, aus dem
heraus der Dialog gestartet wurde. Nicht die Sitzung, in der der Benutzer sitzt, führt die
Debatte weiter, sondern eine zweite Instanz derselben Kennung. Identität und Reihenfolge
stimmen, der Server erzwingt den Zug. Aber die Sitzung im Chat erfährt vom weiteren Verlauf
nichts; der steht in der HTML-Datei.

**2. Der Loop läuft im Hintergrund.**
Ein Dialog über drei Runden dauert Minuten. Blockierend gestartet wäre der Chat für diese Zeit
tot — der Terminalzwang wäre nur durch einen Wartezwang ersetzt. Deshalb Hintergrundprozess,
sofortige Rückmeldung des HTML-Pfads, Verlauf im Browser.

---

## Wenn der Partner Antigravity ist

Antigravity hat keinen Headless-Start (Begründung und Belegstelle in
[dialog-loop.md](dialog-loop.md), Abschnitt „Wartemodus für nur interaktive Agenten"). Der
Loop hält an, sobald Antigravity am Zug ist, meldet `=== Warten auf antigravity ===` und endet
mit Exit 0.

Dann: Antigravity in seiner eigenen Oberfläche antworten lassen — der MCP-Server `aos-dialog`
ist dort registriert — und den Lauf danach erneut starten. Der Resume-Pfad setzt an der
offenen Phase auf.

---

## Wenn etwas klemmt

| Symptom | Ursache / Lösung |
|---|---|
| „Thread ... existiert bereits" | Slug ist vergeben. `dialog_read` zeigt den Stand; entweder fortsetzen oder neuen Slug wählen. Nicht überschreiben. |
| Loop startet, tut aber nichts | Wahrscheinlich steht der Dialog schon auf `done`. Das Skript meldet das und endet mit Exit 0. |
| „Kein Fortschritt: revision unverändert" | Der Server hat einen Beitrag abgelehnt, meist wegen fehlender Rücknahmebedingung. Kein Wiederholungsfall — der Loop bricht bewusst ab. |
| Fatal nach einem Versuch | Authentifizierung oder Guthaben. Die Meldung nennt das Muster; siehe [dialog-loop.md](dialog-loop.md), „Fatale Fehler". |
| Werkzeuge fehlen im Chat | MCP-Server nicht registriert oder Prozess hält einen alten Codestand. Anwendung neu starten. |
