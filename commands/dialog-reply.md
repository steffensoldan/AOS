---
name: dialog-reply
description: Liest den Dialogverlauf unter einem bestimmten Thema ein, formuliert die Antwort und übergibt den Status.
---

# Befehl: dialog-reply

Du wirst aufgerufen, um auf einen asynchronen Dialog im UAOS zu antworten.

## Anweisungen:

1. **Eigene Rolle bestimmen:**
   * **Wenn du Claude Code bist:**
     * Deine Quell-Datei für die Antwort ist `from-claude.md`.
     * Der letzte Beitrag, auf den du antwortest, liegt in `from-ag.md`.
     * Dein erwarteter Eingangs-Status ist `status: waiting-for-claude`.
     * Dein Ausgangs-Status nach der Antwort ist `status: waiting-for-ag`.
     * **Runden-Regel:** Falls der Dialog von Antigravity initiiert wurde (AG schreibt zuerst), bist du der *zweite* Sprecher der Runde. In diesem Fall erhöhst du `current_round` um 1 bei der Statusübergabe. Falls Claude initiiert hat, behältst du den aktuellen Wert bei.
   * **Wenn du Antigravity (Gemini) bist:**
     * Deine Quell-Datei für die Antwort ist `from-ag.md`.
     * Der letzte Beitrag, auf den du antwortest, liegt in `from-claude.md`.
     * Dein erwarteter Eingangs-Status ist `status: waiting-for-ag`.
     * Dein Ausgangs-Status nach der Antwort ist `status: waiting-for-claude`.
     * **Runden-Regel:** Falls der Dialog von Claude initiiert wurde (Claude schreibt zuerst), bist du der *zweite* Sprecher der Runde. In diesem Fall erhöhst du `current_round` um 1 bei der Statusübergabe. Falls Antigravity initiiert hat, behältst du den aktuellen Wert bei.

2. **Thema bestimmen:**
   * Ermittle den Namen des Themas primär aus der Aufforderung des Aufrufers (z. B. "Thema: <Name>" oder "für das Thema '<Name>'").
   * Falls kein Thema im Prompt angegeben ist, scanne das Verzeichnis `C:\Users\sts\AOS\dialog\` nach Ordnern, deren `status.md` auf deinen erwarteten Eingangs-Status steht.
   * Falls mehrere Ordner infrage kommen und kein Thema im Prompt spezifiziert wurde, gib einen Fehler aus und frage nach dem genauen Namen.

3. **Dateien lesen:**
   * Navigiere in das Thema-Verzeichnis: `C:\Users\sts\AOS\dialog\<thema>\`
   * Lies folgende Dateien ein:
     * `status.md` (Metadaten und aktueller Stand)
     * `from-claude.md`
     * `from-ag.md`

4. **Status verifizieren:**
   * Stelle sicher, dass der Status in `status.md` tatsächlich deinem erwarteten Eingangs-Status entspricht. Falls nicht, beende dich mit einem Hinweis darauf, wer an der Reihe ist.

5. **Antwort formulieren:**
   * Analysiere den gesamten Diskussionsverlauf, insbesondere den letzten Eintrag des anderen Agenten.
   * Formuliere eine präzise, fachliche und lösungsorientierte Antwort auf diesen Eintrag.

6. **Antwort schreiben:**
   * Hänge deine Antwort an deine Quell-Datei an. Nutze das aktuelle Datum/Uhrzeit und die aktuelle Runde `current_round` aus `status.md` im folgenden Format:
     * **Für Claude Code:**
       ```markdown
       
       **[YYYY-MM-DD HH:MM, Claude Code — Runde N]**

       [Deine Antwort hier...]

       — Claude Code
       ```
     * **Für Antigravity:**
       ```markdown
       
       **[YYYY-MM-DD HH:MM, Antigravity — Runde N]**

       [Deine Antwort hier...]

       — Antigravity
       ```

7. **Metadaten und Status aktualisieren:**
   * Aktualisiere die Werte in `status.md`:
     * Setze `status` auf deinen Ausgangs-Status.
     * Passe `current_round` gemäß der Runden-Regel (Schritt 1) an.
     * Falls `current_round` nach der Anpassung größer als `max_rounds` ist, setze `status: done`.

8. **Beenden:**
   * Beende dich sofort nach dem Schreiben. Modifiziere keine anderen Dateien.

