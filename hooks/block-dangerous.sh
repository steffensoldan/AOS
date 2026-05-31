#!/usr/bin/env bash
# PreToolUse-Guardrail für Claude Code.
# Blockt offensichtlich destruktive Bash-Befehle, bevor sie ausgeführt werden.
# Aktivierung über settings.json (siehe README am Ende dieser Anleitung).
#
# Funktionsweise: Claude Code übergibt das Tool-Event als JSON via stdin.
# Exit-Code 2 = Befehl blockieren. Exit-Code 0 = erlauben.

set -euo pipefail

# JSON vom stdin lesen
INPUT="$(cat)"

# Auszuführenden Befehl extrahieren (jq erforderlich: brew install jq / apt install jq)
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

# Wenn kein Befehl vorhanden ist (z. B. anderes Tool als Bash), durchlassen
if [ -z "$CMD" ]; then
  exit 0
fi

# Liste destruktiver Muster. Erweiterbar nach Bedarf.
PATTERNS=(
  'rm[[:space:]]+-rf?[[:space:]]+/'        # rm -rf / oder rm -r /
  'rm[[:space:]]+-rf?[[:space:]]+~'        # rm -rf ~
  'rm[[:space:]]+-rf?[[:space:]]+\*'       # rm -rf *
  'git[[:space:]]+push[[:space:]].*--force' # erzwungener Push
  'git[[:space:]]+push[[:space:]].*-f([[:space:]]|$)'
  'git[[:space:]]+reset[[:space:]]+--hard'  # Arbeitsstand verwerfen
  'git[[:space:]]+clean[[:space:]]+-[a-z]*f' # ungetrackte Dateien löschen
  'mkfs'                                     # Dateisystem formatieren
  'dd[[:space:]]+if=.*of=/dev/'              # rohe Disk-Writes
  '>[[:space:]]*/dev/sd'                     # direkt auf Block-Device schreiben
  ':\(\)\{.*\};:'                            # Fork-Bomb
  'chmod[[:space:]]+-R[[:space:]]+777'       # Rechte aufreißen
)

for pat in "${PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eq "$pat"; then
    # stderr-Text erscheint für Claude und den Nutzer; Exit 2 blockt
    echo "BLOCKIERT durch Guardrail: Muster '$pat' im Befehl erkannt." >&2
    echo "Befehl: $CMD" >&2
    echo "Falls beabsichtigt, manuell im Terminal ausführen." >&2
    exit 2
  fi
done

exit 0
