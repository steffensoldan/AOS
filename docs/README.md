# docs — Dokumentation des AOS-Agent-Dialogs

Dieser Ordner beschreibt das **MCP-basierte** Dialogsystem (`dialog-lite`) und seine
Orchestrierung. Das ältere, dateibasierte Protokoll ist getrennt dokumentiert in
[`../dialog/README.md`](../dialog/README.md).

## Dateien

| Datei | Inhalt |
|---|---|
| [dialog-lite.md](dialog-lite.md) | Der MCP-Server: Installation, die sieben Werkzeuge, Ablauf, Registrierung der Agenten, Zwei-Teilnehmer-Grenze |
| [dialog-start.md](dialog-start.md) | Einen Dialog aus der Desktop-Oberfläche starten — Claude Code, Antigravity, Goose Desktop |
| [dialog-loop.md](dialog-loop.md) | `dialog-loop.ps1`: Zustandsmaschine, Agentenregistratur, Timeouts, fatale Fehler, Wartemodus |
| [dialog-lite-vorspann.patch](dialog-lite-vorspann.patch) | Lokale Abweichung am Fremdrepo: Verfahrens-Vorspann in der HTML-Seite |
| [AOS-Loop-Dokumentation.md](AOS-Loop-Dokumentation.md) | Rückblick auf das Loop-Engineering am AOS selbst (2026-06-28) |
| [AOS-loop-optimierung.patch](AOS-loop-optimierung.patch) | Zugehöriger Patch |

## Wo was steht (eine Quelle je Sache)

Damit die Dateien nicht auseinanderlaufen, gilt eine feste Zuständigkeit:

- **Verfahren des Dialogs** (Sondenphase, Bewertung, Debatte, Abschluss) — steht *im Code*,
  in `render.py` als `PROCEDURE_STEPS`/`PROCEDURE_RULES`. Von dort speisen sich sowohl die
  Anleitung für die Agenten (`server.py`) als auch der Vorspann der HTML-Seite.
- **Inhaltliche Qualitätsregeln** (kritische Distanz, Kriterien-Matrix, Compliance-Gate) —
  [`../memory/debate-mode.md`](../memory/debate-mode.md).
- **Einstiegspunkte aus den Oberflächen** — nur `dialog-start.md`.
- **Verhalten des Orchestrators** — nur `dialog-loop.md`.
- **Registrierung und Grenzen des MCP-Servers** — nur `dialog-lite.md`.

Wer etwas ergänzt, ergänzt es an genau einer dieser Stellen und verweist von den anderen
darauf, statt den Text zu kopieren.

## Zugehörige Artefakte außerhalb dieses Ordners

| Pfad | Inhalt |
|---|---|
| `../scripts/dialog-loop.ps1` | Orchestrator |
| `../commands/dialog-start.md` | Slash-Command für Claude Code |
| `../recipes/dialog-start.yaml` | Goose-Recipe |
| `../recipes/dialog-start.deeplink.txt` | Deeplink für Goose Desktop |
| `../dialoge/` | Die Dialoge selbst, eine HTML-Datei je Thema |
| `../dialog-lite-src/` | Geklontes Fremdrepo mit dem MCP-Server (eigenes `.git`) |
