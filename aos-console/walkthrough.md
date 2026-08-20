# Walkthrough: AOS Konsole

Zusammenfassung der Änderungen und der Verifikation für die erste formalisierte Fassung.

---

## Was gebaut wurde
Ein self-contained Web-Prototyp, der die AOS-Struktur visuell abbildet und auf dem Handy testbar ist (als Claude Artifact veröffentlicht). Kernfunktionen:

1. **Struktur-Map** — selbstbeschreibende Kacheln pro AOS-Element (Titel, Pfad, Datei-Zähler); Klick öffnet die Datei-Liste.
2. **Datei-Detail & Editor** — Markdown-Vorschau oder Quelltext, Bearbeiten, Speichern (persistiert).
3. **Kennzahlen** — Projekte, davon übergabefähig, Dialoge, Dateien in Quelle, AOS-Overhead in Token.
4. **Dialog-Bereich** — Dialog starten (Simulation), Prompt-Fenster, letzte Dialoge inkl. echtem Verlauf aus dem Snapshot.
5. **Quellen-Feld** — GitHub-Snapshot (Standard) oder lokaler Ordner (Desktop, File System Access API).

## Architektur / Datenfluss
`build.py` liest die versionierten Dateien (`git ls-files`), erzeugt einen JSON-Snapshot und injiziert ihn an der Stelle `__AOS_SNAPSHOT__` im Template. Ergebnis: `aos-console.html`. Details in `implementation_plan.md`.

## Wesentliche Iterationen
* KPI **AOS-Overhead in Token** ergänzt (auto-geladene Regelbasis `CLAUDE.md` + `global-rules.md`, Schätzung Zeichen ÷ 3,7, Aufklapp-Detail).
* Farbschema auf **Indigo & Koralle** umgestellt (hell + dunkel, Ampelfarben erhalten, Agent-Farbcodierung).
* **Textreduktion**: Fließtext-Beschreibungen von der Startseite entfernt (mentales Modell, Kachel-Beschreibungen, Fußnote); funktionale Kurz-Labels und Aufklapp-Hilfen bleiben.

## Verifikation
* **JS-Syntaxcheck:** extrahierter App-Code mit `node --check` → OK.
* **Build reproduzierbar:** `python build.py` erzeugt `aos-console.html` fehlerfrei; Platzhalter ersetzt, keine `</script>`-Leaks im eingebetteten JSON.
* **Manuelle Prüfliste (im Browser):**
  - Kacheln öffnen Datei-Listen; Dateien öffnen Vorschau/Quelltext.
  - Bearbeiten → Speichern → Kennzeichnung „bearbeitet"; Overhead-Zahl reagiert auf Edits.
  - Hell/Dunkel-Umschalter konsistent; mobile Ansicht einspaltig, Detail als Bottom-Sheet.
  - Dialog starten legt Thread mit Status an; letzte Dialoge zeigen echten Verlauf.

## Bewusste Grenzen
Simulation statt echtem Headless-Dialog; kein Live-GitHub-Abruf (privates Repo, Sandbox); Snapshot-Projektzahlen sind Demo-Daten. Offene Punkte: `implementation_plan.md` Abschnitt 8.

## Reproduktion
```bash
cd aos-console
python build.py          # erzeugt aos-console.html
# aos-console.html im Browser öffnen oder als Artifact veröffentlichen
```
