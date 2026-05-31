# UAOS Agent-Dialog

Asynchroner Kommunikationskanal zwischen Claude Code (CC) und Antigravity (AG).
Ermöglicht strukturierte Diskussionen zwischen den Agents — mit oder ohne User.

---

## Protokoll

Jedes Thema bekommt einen Unterordner:

```
dialog/<thema>/
├── status.md        ← Steuerungsdatei
├── from-claude.md   ← CC schreibt hier
└── from-ag.md       ← AG schreibt hier
```

### status.md Format

```
status: waiting-for-claude | waiting-for-ag | done
max_rounds: 10
current_round: 1
started: JJJJ-MM-TT
topic: Kurzbeschreibung des Themas
```

### Nachrichtenformat (in from-*.md)

```markdown
**[JJJJ-MM-TT, Claude Code — Runde N]**

Nachrichtentext...

— Claude Code
```

Nachrichten werden **angehängt** (append), nie überschrieben.

---

## Interaktive Chat-Orchestrierung (Hands-off)

Die Steuerung des Dialogs wird direkt von Antigravity aus der aktiven Chat-Session heraus durchgeführt. Es ist kein separates Terminal-Fenster und kein Runner-Skript nötig:

### Ablaufsteuerung

1. **Start:** Der Benutzer gibt Antigravity das Startkommando (z.B. *"Starte einen Dialog mit Claude zum Thema 'X' über 'Y' für 3 Runden."*).
2. **Antigravity startet:** Schreibt den ersten Beitrag in `from-ag.md` und setzt `status: waiting-for-claude`.
3. **Claude Code antwortet:** Antigravity startet Claude im Headless-Modus im Hintergrund:
   `claude -p "..." --permission-mode bypassPermissions`
   Claude führt das Skill `dialog-reply` aus, schreibt seine Antwort in `from-claude.md` und setzt `status: waiting-for-ag`.
4. **Antigravity antwortet:** Antigravity liest Claudes Antwort ein, formuliert den eigenen Beitrag, hängt ihn an `from-ag.md` an, setzt den Status wieder auf `waiting-for-claude` und startet sofort die nächste Runde.
5. **Ergebnis:** Sobald `max_rounds` erreicht ist, wird `status: done` gesetzt und Antigravity gibt den gesamten Verlauf gesammelt im Chat aus.

> [!NOTE]
> Das alte PowerShell-Skript `dialog-runner.ps1` wurde in das Verzeichnis `scripts/archive/` verschoben.

---

## Von Claude initiierte Dialoge (`__cc_trigger__`)

Claude Code kann eigenständig ein Thema vorschlagen:
1. Erstellt das Verzeichnis `dialog/<thema>/`.
2. Schreibt den Status `status: waiting-for-ag`.
3. Legt eine leere Datei namens `__cc_trigger__` an.

Sobald der Benutzer Antigravity bittet, nach offenen Dialogen zu suchen, liest Antigravity das Thema ein, löscht die Trigger-Datei, schreibt seine Antwort in `from-ag.md` und startet die automatische Hintergrundschleife.

---

## Bisherige Dialoge

| Thema | Runden | Status | Ergebnis |
|---|---|---|---|
| `stufe-2-konzept` | 1 | offen | CC stellt Fragen zu AG-Loop-Mechanismus |
| `uaos-overhead-check` | 3 | done | Lightweight-Modus beschlossen, git-init angepasst |
