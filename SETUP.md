# UAOS Setup: Symbolische Links unter Windows

Diese Anleitung beschreibt die einmalige Einrichtung der symbolischen Links (Symlinks), um die UAOS-Befehle und Hooks für **Claude Code** auf diesem System verfügbar zu machen.

---

## Voraussetzungen

Stellen Sie sicher, dass in den Windows-Systemeinstellungen der **Entwicklermodus** (Developer Mode) aktiviert ist. Dadurch können symbolische Links ohne Administratorrechte erstellt werden.

---

## Einrichtung der Links

Führen Sie die folgenden Befehle in einer **PowerShell-Konsole** aus:

```powershell
# 1. Commands verknüpfen
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\sync.md" -Value "C:\Users\sts\AOS\commands\sync.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\git-init.md" -Value "C:\Users\sts\AOS\commands\git-init.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\entscheidungsvorlage.md" -Value "C:\Users\sts\AOS\commands\entscheidungsvorlage.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\zew-praesentation.md" -Value "C:\Users\sts\AOS\commands\zew-praesentation.md" -Force
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands\dialog-reply.md" -Value "C:\Users\sts\AOS\commands\dialog-reply.md" -Force

# 2. Hooks verknüpfen
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\hooks\block-dangerous.sh" -Value "C:\Users\sts\AOS\hooks\block-dangerous.sh" -Force
```

*Hinweis: Neue Skills, die über das Skript `add-skill.ps1` erstellt werden, werden automatisch über Hard Links verknüpft, sodass hierfür keine manuellen Symlinks angelegt werden müssen.*
