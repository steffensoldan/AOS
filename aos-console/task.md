# Aufgabenliste: AOS Konsole

## Aktueller Stand
* **Zuletzt bearbeitet:** 2026-08-20 durch Claude Code
* **Letzter Meilenstein:** Im AOS-Repo auf Feature-Branch `claude/aos-shared-folder-1yn1q8` unter `aos-console/` abgelegt (nicht auf `main`). Integration nach `main` erst bei voll lauffähiger Version.
* **Nächster Schritt:** Nutzer-Test auf dem Handy; danach Feinschliff (offene Architekturfragen in `implementation_plan.md` Abschnitt 8).
* **Offene Fragen / Blockaden:** Keine blockierenden. Offene Entscheidungen: Overhead-Definition, Token-Kalibrierung, Antigravity-Farbton.

---

## 1. Planungsphase
- [x] `PROJECT.md` ausgefüllt und verifiziert
- [x] `implementation_plan.md` erstellt

## 2. Umsetzung
- [x] Struktur-Map aus selbstbeschreibenden Kacheln (Titel, Pfad, Zähler)
- [x] Datei-Detail: Anzeigen (Vorschau/Quelltext), Bearbeiten, Speichern
- [x] Persistenz: localStorage (Snapshot) + File System Access API (lokaler Ordner)
- [x] Kennzahlen: Projekte, davon übergabefähig, Dialoge, Dateien
- [x] Kennzahl AOS-Overhead in Token (mit Aufklapp-Detail)
- [x] Dialog-Bereich: starten, Prompt-Fenster, letzte Dialoge, Verlauf
- [x] Quellen-Feld (GitHub-Snapshot / lokaler Ordner) als Erweiterungspunkt
- [x] Farbschema „Indigo & Koralle" (hell + dunkel)
- [x] Texte auf der Startseite auf das Nötige reduziert
- [x] Build-Skript `build.py` (Snapshot-Injektion, portabel)

## 3. Verifizierung & Dokumentation
- [x] JS-Syntaxcheck (`node --check`) grün
- [x] Build reproduzierbar (`python build.py`)
- [x] `walkthrough.md` erstellt
- [x] Git Commit auf Arbeitsbranch
- [x] Statusblock aktualisiert
- [ ] Nutzer-Test auf dem Handy (offen)
