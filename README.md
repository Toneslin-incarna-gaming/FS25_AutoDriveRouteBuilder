<img src="docs/images/icon_routeBuilder.png" width="96" align="right">

# AutoDrive Strecken-Baukasten (`FS25_AutoDriveRouteBuilder`)

**Deutsch** | [English](README.en.md)

Baut AutoDrive-Strecken aus Einstellungen und platziert sie mit der Maus – statt jeden Wegpunkt einzeln zu setzen. Die Punkte werden mit AutoDrives eigenen Funktionen angelegt und im Mehrspieler an alle verteilt.

## Voraussetzungen

- Landwirtschafts-Simulator 25
- [FS25_AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive) (entwickelt mit AutoDrive 3.0.1.4)
- Mehrspieler / Dedicated Server: auf dem Server **und** bei allen Spielern in derselben Version installieren.

## Installation

1. Die Zip-Datei aus den [Releases](../../releases) laden (nicht entpacken).
2. In den Mods-Ordner legen, z. B. `Dokumente/My Games/FarmingSimulator2025/mods`.
3. Beim Laden des Spielstands zusammen mit AutoDrive aktivieren.

Selbst bauen: `modDesc.xml`, `icon_*.dds` und die Ordner `scripts` und `gui` zippen – `modDesc.xml` muss direkt in der Zip-Datei liegen. Der Ordner `docs` gehört nicht in den Mod.

Ebenfalls von mir: [AutoDrive Aufträge (FS25_AutoDriveJobs)](https://github.com/Toneslin-incarna-gaming/FS25_AutoDriveJobs).

## Inhalt

- [Start](#start)
- [Bauarten](#bauarten)
- [Tasten beim Platzieren](#tasten-beim-platzieren)
- [Hilfslinien](#hilfslinien)
- [Verzweigung / Zuführung an Hilfslinien ausrichten](#verzweigung--zuführung-an-hilfslinien-ausrichten)
- [AutoDrive-Punkte auswählen, verschieben, kopieren, löschen](#autodrive-punkte-auswählen-verschieben-kopieren-löschen)
- [Draufsicht und AutoDrive bearbeiten](#draufsicht-und-autodrive-bearbeiten)
- [Gut zu wissen](#gut-zu-wissen)

## Start

1. **LStrg + LAlt + B** öffnet das Einstellungsfenster.
2. Oben die **Bauart** wählen. Es erscheinen nur die Einstellungen dieser Bauart, rechts eine Erklärung, unten ein Schaubild.
3. **Platzieren** – die Strecke hängt als Vorschau an der Maus.
4. **Linksklick** baut. Der Baukasten bleibt aktiv, du kannst gleich weiterbauen.
5. **Ende** beendet den Baukasten.

**LStrg + LAlt + P** startet das Platzieren direkt mit den zuletzt benutzten Werten. **LStrg + LAlt + Z** nimmt die letzte Strecke zurück.

Beim Platzieren zeigt ein Panel links oben die aktuellen Werte und alle Tasten der Bauart (**Num-** klappt es ein / aus).

## Bauarten

Mit **Num1** öffnet sich beim Platzieren ein Menü mit allen Bauarten – Zahl drücken oder anklicken.

| Nr. | Bauart | Was sie baut |
|---|---|---|
| 1 | **Rückfahr-Bucht** | Eine oder mehrere Buchten nebeneinander (Silo, Parkplatz, Abladestelle): vorwärts rein bis zum Wendestück, rückwärts ins Ziel, vorwärts über die Abfahrt raus. Mit AD-Zielen (Zielname + fortlaufende Nummer) und Sammelstraßen bei mehreren Buchten. |
| 2 | **Freie Kurve** | Eine Kurve ab der Mausposition mit Seite, Winkel, Radius und Punktzahl. |
| 3 | **Hilfslinie / Kreuz** | Eine Linie mit Querlinie und Lineal zum Ausrichten. Nur du siehst sie, AutoDrive baut nichts. |
| 4 | **Gerade auf Hilfslinie** | 1. Klick = Start, 2. Klick = Ende, beide werden auf die Hilfslinie gesetzt. Die Punkte werden gleichmäßig verteilt (Abstand höchstens „max. Punktabstand“). |
| 5 | **Bogen** | Ein Bogen, der die letzten zwei Hilfslinien berührt. Die Maus wählt Ecke und Größe. |
| 6 | **Verzweigung** | Zulauf, Abzweige nach links und/oder rechts (jeder mit eigenem Winkel, Radius und Beginn), wahlweise geradeaus weiter. Als Abzweig oder Einmündung (Num3). |
| 7 | **Zuführung** | Das Gegenstück: Strecken von links und/oder rechts hinten laufen auf eine Linie zusammen. |
| 8 | **Auswählen / Verschieben** | Bestehende AD-Punkte mit dem Kasten auswählen, verschieben, kopieren, löschen. |

| Rückfahr-Bucht | Verzweigung |
|---|---|
| ![Bucht](docs/images/diagram_de.png) | ![Verzweigung](docs/images/branch_de.png) |
| **Zuführung** | **Freie Kurve** |
| ![Zuführung](docs/images/merge_de.png) | ![Kurve](docs/images/curve_de.png) |
| **Bogen** | **Hilfslinie** |
| ![Bogen](docs/images/arc_de.png) | ![Hilfslinie](docs/images/guide_de.png) |
| **Gerade auf Hilfslinie** | |
| ![Gerade](docs/images/line_de.png) | |

**Verbindungsarten** (Kurve, Bogen, Gerade, Verzweigung): **V** = Einbahn vorwärts, **B** = beidseitig, **R** = rückwärts.

## Tasten beim Platzieren

### Für alle Bauarten

| Taste | Funktion |
|---|---|
| Linksklick | bauen (bleibt aktiv) |
| Ende | Baukasten beenden |
| kurzer Rechtsklick / Num Enter | AutoDrive bearbeiten (Bauen pausiert) und zurück |
| Mausrad | Kamera zoomen |
| mittlere Maustaste halten / Num/ | frei umsehen |
| LUmschalt + Mausrad oder `,` / `.` | drehen in 5°-Schritten |
| LUmschalt + LAlt + Mausrad | fein drehen 0,1° (mit LStrg 0,01°) |
| Num8 / Num2 / Num4 / Num6 | fein verschieben 0,1 m (LUmschalt 0,01 m) |
| Num5 | Position festhalten |
| Num0 | an den nächsten AD-Punkt setzen und dessen Richtung übernehmen |
| Num1 | Bauart-Menü (LUmschalt + Num1 = vorige Bauart) |
| LAlt + Num1 | zu „Gerade auf Hilfslinie“ und zurück |
| H | Hilfskreise an / aus |
| Num- | Hilfe-Panel ein / aus |
| Num+ | Draufsicht an / aus |
| Num* | AutoDrive-Netz anzeigen an / aus |
| Entf / LUmschalt + Entf | Hilfslinie bei der Maus entfernen / zurückholen |
| LStrg + LAlt + Z | letzte Strecke (bzw. Verschiebung) rückgängig |
| LStrg + LAlt + B | Einstellungen – danach geht es an derselben Stelle weiter |

Mit gedrückter LUmschalt-, LStrg- oder LAlt-Taste zoomt das Mausrad nicht.

### Je Bauart

| Bauart | Taste | Funktion |
|---|---|---|
| Bucht | LStrg + Mausrad | Radius von Zu- und Abfahrt (LUmschalt = fein) |
| | LAlt + Mausrad | Punkte der Kurven |
| Kurve, Bogen | LStrg + Mausrad | Radius |
| | LAlt + Mausrad | Punkte |
| | Num3 | Fahrtrichtung umdrehen |
| | Num, | Verbindungsart wechseln |
| Hilfslinie | LStrg + Mausrad | Länge je Seite ±5 m (LUmschalt ±1 m) |
| Gerade | Linksklick, Linksklick | Start, Ende |
| | LAlt + Mausrad | max. Punktabstand |
| | Num0 | Start verwerfen |
| Verzweigung, Zuführung | LStrg + Mausrad | beide Radien |
| | LAlt + Mausrad | Punkte je Kurve |
| | Num3 | Abzweig / Einmündung (nur Verzweigung) |
| | Num, | Einbahn / beidseitig |
| | Num0 | Start (Zuführung: Ende des Ablaufs) auf einen AD-Punkt legen – wird damit verbunden, danach dreht sich alles um diesen Punkt |
| | LAlt + Linksklick auf eine Seite | diesen Abzweig entfernen / zurückholen |
| | LStrg + Maustaste | an Hilfslinie ausrichten (siehe unten) |

Solange LStrg oder LAlt gedrückt ist, bleibt eine Verzweigung / Zuführung stehen, damit du ihre Seiten anklicken kannst.

## Hilfslinien

- Bauart **Hilfslinie / Kreuz**: Linksklick setzt eine Linie mit Querlinie. Die Linie hat ein Lineal (Striche jeden Meter, alle 5 m länger, alle 10 m die Meterzahl) und zeigt ihre Länge.
- Die letzten zwei Linien sind orange und türkis – sie sind die Grundlage für den **Bogen**.
- Hilfslinien werden je Karte und Spielstand gespeichert und sind nur bei dir sichtbar.
- **Entf** entfernt die Linie bei der Maus, **LUmschalt + Entf** holt sie zurück, **LStrg + LAlt + L** entfernt alle.

## Verzweigung / Zuführung an Hilfslinien ausrichten

1. **LStrg + Maustaste** neben einen Abzweig klicken (links oder rechts der Hauptlinie) – die Seite ist gewählt.
2. **LStrg + Maustaste** auf eine Hilfslinie klicken (Haupt- oder Querlinie). Der Abzweig bekommt den passenden Winkel und sein Auslauf liegt genau auf der Linie.
3. Für die andere Seite dasselbe nochmal.

Der **zuerst** ausgerichtete Abzweig verschiebt die ganze Verzweigung entlang ihrer Achse. Hängt der Start mit Num0 an einem AD-Punkt, wird stattdessen der Zulauf verlängert. Der **zweite** Abzweig verschiebt nur, wo er auf der Hauptlinie beginnt. **LStrg + Num0** schaltet die Ausrichtung aus.

Als Maustaste wird eine **Seitentaste der Maus** genommen: einfach beim Platzieren mit LStrg drücken, der Mod merkt sie sich. Die Nummer steht auch im Einstellungsfenster.

## AutoDrive-Punkte auswählen, verschieben, kopieren, löschen

Bauart **Auswählen / Verschieben** – am besten in der Draufsicht:

| Taste | Funktion |
|---|---|
| linke Maustaste ziehen | Kasten aufziehen = Punkte auswählen (LUmschalt = dazu, LStrg = abwählen) |
| Klick auf einen Punkt | nur diesen wählen (LUmschalt = dazu / weg) |
| ausgewählten Punkt ziehen | ganze Auswahl verschieben |
| Num3 | frei / entlang einer Hilfslinie / quer dazu |
| Num8/2/4/6 | Auswahl um 0,1 m schieben (LUmschalt 0,01 m) |
| LStrg + LAlt + Z | letzte Verschiebung rückgängig |
| LStrg + C oder Einfg | Auswahl kopieren – die Kopie hängt an der Maus, Linksklick fügt sie ein (mehrmals möglich), drehen wie beim Platzieren |
| Entf, nochmal Entf (innerhalb 3 s) | Auswahl löschen – **nicht rückgängig zu machen** |
| Num0 | Kopieren beenden / Auswahl aufheben |

Kopiert werden die Verbindungen zwischen den ausgewählten Punkten (mit ihrer Art) und die Nebenstrecken-Markierung. AD-Ziele werden nicht kopiert, weil AutoDrive jeden Zielnamen nur einmal erlaubt.

## Draufsicht und AutoDrive bearbeiten

- **Num+** schaltet eine Draufsicht wie im Baumenü ein: W A S D bewegen, Mausrad zoomen, **Leertaste halten + Maus ziehen** dreht und kippt (Pos1 = Drehen ohne Leertaste). Esc oder Num+ zurück.
- **Num*** zeigt das AutoDrive-Netz in der Umgebung, auch zu Fuß.
- **Kurzer Rechtsklick / Num Enter** pausiert das Bauen und gibt Maus und Tasten an den AutoDrive-Editor. AutoDrive bearbeitet mit der Maus nur im Editor-Modus „erweitert“ (**Num/** stellt ihn ein), bei eingeblendetem AD-HUD und wenn du in einem Fahrzeug sitzt. Das Panel zeigt diese Punkte an.

## Gut zu wissen

- **Mehrspieler:** Der Mod muss auf dem Server und bei allen Spielern in derselben Version installiert sein.
- **Anbindung:** Die neue Strecke wird nur dort mit dem bestehenden Netz verbunden, wo du es mit Num0 festlegst. Alles andere verbindest du im AutoDrive-Editor.
- **Rückfahr-Buchten:** Von dem Punkt, an dem das Rückwärtsfahren beginnt, darf keine weitere Strecke abgehen – sonst findet AutoDrive den Weg ins Ziel nicht mehr.
- Einstellungen werden lokal in `modSettings/FS25_AutoDriveRouteBuilder.xml` gespeichert.
- Texte und Schaubilder gibt es auf Deutsch und Englisch.

## Fehler und Wünsche

Bitte als [Issue](../../issues) melden – am besten mit Screenshot und der `log.txt`.

## Ersteller

Toneslin
