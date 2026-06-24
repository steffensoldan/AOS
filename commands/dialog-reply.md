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
   * Stelle sicher, dass der Status in `status.md` tatsächlich deinem erwarteten Eingangs-Status entspricht.
   * Falls `status.md` auf `status: done` steht oder ein anderer unerwarteter Status vorliegt, brich sofort ab und beende die Ausführung. Ein abgeschlossener Thread (`done`) ist terminal und darf nie reaktiviert werden.

5. **Antwort formulieren:**
   * Analysiere den gesamten Diskussionsverlauf, insbesondere den letzten Eintrag des anderen Agenten.
   * Befolge dabei die folgenden inhaltlichen Qualitätsstandards für den Agenten-Dialog (Debatten-Modus):
     1. **Kein blindes Zustimmen (Harmonie-Filter abbauen):**
        * Vermeide inhaltsleere Lobpreisungen (z. B. "Das ist ein hervorragender/genialer Vorschlag").
        * Finde in den Runden 1 und 2 zwingend mindestens eine Schwachstelle, eine alternative Option oder ein Risiko im Entwurf des anderen Agenten.
        * *Ausnahme (Entwarnung):* Falls kein direktes Risiko vorliegt, darf entwarnt werden. Der Agent muss dann zwingend aus den folgenden 5 Risikofeldern die **zwei für den aktuellen Entwurf kritischsten Felder** benennen, begründen warum genau diese relevant sind, und im Freitext detailliert analysieren, warum sie im konkreten Fall unkritisch sind:
          * *Netzwerk & Offline-Betrieb:* Fehlende Internetverbindung, Air-Gap-VMs.
          * *Daten & Volumen:* Extrem große Dateigrößen, RAM-Sperren, Timeouts.
          * *Plattform & OS:* Windows-Besonderheiten (Pfade, Registry, Zeichensätze, shell-spezifische Syntax).
          * *Berechtigungen & Pfade:* Dateizugriffskonflikte, Schreibschutz, mangelnde Rechte.
          * *Ressourcen-Limits:* CPU/RAM-Überlastung bei rechenintensiven Aufgaben (z. B. OCR, LibreOffice-Renderings).
     2. **Explizite Alternativenprüfung:**
        * Bei jedem technischen Entwurf muss mindestens eine alternative Herangehensweise genannt und kurz gegenübergestellt werden.
     3. **Kriterienbasierte Bewertung (Kriterien-Matrix):**
        * Bewerte Vorschläge strukturiert nach den Dimensionen: *Sicherheit*, *Robustheit*, *Wartbarkeit*, *Usability für den Endanwender* und *Compliance (Gate)*.
        * Die Dimension **"Compliance (Lizenz & Datensouveränität) [Gate]"** fungiert als Ausschlusskriterium gegen folgenden Katalog:
          * **Hard-Blocker** (Führen zum sofortigen Ausschluss des Entwurfs): (1) Unkontrollierter Datenabfluss (Cloud-Schnittstellen/CDNs ohne dokumentierte Opt-In-Lösungen), (2) Proprietäre Softwarelizenzen ohne kostenfreie kommerzielle Option für öffentliche/wissenschaftliche Einrichtungen, (3) Erfordernis einer permanenten Internetverbindung zur Laufzeit (Online-Zwang).
          * **Heilbare Verstöße** (Zulässig mit zu dokumentierendem Heilungspfad): (1) Externe Web-Ressourcen wie CDN-Fonts (Heilung: Lokales Hosten), (2) Unpräzise Versionierung (Heilung: Fixierung über requirements.txt/pyproject.toml), (3) Mangelnde Windows-Portabilität (Heilung: Kapselung in Rancher Desktop oder separates Setup-Skript).
     4. **Synthese vor Konsens (Runden-Dynamik):**
        * Ein finaler Konsens darf frühestens in Runde 3 (oder der letzten Runde) deklariert werden.
        * Falls am Ende von Runde 2 noch kein klarer, geprüfter Entwurf vorliegt, schlage dem Benutzer im Rundenstatement eine manuelle Verlängerung vor (*"Verlängerung um N Runden empfohlen, Begründung: [...]"*). Die Anpassung erfolgt durch den Benutzer manuell in `status.md`.



6. **Antwort schreiben (Atomarer Schreibschritt 1):**
   * Hänge deine Antwort an deine Quell-Datei (`from-claude.md` bzw. `from-ag.md`) an. Nutze das aktuelle Datum/Uhrzeit und die aktuelle Runde `current_round` aus `status.md` im folgenden Format:
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
   * **Wichtig**: Die Datei muss zwingend als **UTF-8 ohne BOM** gespeichert und der Schreibprozess vollständig abgeschlossen und geflusht sein, bevor der nächste Schritt erfolgt.

7. **Metadaten und Status aktualisieren (Atomarer Schreibschritt 2):**
   * Erst wenn das Schreiben der Nachricht abgeschlossen ist, aktualisiere die Werte in `status.md` (ebenfalls als UTF-8 ohne BOM):
     * Setze `status` auf deinen Ausgangs-Status.
     * Passe `current_round` gemäß der Runden-Regel (Schritt 1) an.
     * Falls `current_round` nach der Anpassung größer als `max_rounds` ist, setze `status: done`.

8. **Beenden:**
   * Beende dich sofort nach dem Schreiben von `status.md`. Modifiziere keine anderen Dateien.

9. **Sicherheitsbeschränkung (Pfad-Restriktion):**
   * Da du im Headless-Modus mit weitreichenden Berechtigungen ausgeführt wirst, gilt eine strikte Selbstbeschränkung: Du darfst **ausschließlich** Dateien lesen, schreiben oder modifizieren, die sich im Verzeichnis `C:\Users\sts\AOS\dialog\<thema>\` befinden. Jegliche Dateioperationen außerhalb dieses Pfads oder das Ausführen von Systembefehlen ist dir in diesem Modus strengstens untersagt.

