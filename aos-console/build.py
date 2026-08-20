#!/usr/bin/env python3
"""Build der AOS Konsole.

Liest einen Snapshot des AOS-Repos (nur versionierte Dateien) und injiziert ihn in
das HTML-Template. Ergebnis ist eine self-contained Datei `aos-console.html`, die
direkt im Browser oder auf dem Handy geoeffnet werden kann.

Aufruf (aus beliebigem Verzeichnis):
    python build.py

Der AOS-Root wird ueber Marker-Dateien ermittelt (memory/global-rules.md + CLAUDE.md),
per Aufwaerts-Suche ab dem Skriptverzeichnis; alternativ ueber die Umgebungsvariable AOS_ROOT.
Keine externen Abhaengigkeiten, keine hartkodierten Pfade.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "aos-console.template.html")
OUTPUT = os.path.join(HERE, "aos-console.html")
PLACEHOLDER = "__AOS_SNAPSHOT__"
BUILT_NAME = "aos-console.html"  # eigene Build-Ausgabe nicht in den Snapshot einbetten

# Binaerformate werden nur als Metadaten (ohne Inhalt) erfasst.
BINARY_SUFFIXES = (".png", ".jpg", ".jpeg", ".gif", ".pdf", ".zip", ".ico", ".exe", ".dll")


def git(root, *args):
    return subprocess.check_output(["git", "-C", root, *args]).decode().strip()


def _is_aos_root(path):
    return (os.path.isfile(os.path.join(path, "memory", "global-rules.md"))
            and os.path.isfile(os.path.join(path, "CLAUDE.md")))


def find_aos_root(start):
    override = os.environ.get("AOS_ROOT")
    if override:
        override = os.path.abspath(override)
        if _is_aos_root(override):
            return override
        sys.exit(f"AOS_ROOT={override} ist kein AOS-Root (Marker fehlen).")
    path = start
    while True:
        if _is_aos_root(path):
            return path
        parent = os.path.dirname(path)
        if parent == path:
            sys.exit("AOS-Root nicht gefunden (Marker memory/global-rules.md + CLAUDE.md). "
                     "Projekt unterhalb des AOS-Repos ablegen oder AOS_ROOT setzen.")
        path = parent


def build():
    root = find_aos_root(HERE)
    tracked = git(root, "ls-files").splitlines()
    # Das eigene Projektverzeichnis nicht in den Snapshot einbetten (Fokus auf AOS-Inhalte,
    # kein Selbst-Einbetten). Standortunabhaengig ueber den relativen Pfad ermittelt.
    self_dir = os.path.relpath(HERE, root).replace(os.sep, "/")

    data = {
        "repo": "steffensoldan/AOS",
        "branch": git(root, "rev-parse", "--abbrev-ref", "HEAD"),
        "captured": git(root, "log", "-1", "--format=%cs"),
        "files": {},
    }
    for rel in tracked:
        if rel == self_dir or rel.startswith(self_dir + "/"):
            continue
        if rel.endswith(BUILT_NAME):
            continue
        path = os.path.join(root, rel)
        entry = {"path": rel, "size": os.path.getsize(path)}
        if rel.lower().endswith(BINARY_SUFFIXES):
            entry["content"] = None
        else:
            try:
                with open(path, encoding="utf-8") as fh:
                    entry["content"] = fh.read()
            except Exception as exc:  # nicht lesbare Datei im Prototyp markieren, nicht abbrechen
                entry["content"] = f"[nicht lesbar: {exc}]"
        data["files"][rel] = entry

    with open(TEMPLATE, encoding="utf-8") as fh:
        template = fh.read()
    if PLACEHOLDER not in template:
        sys.exit(f"Platzhalter {PLACEHOLDER} fehlt im Template.")

    # </script> im eingebetteten JSON entschaerfen, damit der <script>-Block nicht bricht.
    snapshot = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    with open(OUTPUT, "w", encoding="utf-8") as fh:
        fh.write(template.replace(PLACEHOLDER, snapshot))

    print(f"OK: {OUTPUT} ({len(data['files'])} Dateien, Branch {data['branch']}, Stand {data['captured']})")


if __name__ == "__main__":
    build()
