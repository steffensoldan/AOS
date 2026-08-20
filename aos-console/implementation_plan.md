# Implementation Plan: AOS Konsole

Technische Spezifikation des Prototyps. Ergänzt `PROJECT.md` um Architektur, Datenfluss und Trade-offs.

---

## 1. Architektur (Überblick)
Single-Page-Anwendung, vollständig client-seitig. Ein Build-Schritt (`build.py`) bettet einen JSON-Snapshot der versionierten Repo-Dateien in das HTML-Template ein. Das Ergebnis (`aos-console.html`) ist self-contained und ohne Server lauffähig.

```
git ls-files ──► build.py ──► JSON-Snapshot ──► {Template + __AOS_SNAPSHOT__} ──► aos-console.html
```

Zur Laufzeit rendert JavaScript aus dem Snapshot: Kennzahlen, Struktur-Map, Datei-Detail/Editor und Dialog-Bereich.

## 2. Datenquellen
* **GitHub-Snapshot (Standard):** eingebetteter Stand des Repos. Read-only Basis; Bearbeitungen werden als Overrides gehalten.
* **Lokaler Ordner (Desktop):** über die File System Access API (`showDirectoryPicker`). Liest echte Dateien, berechnet Kennzahlen neu und schreibt beim Speichern zurück in die Datei (`createWritable`). Am Handy nicht verfügbar → sauberer Hinweis, Snapshot bleibt aktiv.
* Das Quellen-Feld in der Topbar ist bewusst als Erweiterungspunkt angelegt (lokal/Git künftig).

## 3. Persistenz
* **Snapshot-Quelle:** Bearbeitungen liegen in `STATE.overrides[pfad]` und werden in `localStorage` gehalten (überlebt Neuladen auf demselben Gerät). Kein Rückschrieb ins Git-Repo.
* **Lokale Quelle:** Speichern schreibt direkt in die echte Datei.
* Fällt `localStorage` aus (Sandbox blockiert), degradiert die App auf In-Memory und meldet dies.

## 4. Kennzahlen
* **Projekte / davon übergabefähig:** aus Demo-Daten (Snapshot, `projects/` real leer) bzw. real aus dem lokalen Ordner (Projekt = Verzeichnis mit `PROJECT.md`; übergabefähig, wenn zusätzlich `task.md` existiert).
* **Dialoge:** aus `STATE.dialogs` (real + historisch).
* **Dateien in Quelle:** Anzahl im aktiven Dateiset.
* **AOS-Overhead (Token):** Kontext, den jede Session automatisch lädt = `CLAUDE.md` + `memory/global-rules.md`. Schätzung Zeichen ÷ 3,7 (deutsch + Markdown). Aufklapp-Detail zeigt Aufschlüsselung, Maximalkontext (alle Markdown-Dateien) und Methode. Zahl reagiert live auf Bearbeitungen und die gewählte Quelle.

## 5. Rendering-Details
* Kompakter Markdown-Renderer (Überschriften, Listen, Code-Fences, Tabellen, Blockquote, Inline) mit HTML-Escaping vor der Umwandlung.
* Struktur-Gruppen werden per Pfad-Präfix aus dem Dateiset abgeleitet; `root` = Dateien ohne `/`.
* Detail-Ansichten laufen über ein gemeinsames Slide-over-Sheet (Bottom-Sheet am Handy, seitlich am Desktop).

## 6. Design / Farbschema
* Variante „Indigo & Koralle": Akzent Indigo `#5A45E0` (dunkel `#8B78FF`), Zweitfarbe Koralle `#FF6A5A`. Ampelfarben eigenständig (grün/amber/rot). Vollständige Token-Sätze für Light, System-Dark und expliziten Dark-Toggle.
* Agent-Farbcodierung: Claude = Indigo, Antigravity = Koralle.

## 7. Bewusste Grenzen (Prototyp)
* „Dialog starten" ist eine Simulation (legt Thread/Status an) — kein echter Claude-Headless-Start (Windows-lokal).
* Live-Abruf von GitHub aus der Artifact-Sandbox nicht möglich (privates Repo, Netz-Sperre) → Snapshot.
* Projekt-Kennzahlen im Snapshot sind Demo-Daten (klar beschriftet).

## 8. Offene Architekturfragen
* Overhead-Definition: nur auto-geladene Regelbasis (aktuell) oder optional inkl. projektspezifischer `CLAUDE.md`-Abweichungen?
* Token-Divisor 3,7 ist eine Heuristik; Kalibrierung gegen den echten Anthropic-Tokenizer offen.
* Antigravity-Farbe (Koralle) liegt nah an der roten Blockade-Statusfarbe — ggf. nach Pink/Magenta verschieben.
* Echter Repo-Rückschrieb (statt localStorage) nur über lokalen Ordner am Desktop; mobiler Schreibpfad offen.
