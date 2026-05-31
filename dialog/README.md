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

## Live-Orchestrierung mit dialog-runner.ps1

Die Orchestrierung erfolgt über ein zentrales PowerShell-Skript, das die Schleife steuert und Claude Code über die CLI aufruft:

```powershell
# Dialog starten (AG initialisiert und schreibt ersten Beitrag)
C:\Users\sts\AOS\scripts\dialog-runner.ps1 -Topic "thema-name" -MaxRounds 5 -InitialPrompt "Deine Startfrage..."
```

### Ablaufsteuerung

1. **Antigravity startet:** Schreibt den ersten Beitrag in `from-ag.md` und setzt `status: waiting-for-claude`.
2. **Claude Code antwortet:** Das Skript ruft Claude im Headless-Modus auf:
   `npx @anthropic-ai/claude-code -p "..." --permission-mode bypassPermissions`
   Claude führt das Skill `dialog-reply` aus, schreibt seine Antwort in `from-claude.md` und setzt `status: waiting-for-ag`.
3. **Antigravity antwortet:** Das Skript wartet im Terminal, bis die status.md-Datei aktualisiert wird. Der Benutzer antwortet direkt im Antigravity-Chatfenster über die dort verknüpfte Skill-Datei `dialog-reply`.
4. **Schleifenende:** Sobald die Rundenanzahl `max_rounds` überschritten wird oder einer der Agenten `status: done` setzt, beendet sich das Skript.

---

## Von Claude initiierte Dialoge (`__cc_trigger__`)

Claude Code kann eigenständig ein Thema vorschlagen:
1. Erstellt das Verzeichnis `dialog/<thema>/`.
2. Schreibt den Status `status: waiting-for-ag`.
3. Legt eine leere Datei namens `__cc_trigger__` an.

Das Skript `dialog-runner.ps1` scannt beim Start ohne Parameter nach dieser Datei und bietet dem Benutzer an, den Dialog zu übernehmen.

---

## Bisherige Dialoge

| Thema | Runden | Status | Ergebnis |
|---|---|---|---|
| `stufe-2-konzept` | 1 | offen | CC stellt Fragen zu AG-Loop-Mechanismus |
| `uaos-overhead-check` | 3 | done | Lightweight-Modus beschlossen, git-init angepasst |
