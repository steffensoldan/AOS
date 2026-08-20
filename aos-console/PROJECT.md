# Projekt-Metadaten: AOS Konsole

Dieses Dokument beschreibt das Projekt deklarativ und tool-neutral. Es dient als primärer Einstiegspunkt (Wiederherstellbarkeit / Zero-Context-Start).

---

## 1. Übersicht & Stakeholder
* **Ziel:** Interaktiver Web-Prototyp, der die AOS-Struktur visuell abbildet. Elemente des AOS erscheinen als selbstbeschreibende Kacheln; per Klick lassen sich Unterordner und Datei-Inhalte anzeigen, bearbeiten und speichern. Zusätzlich Kennzahlen (Projekte, davon übergabefähig, Dialoge, Dateien, AOS-Overhead in Token) und ein Dialog-Bereich (starten, Prompt, letzte Dialoge). Primäres Testmedium ist das Smartphone.
* **Verantwortlicher Client:** Claude Code
* **Maintainer / Bus-Faktor:** steffen.schmuck-soldan@zew.de (Bus-Faktor 1 — Kontextübergabe über diese Datei + `task.md`)
* **Lizenz:** ZEW-proprietär (intern)

## 2. Technologie-Stack & Lauffähigkeit
* **Core:** Vanilla HTML/CSS/JavaScript (kein Framework, keine Runtime-Abhängigkeiten)
* **Build:** Python 3 (nur Standardbibliothek) — `build.py` injiziert einen Repo-Snapshot ins Template
* **Datenbank / API:** Keine. Persistenz der Bearbeitungen über `localStorage` (Snapshot-Quelle) bzw. File System Access API (lokaler Ordner am Desktop)
* **Styling / UI:** Vanilla CSS, theme-aware (hell/dunkel), mobile-first. Schriften über Google Fonts (Archivo, IBM Plex Sans, IBM Plex Mono)
* **Paketmanager:** Keiner

## 3. Setup- & Startbefehle (Zero-Context-Befehle)
* **Abhängigkeiten installieren:** entfällt (Standardbibliothek genügt)
* **Prototyp bauen:** `python build.py`  → erzeugt `aos-console.html`
* **Starten / Testen:** `aos-console.html` im Browser öffnen (Doppelklick) oder als Claude Artifact veröffentlichen und den Link auf dem Handy öffnen
* **Linter ausführen:** entfällt (Vanilla); JS-Syntaxcheck optional via `node --check`
* **Test-Suite ausführen:** manuelle Prüfliste in `walkthrough.md` (kein automatisiertes Test-Framework im Prototyp)

## 4. Verzeichnisse & Struktur
* `aos-console.template.html`: Quell-Template (UI, CSS, JS). Enthält den Platzhalter `__AOS_SNAPSHOT__`.
* `build.py`: liest die versionierten Repo-Dateien (via `git ls-files`) und injiziert sie als JSON-Snapshot in das Template.
* `aos-console.html`: generierte, self-contained Auslieferungsdatei (aus dem Template + Snapshot). Nicht von Hand editieren — wird von `build.py` überschrieben.
* `implementation_plan.md`: technische Spezifikation, Architektur und offene Fragen.
* `task.md`: Aufgabenliste mit verbindlichem Statusblock (Wiederaufsetzpunkt).
* `walkthrough.md`: Änderungs- und Testdokumentation.

## 5. Konfiguration & Secrets
* Keine Umgebungsvariablen, keine API-Keys, keine Credentials. Daher bewusst **keine** `.env.example` (Zero-Plaintext-Policy erfüllt: es gibt nichts zu konfigurieren).

## 6. Ablage & Repository
* Liegt im AOS-Repo (`steffensoldan/AOS`) auf dem Feature-Branch `claude/aos-shared-folder-1yn1q8`, im Verzeichnis `aos-console/` — normal versioniert.
* Bewusst auf einem Branch und **nicht** auf `main`: solange die Konsole in Entwicklung ist, bleibt sie vom Hauptstand getrennt. Erst bei voll lauffähiger Version wird der Branch nach `main` integriert.
* Nicht unter `projects/` — dieser Pfad ist per `.gitignore` für separate Projekt-Repos reserviert.
