---
name: zew-praesentation
description: Erstellt oder bearbeitet eine ZEW-Präsentation nach dem offiziellen Corporate Design. Lädt automatisch das Design-System und die Vorlage. Aufruf: /zew-praesentation <Thema oder Aufgabe>
---

Erstelle oder bearbeite eine ZEW-PowerPoint-Präsentation. Aufgabe: $ARGUMENTS

## Pflichtregeln (immer einhalten)

- Basis ist immer die Vorlage: `C:\Users\sts\Documents\Claude\Vorlage PPT.pptx`
- Keine leere Präsentation, kein eigenes Design erfinden
- Schrift ausschließlich Calibri
- Kein Schatten, keine 3D-Effekte — flaches Design
- Logos und Wordmark nicht verschieben oder skalieren
- Bei Layoutunsicherheit: fragen, nicht raten

## Farbpalette (ab 2023)

| Name | HEX | RGB |
|---|---|---|
| Eisblau (Hauptakzent) | `#aadade` | 194 / 221 / 225 |
| News Grün | `#c8d400` | 206 / 219 / 45 |
| News Grün abgedunkelt | `#a2bc0c` | 162 / 188 / 12 |
| ZEW Intrans | `#39484f` | 57 / 72 / 79 |
| Grau 80% | `#575756` | 87 / 87 / 86 |
| Eisblau abgedunkelt I | `#7bbec4` | 127 / 190 / 196 |
| Eisblau abgedunkelt II | `#80b3c4` | 128 / 179 / 196 |

Legacy-Farben (ZEW Blau #003f7f, Hellblau #0090d4, Grün #78be20) nur auf explizite Anfrage.

## Python-Konstanten (python-pptx)

```python
from pptx.util import RGBColor
EISBLAU         = RGBColor(0xAA, 0xDA, 0xDE)
NEWS_GRUEN      = RGBColor(0xC8, 0xD4, 0x00)
NEWS_GRUEN_DARK = RGBColor(0xA2, 0xBC, 0x0C)
INTRANS         = RGBColor(0x39, 0x48, 0x4F)
GRAU            = RGBColor(0x57, 0x57, 0x56)
```

## Typografie

- Überschriften: Calibri Bold, weiß auf farbigem Hintergrund oder Intrans auf weiß
- Fließtext: Calibri Regular, Grau 80%, Mindestgröße 18 pt
- Folienformat: 33,87 × 19,05 cm (16:9)

## Diagramme & Charts

- Primär Eisblau + News Grün, Grau als Neutralton
- Keine Mischung mit Legacy-Farben
