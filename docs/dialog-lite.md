# dialog-lite — Agent-Dialog über MCP

**Stand:** 2026-09-15
**Quelle:** `github.com/steffensoldan/claude`, Branch `claude/session-communication-iwyzwe`
**Lokaler Pfad:** `<AOS_ROOT>\dialog-lite-src\dialog-lite\`

dialog-lite ist ein MCP-Server, der zwei Agenten einen asynchronen Dialog kanalisiert.
Er ersetzt das dateisystembasierte Protokoll (`dialog/<thema>/status.md` + `from-*.md`)
durch ein toolbasiertes Verfahren: Jeder Agent ruft MCP-Werkzeuge auf, der Server
verwaltet Zustand, Zug und Regeln.

---

## Was installiert ist

| Komponente | Pfad |
|---|---|
| Repo (geclont) | `<AOS_ROOT>\dialog-lite-src\` |
| Venv + Paket | `<AOS_ROOT>\dialog-lite-src\dialog-lite\.venv\` |
| Dialog-Dateien | `<AOS_ROOT>\dialoge\` (HTML-Dateien, eine je Thema) |
| MCP-Registrierung | Claude Code user-level (`~/.claude.json`), Name: `aos-dialog` |

**Python-Anmerkung:** Paket fordert >=3.11, System hat 3.10.2. Angepasst auf >=3.10
in `pyproject.toml` — Code nutzt `from __future__ import annotations`, läuft fehlerfrei.

---

## Die sieben Werkzeuge

| Werkzeug | Zweck |
|---|---|
| `dialog_open` | Dialog anlegen, Sondenphase starten |
| `dialog_list` | Alle Dialoge + Zustand anzeigen |
| `dialog_read` | Vollständigen Verlauf lesen (fremde Sonden verdeckt während Sondenphase) |
| `dialog_probe` | Blinde Erstlösung einreichen (Artefakt: Datei+Zeile, nicht Prosa) |
| `dialog_probe_resolve` | Sonden bewerten: `converged` (Dialog entfällt) oder `diverged` (Debatte startet) |
| `dialog_post` | Beitrag schreiben, nur wer am Zug ist; Einträge brauchen Rücknahmebedingung |
| `dialog_close` | Dialog abschließen mit Ergebnis |

---

## Ablauf bei einer konkreten Frage

### 1. Beide Agenten bekommen denselben Slug + Thema

**An Agent 1 (Claude Code, `--as claude`):**

> Nutze aos-dialog. Öffne einen Dialog mit Slug `export-allowlist`, Thema
> "Allowlist oder Denylist im Secret-Check von export-aos.ps1?", Partner
> `lokales-modell`, 3 Runden. Sieh dir `scripts/export-aos.ps1` selbst an und
> reiche deine Sonde ein — ein Artefakt, keine Prosa: Datei und Zeile.
> Danach warte; lies nichts vom anderen.

**An Agent 2 (zweiter Harness, `--as lokales-modell`):**

> Nutze aos-dialog. Der Dialog `export-allowlist` läuft. Sieh dir
> `scripts/export-aos.ps1` selbst an und reiche deine Sonde ein, bevor du
> irgendetwas vom anderen liest. Danach `dialog_probe_resolve`: stimmen die
> Artefakte überein → `converged`, sonst `diverged`. Bei `diverged` debattiert
> ihr im Wechsel bis `dialog_close`.

Der Partnername im ersten Prompt muss exakt das `--as` des zweiten Agenten sein.

### 2. Sondenphase

- Beide Agenten analysieren **unabhängig**, reichen Artefakt ein (Datei+Zeile, max. ~10 Zeilen)
- Niemand sieht die Sonde des anderen, bis beide vorliegen
- `dialog_probe_resolve` entscheidet:
  - **converged** → Dialog beendet, Ergebnis = Artefakt
  - **diverged** → Debatte startet, Differenz der Sonden = Tagesordnung Runde 1

### 3. Debatte (bei diverged)

- `dialog_post` im Wechsel; Zug wechselt strikt nach jedem Beitrag
- Jeder Einwand braucht Rücknahmebedingung: *"Ich ziehe das zurück, wenn ___"*
- Ohne Rücknahmebedingung → Beitrag wird abgelehnt
- Runde zählt hoch nach dem zweiten Sprecher
- Bei `round > max_rounds` oder `dialog_close` → Status `done`

---

## Mitlesen (visuelle Oberfläche)

**Datei:** `<AOS_ROOT>\dialoge\<slug>.html` im Browser öffnen (Doppelklick).

- Auto-Refresh alle 5 Sekunden während der Dialog läuft
- Stoppt automatisch bei `status: done`
- Danach: statisches Abschlussdokument — archivierbar, verschickbar, ohne Werkzeug lesbar
- Dark/Light-Mode je Systemeinstellung
- Zeigt: Thema, Status-Pille, Runde, Teilnehmer, Sondenphase (verdeckt bis aufgelöst), Verlauf mit Einwänden + Rücknahmebedingungen, Ergebnis

---

## Genau zwei Teilnehmer je Dialog

`dialog-lite` ist auf **zwei** Teilnehmer verdrahtet, nicht auf beliebig viele:
`thread.py:152` setzt `participants: [me, partner]`, `thread.py:281` wählt den Gegenüber als
`[p for p in participants if p != me][0]`. Auch die große Variante `dialog-mcp` begrenzt auf
genau zwei Debattierende (`service.py:96`) — sie erlaubt zusätzlich beliebig viele blinde
Sondierer, aber keine Dreier-Debatte.

**Welches** Paar debattiert, ist dagegen frei. Registriert sind drei Kennungen; jeder Dialog
nimmt zwei davon:

| Kennung | Host | Konfiguration |
|---|---|---|
| `claude` | Claude Code | `~/.claude.json`, Eintrag `aos-dialog` |
| `goose` | Goose | `%APPDATA%\Block\goose\config\config.yaml` |
| `antigravity` | Antigravity | `~/.gemini/config/mcp_config.json` |

Alle drei zeigen mit `--dir` auf denselben Ordner `<AOS_ROOT>\dialoge` und tragen ein je
eigenes `--as`. Im automatischen Loop (`dialog-loop.ps1`) wählen `-Initiator` und `-Partner`
das Paar; Antigravity läuft dort nur im Wartemodus, weil es keinen Headless-Start hat —
Einzelheiten in [dialog-loop.md](dialog-loop.md).

## Weiteren Agenten registrieren

Ein weiterer Harness (anderes Modell, andere IDE) wird über dessen jeweilige
MCP-Konfiguration hinzugefügt. JSON-Form (Standard MCP):

```json
{
  "mcpServers": {
    "aos-dialog": {
      "command": "<AOS_ROOT>\\dialog-lite-src\\dialog-lite\\.venv\\Scripts\\python.exe",
      "args": ["-m", "dialog_lite", "--as", "<kennung>", "--dir", "<AOS_ROOT>\\dialoge"]
    }
  }
}
```

**Zwei Pflichten:**
- `--as` bei beiden **unterschiedlich** → das ist die Identität im Dialog
- `--dir` bei beiden **identisch** → sonst reden sie an verschiedenen Ordnern vorbei

---

## Wenn etwas klemmt

| Symptom | Ursache / Lösung |
|---|---|
| *"... ist am Zug, nicht ..."* | Kein Defekt, sondern die Regel. `dialog_read` aufrufen und warten. |
| *"Einwand hat keine Rücknahmebedingung"* | Absicht. Jeder Einwand endet mit "Ich ziehe das zurück, wenn ___". |
| *"Die Sondenphase läuft noch"* | Der andere hat seine Sonde noch nicht abgegeben. Warten. |
| *"Gleichzeitige Änderung an ..."* | Beide haben zugleich geschrieben. Neu lesen und Aufruf wiederholen. |
| Werkzeuge tauchen nicht auf | Pfad zur `python.exe` prüfen — muss auf die `.venv` zeigen, nicht auf System-Python. Harness neu starten. |

---

## Große Variante (dialog-mcp)

Nur bei Bedarf: nachgewiesene Identität (Token), erzwungene Blindheit über mehrere
Rechner, echter Dienst.

```powershell
cd <AOS_ROOT>\dialog-lite-src\dialog-mcp
python -m venv .venv
.venv\Scripts\pip install -e .
copy config.example.toml config.toml
```

In `config.toml` je Teilnehmer ein Token eintragen (`python -c "import secrets; print(secrets.token_urlsafe(32))"`).
Start: `.venv\Scripts\python -m dialog_mcp --config config.toml`.

Agent-Anbindung:
```
claude mcp add --transport http aos-dialog http://<host>:8770/mcp --header "Authorization: Bearer <token>"
```

Mitlesen: Browser unter `http://<host>:8770/`. Ablauf bei konkreter Frage identisch zu dialog-lite.

---

## Lokale Abweichung vom Upstream

Die HTML-Seite trägt einen Verfahrens-Vorspann („Wie dieser Dialog funktioniert“), der im
Upstream-Repo nicht enthalten ist. Die Änderung liegt als Commit im geklonten Repo und
zusätzlich als Patch unter `docs/dialog-lite-vorspann.patch`. Nach einem Upstream-Update
lässt sie sich mit `git am docs/dialog-lite-vorspann.patch` erneut auftragen.

Betroffen sind `render.py` (Konstanten `PROCEDURE_STEPS`/`PROCEDURE_RULES`, `_procedure_html`)
und `server.py`, das seine `INSTRUCTIONS` aus denselben Konstanten aufbaut — der
Verfahrenstext steht dadurch genau einmal im Code.

**Grenze:** Gerendert wird bei jedem Schreibvorgang. Laufende Dialoge bekommen den Vorspann
beim nächsten Beitrag; **bereits geschlossene Dialoge sind terminal und werden nie neu
gerendert** — sie bleiben ohne Vorspann.

## Beziehung zum bestehenden AOS-Dialog

| Aspekt | alt (`dialog/`) | neu (`dialog-lite`) |
|---|---|---|
| Transport | Markdown-Dateien (`status.md`, `from-*.md`) | MCP-Tools (7 Werkzeuge) |
| Mutex | `status.md` als Datei-Schreibrecht | Server-seitig, Zug wechselt pro Beitrag |
| Sondenphase | nicht vorhanden | Pflicht vor Runde 1 (Blindheit, Artefakt) |
| Rücknahmebedingung | nicht vorhanden | Pflichtfeld bei jedem Einwand |
| Mitlesen | Dateien im Editor | HTML mit Auto-Refresh |
| Format | UTF-8-ohne-BOM Markdown | HTML mit eingebettetem JSON |
| Bestehende Dialoge | 16 Themen in `dialog/` | unberührt, kein Automigrationsbedarf |

Die inhaltlichen Qualitätsregeln (`memory/debate-mode.md`) gelten für beide Systeme.
Die Sondenphase und Rücknahmebedingung aus dem diff zu `debate-mode.md` sind in
dialog-lite bereits serverseitig implementiert.
