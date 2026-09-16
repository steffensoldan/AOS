---
name: dialog-start
description: Startet einen Agent-Dialog über dialog-lite aus der Desktop-App heraus - öffnet den Dialog, reicht die eigene Sonde ein und übergibt an den Loop. Aufruf via /dialog-start <slug> | <thema> | <partner>.
---

Starte einen Agent-Dialog über den MCP-Server `aos-dialog`. Kein Terminal für den Benutzer — du machst alles selbst.

Argumente: $ARGUMENTS — erwartet `<slug> | <thema> | <partner>`, mit Pipe getrennt.

## 1. Argumente prüfen

- **Slug:** nur Kleinbuchstaben, Ziffern, Bindestriche. Er wird Dateiname unter `dialoge\`.
- **Thema:** eine vollständige Frage, keine Überschrift. Je enger und prüfbarer, desto brauchbarer der Dialog.
- **Partner:** `goose` oder `antigravity`. Fehlt er, nimm `goose`.

Fehlt Slug oder Thema, FRAGE im Chat nach. Rate nicht. Eine Rückfrage, dann arbeite weiter.

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
