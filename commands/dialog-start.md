---
name: dialog-start
description: Startet einen Agent-Dialog über dialog-lite aus der Desktop-App heraus - öffnet den Dialog, reicht die eigene Sonde ein und übergibt an den Loop. Aufruf via /dialog-start <thema> | <partner> | <slug>.
---

Starte einen Agent-Dialog über den MCP-Server `aos-dialog`. Kein Terminal für den Benutzer — du machst alles selbst.

Argumente: $ARGUMENTS — erwartet `<thema> | <partner> | <slug>`, mit Pipe getrennt. Nur das Thema ist Pflicht.

## 0. Plausibilität der Argumente

Die Reihenfolge wird erfahrungsgemäß verwechselt. Prüfe deshalb **vor** allem anderen, was du
tatsächlich bekommen hast:

- Ein **Thema** ist ein Satz: Leerzeichen, meist ein Fragezeichen, gemischte Groß-/Kleinschreibung.
- Ein **Slug** ist eine Kurzkennung: keine Leerzeichen, nur Kleinbuchstaben, Ziffern, Bindestriche.
- Ein **Partner** ist genau `goose` oder `antigravity`.

Passt ein Wert offensichtlich zu einem anderen Feld, ordne ihn dort ein und **sage im Chat
deutlich, dass du die Argumente umsortiert hast**. Ist gar keine Frage dabei, FRAGE nach dem
Thema und lege nichts an, bevor du eine Antwort hast.

**Leg niemals einen Dialog an, dessen Thema keine Frage ist.** Ein Dialog mit einem Slug als
Thema ist inhaltlich wertlos, und der Slug ist danach belegt.

## 1. Argumente prüfen und den Slug festlegen

- **Thema:** eine vollständige Frage, keine Überschrift. Je enger und prüfbarer, desto brauchbarer der Dialog. Fehlt es, FRAGE im Chat nach — rate nicht.
- **Partner:** `goose` oder `antigravity`. Fehlt er, nimm `goose`.
- **Slug:** wurde einer angegeben, prüfe ihn; sonst leite ihn aus dem Thema ab.

**Regel für den Slug:** nur Kleinbuchstaben, Ziffern und Bindestriche. Umlaute umschreiben
(ae oe ue ss), Leerzeichen zu Bindestrichen, alles übrige entfernen, höchstens etwa 40 Zeichen.
Beispiel: „Sind die Ziele des AOS angemessen?" → `aos-ziele-angemessen`.

**Leg den Slug einmal fest und verwende danach ausnahmslos diesen einen Wert** — in
`dialog_open`, in `dialog_probe` und in der Kommandozeile des Loops. Weicht er zwischen Server
und Skript ab, sucht das Skript eine Datei, die es nicht gibt, sieht `state: absent` und
eröffnet einen **zweiten** Dialog. Nenne **Thema und Slug** im Chat, damit eine Verwechslung sofort auffällt.

## 2. Selbst nachsehen, bevor du sondierst

Sieh dir die Dateien an, um die es im Thema geht — öffne sie, lies die relevanten Zeilen. Eine Sonde ohne Dateikontakt zieht nur dein Vorwissen und ist wertlos.

## 3. Dialog öffnen

`dialog_open(slug=<slug>, topic=<thema>, partner=<partner>, max_rounds=3)`

Meldet der Server, dass der Slug bereits existiert: nicht überschreiben. Lies ihn mit `dialog_read`, melde im Chat den Stand und frage, ob fortgesetzt oder ein neuer Slug gewählt werden soll.

## 4. Eigene Sonde einreichen

`dialog_probe(slug=<slug>, artifact=...)`

Das Artefakt ist **keine Prosa**: Datei und Zeile, ein Testfall, eine konkrete Entscheidung, eine Zahl. Richtwert höchstens zehn Zeilen. Du reichst blind ein — du siehst die Sonde des anderen erst, wenn beide vorliegen.

## 5. Den Rest dem Loop übergeben

Starte `scripts\dialog-loop.ps1` **im Hintergrund** (Bash-Tool mit `run_in_background`), damit der Chat bedienbar bleibt:

```
powershell -ExecutionPolicy Bypass -File "<AOS_ROOT>\scripts\dialog-loop.ps1" -Slug "<slug>" -Topic "resume" -Initiator "<partner>" -Partner "claude" -Rounds 3
```

- `-Topic "resume"` ist ein Platzhalter: Das Thema steht bereits im Dialog und wird beim Wiederaufsetzen ignoriert, der Parameter ist aber Pflicht.
- `-Initiator` ist der **Partner**, nicht du: Du hast bereits geöffnet und sondiert, der Loop muss als Nächstes den anderen holen.
- `<AOS_ROOT>` ist das Wurzelverzeichnis des AOS — leite es aus dem Skriptpfad ab, kodiere es nicht hart.

## 6. Im Chat melden

Nenne dem Benutzer:
- den Pfad zum Mitlesen: `dialoge\<slug>.html` (Auto-Refresh alle 5 Sekunden)
- dass der Loop im Hintergrund läuft und der Chat frei ist
- **dass deine späteren Züge von einer headless gestarteten Zweitinstanz übernommen werden, nicht von dieser Sitzung.** Das ist beabsichtigt — der Server erzwingt Identität und Reihenfolge —, aber der Benutzer soll es wissen.

Ist der Partner `antigravity`, sage zusätzlich: Antigravity hat keinen Headless-Start. Der Loop hält an, sobald Antigravity am Zug ist, und meldet das. Der Benutzer lässt Antigravity in seiner eigenen Oberfläche antworten und startet den Lauf danach erneut.

## Verbote

- Kein Kommando ausgeben, das der Benutzer selbst in eine Konsole tippen soll. Der Sinn dieses Befehls ist, dass er keine öffnen muss.
- Den Loop nicht blockierend starten. Ein Dialog über drei Runden dauert Minuten.
- Keine Sonde ohne vorherigen Dateikontakt.
