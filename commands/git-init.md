---
name: git-init
description: Initialisiert ein lokales Git-Repo für ein Projekt. Legt .gitignore und schlankes CLAUDE.md an, macht initialen Commit. Aufruf via /git-init <Projektpfad>.
---

Initialisiere ein lokales Git-Repository. Pfad: $ARGUMENTS

Standardpfad für neue Projekte: `C:\Users\sts\.claude\Projekte\<Projektname>`

Halte dich strikt an diese Reihenfolge:

1. Prüfe ob $ARGUMENTS angegeben wurde. Falls nicht: FRAGE nach dem Projektpfad. Fahre nicht fort ohne klaren Pfad.
2. Prüfe ob im Zielverzeichnis bereits ein `.git`-Verzeichnis existiert. Falls ja: STOPPEN und melden — kein doppeltes Init.
3. `git init` im Zielverzeichnis ausführen.
4. `.gitignore` anlegen (Inhalt siehe unten).
5. Projektspezifisches `CLAUDE.md` anlegen (Inhalt siehe unten). Frage vorher: Was ist der Tech-Stack und das Ziel des Projekts?
6. `git add -A` und `git commit -m "init: Projektstruktur"`.
7. Status melden: Pfad, Branch, Anzahl committeter Dateien.

Noch kein Remote anlegen — das erfolgt separat bei Launch.

---

Inhalt der `.gitignore` (Standard):

```
# Abhängigkeiten
node_modules/
.pnp/
.pnp.js

# Build-Outputs
dist/
build/
.next/
.nuxt/
out/

# Umgebungsvariablen
.env
.env.local
.env.*.local

# Editor & OS
.DS_Store
Thumbs.db
.vscode/
.idea/

# Logs
*.log
npm-debug.log*

# Cache
.cache/
.parcel-cache/
.eslintcache

# Python
__pycache__/
*.py[cod]
.venv/
*.egg-info/
```

---

Inhalt des projektspezifischen `CLAUDE.md`:
(Platzhalter mit tatsächlichen Angaben aus Schritt 5 füllen)

```markdown
# [Projektname]

## Ziel
[Ein Satz: Was macht dieses Projekt?]

## Tech-Stack
- [z.B. HTML/CSS/JS vanilla | React | Next.js | Python/Flask | ...]

## Projektspezifische Regeln
- [Nur was vom übergeordneten CLAUDE.md in C:\Users\sts\Projekte\ abweicht]
- [Leer lassen wenn keine Abweichungen]
```
