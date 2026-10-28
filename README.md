<img src="docs/images/icon_routeBuilder.png" width="96" align="right">

# AutoDrive Strecken-Baukasten (`FS25_AutoDriveRouteBuilder`)

**Deutsch** | [English](README.en.md)

[![Spenden mit PayPal](https://img.shields.io/badge/Spenden-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

Baut AutoDrive-Strecken aus Einstellungen und platziert sie mit der Maus – statt jeden Wegpunkt einzeln zu setzen. Die Punkte werden mit AutoDrives eigenen Funktionen angelegt und im Mehrspieler an alle verteilt.

## So sieht's aus

**Buchten automatisch ins Fahrsilo setzen** – Maus ins Silo, Num9, fertig:

![Num9 im Fahrsilo](docs/images/silo_fit_de.png)

**Zufahrt an eine Hilfslinie anlegen** – der Radius bleibt, der Anschluss an die Bucht wird berechnet:

![Zufahrt an Hilfslinie](docs/images/bay_align_de.png)

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
- [Unterstützen](#unterstützen)

## Start

1. **LStrg + LAlt + B** startet den Baukasten – in der Draufsicht und mit der Bauart **Hilfslinie**.
2. **Num1** öffnet das Bauart-Menü, eine Zahl oder ein Klick wählt die Bauart.
3. Nochmal **LStrg + LAlt + B** öffnet die **Einstellungen der Bauart, die du gerade benutzt** (rechts eine Erklärung, unten ein Schaubild). „Platzieren“ oder „Zurück“ führt an dieselbe Stelle zurück.
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
| 6 | **Verzweigung** | Zulauf, Abzweige nach links und/oder rechts (jeder mit eigenem Winkel, Radius und Beginn), wahlweise geradeaus weiter. Zum Zusammenführen gibt es die Zuführung (7). |
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
| Num1 | Bauart-Menü (LUmschalt + Num1 = vorige Bauart); Rechtsklick schließt das Menü, ohne das Bauen zu pausieren |
| LAlt + Num1 | zu „Gerade auf Hilfslinie“ und zurück |
| H | Hilfskreise an / aus |
| Num- | Hilfe-Panel ein / aus |
| Num+ | Draufsicht an / aus |
| LStrg + Num+ | Draufsicht zurück über die Person / das Fahrzeug, in deren Blickrichtung |
| Num* | AutoDrive-Netz anzeigen an / aus |
| Entf / LUmschalt + Entf | Hilfslinie bei der Maus entfernen / zurückholen |
| LStrg + LAlt + Z | letzte Strecke (bzw. Verschiebung) rückgängig |
| LStrg + LAlt + B | Einstellungen der aktuellen Bauart – danach geht es an derselben Stelle weiter |

Mit gedrückter LUmschalt-, LStrg- oder LAlt-Taste zoomt das Mausrad nicht.

### Je Bauart

| Bauart | Taste | Funktion |
|---|---|---|
| Bucht | LStrg + Mausrad | Radius von Zu- und Abfahrt (LUmschalt = fein) |
| Bucht | LAlt + Mausrad | Punkte der Kurven |
| | LStrg + Seitentaste / LStrg + Linksklick | Zu- oder Abfahrt **tangential an eine Hilfslinie**: erst neben die Kurve klicken, dann auf die Hilfslinie. Der Winkel folgt der Linie, der Radius bleibt wie eingestellt, und für jede Bucht wird berechnet, wo die Kurve an die Fahrspur anschließt, damit sie genau auf der Linie beginnt bzw. endet. Die Linie darf vor oder hinter der bisherigen Kurve liegen. **LStrg + Num0** = aus. |
| | LAlt + Linksklick | auf Zu- oder Abfahrt: diese Kurve geht auf die andere Seite |
| | LStrg + Mausrad (Kurve ausgerichtet) | Radius der ausgerichteten Kurve – der Anschluss an die Fahrspur wandert mit, die Kurve bleibt an der Hilfslinie |
| | Num9 | **Fahrsilo automatisch einpassen:** Maus ins Fahrsilo nahe der Einfahrt, Num9 – Richtung entlang des Silos, Buchten mittig, Abstand = Silobreite / Anzahl, Ziele 2 m vor der Rückwand. Danach mit Num8/2/4/6 nachjustieren und Linksklick. |
| | Num3 | Bezugspunkt: Maus = erste Bucht oder Mitte aller Buchten (mittig im Silo ausrichten; Abstand = Silobreite / Anzahl). Ist die Position fest (z. B. nach Num9), bleiben die Buchten stehen – nur der Bezugspunkt wechselt |
| Kurve, Bogen | LStrg + Mausrad | Radius |
| | LAlt + Mausrad | Punkte |
| | Num3 | Fahrtrichtung umdrehen |
| | Num, | Verbindungsart wechseln |
| Hilfslinie | LStrg + Mausrad | Länge je Seite ±5 m (LUmschalt ±1 m) |
| | LAlt + Mausrad | Linie seitlich (parallel) verschieben – jedes neue Drücken von LAlt wechselt den Schritt: 1 m → 0,5 m → 0,1 m → 0,01 m. Der erste Schritt startet genau auf der zuletzt gesetzten (bzw. ausgerichteten) Linie, der Abstand dazu wird angezeigt. |
| Gerade | Linksklick, Linksklick | Start, Ende |
| | LAlt + Mausrad | max. Punktabstand |
| | Num0 | Start verwerfen |
| Verzweigung, Zuführung | LStrg + Mausrad | beide Radien |
| | LAlt + Mausrad | Punkte je Kurve |
| | Num, | Einbahn / beidseitig |
| | Num0 | Start (Zuführung: Ende des Ablaufs) auf einen AD-Punkt legen – wird damit verbunden, danach dreht sich alles um diesen Punkt |
| | LAlt + Linksklick auf eine Seite | diesen Abzweig entfernen / zurückholen |
| | LStrg + Maustaste | an Hilfslinie ausrichten (siehe unten) |

Solange LStrg oder LAlt gedrückt ist, bleibt eine Verzweigung / Zuführung stehen, damit du ihre Seiten anklicken kannst.

## Hilfslinien

- Bauart **Hilfslinie / Kreuz**: Linksklick setzt eine Linie mit Querlinie. Die Linie hat ein Lineal (Striche jeden Meter, alle 5 m länger, alle 10 m die Meterzahl) und zeigt ihre Länge.
- Die letzten zwei Linien sind orange und türkis – sie sind die Grundlage für den **Bogen**.
- Hilfslinien werden je Karte und Spielstand gespeichert und sind nur bei dir sichtbar.
- **LStrg + Seitentaste der Maus** (oder LStrg + Linksklick) an einer vorhandenen Hilfslinie (Haupt- oder Querlinie), an der Wand eines **Fahrsilos** (Seitenwand = längs, Einfahrt/Rückseite = quer) oder an der Kante eines **Gebäudes** (Bau- und Planierflächen des Gebäudes; die Kante bei der Maus zählt – haben Gebäude keine solchen Flächen, werden ihre Achsen genommen): die neue Linie wird parallel dazu gedreht. Solange sie parallel bleibt, zeigen eine gelbe Messlinie und das Panel ihren **Abstand** zu dieser Linie.
- **Entf** entfernt die Linie bei der Maus, **LUmschalt + Entf** holt sie zurück, **LStrg + LAlt + L** entfernt alle.

![Hilfslinie parallel zur Silowand](docs/images/guide_parallel_de.png)

## Verzweigung / Zuführung an Hilfslinien ausrichten

1. **LStrg + Maustaste** neben einen Abzweig klicken (links oder rechts der Hauptlinie) – die Seite ist gewählt.
2. **LStrg + Maustaste** auf eine Hilfslinie klicken (Haupt- oder Querlinie). Der Abzweig bekommt den passenden Winkel und sein Auslauf liegt genau auf der Linie.
3. Für die andere Seite dasselbe nochmal.

Der **zuerst** ausgerichtete Abzweig verschiebt die ganze Verzweigung entlang ihrer Achse. Hängt der Start mit Num0 an einem AD-Punkt, wird stattdessen der Zulauf verlängert. Der **zweite** Abzweig verschiebt nur, wo er auf der Hauptlinie beginnt. **LStrg + Num0** schaltet die Ausrichtung aus.

Als Maustaste wird eine **Seitentaste der Maus** genommen: einfach beim Platzieren mit LStrg drücken, der Mod merkt sie sich. Die Nummer steht auch im Einstellungsfenster. **Ohne Seitentaste** (einfache Maus, Touchpad) geht überall auch **LStrg + Linksklick**.

## AutoDrive-Punkte auswählen, verschieben, kopieren, löschen

Bauart **Auswählen / Verschieben** – am besten in der Draufsicht:

![Verbindungen](docs/images/connections_de.png)

| Taste | Funktion |
|---|---|
| linke Maustaste ziehen | Kasten aufziehen = Punkte auswählen (LUmschalt = dazu, LStrg = abwählen) |
| Klick auf einen Punkt | nur diesen wählen (LUmschalt = dazu / weg) |
| ausgewählten Punkt ziehen | ganze Auswahl verschieben |
| Num3 | frei / entlang einer Hilfslinie / quer dazu |
| Num8/2/4/6 | Auswahl um 0,1 m schieben (LUmschalt 0,01 m) |
| LStrg + LAlt + Z | letzte Verschiebung bzw. Änderung der Verbindungen rückgängig |
| Num7 | Auswahl genau auf die Hilfslinie legen, an der sie entlang liegt (Haupt- oder Querlinie, im Schnitt höchstens 15 m entfernt) – ergibt eine saubere Gerade |
| Num5 (genau ein Punkt gewählt) | AD-Ziel auf diesen Punkt setzen, umbenennen oder mit leerem Namen entfernen – überall auf der Karte, ohne hinzufahren |
| LAlt + Mausrad | Punktzahl eines Abschnitts ändern (Kurve oder Gerade): alle seine Punkte oder nur den ersten und letzten auswählen. Die Form bleibt (Kurve durch die alten Punkte), die Endpunkte bleiben, die Zwischenpunkte werden neu verteilt. **Linksklick** oder **Num Enter** = übernehmen, **Num0** = abbrechen. Im Abschnitt darf nichts abzweigen und kein Ziel liegen. |
| Num/ (genau zwei Punkte gewählt) | gerade Strecke zwischen den beiden Punkten: **LAlt + Mausrad** = Zahl der Zwischenpunkte, **Num,** = Richtung / beidseitig, **Linksklick** oder **Num Enter** = anlegen, **Num0** = abbrechen. Die Richtung geht vom Ende einer Strecke zum Anfang der anderen, wenn das eindeutig ist. |
| Num9 | wie Num7 und die Punkte zusätzlich gleichmäßig zwischen den beiden äußeren verteilen |
| LStrg + C oder Einfg | Auswahl kopieren – die Kopie hängt an der Maus, Linksklick fügt sie ein (mehrmals möglich), drehen wie beim Platzieren |
| Num, | Verbindungen der Auswahl: Einbahn → beidseitig → rückwärts → Einbahn (auch nur Anfangs- und Endpunkt einer Strecke wählen) |
| LStrg + Num, | Richtung der Einbahn- / Rückwärts-Verbindungen umdrehen |
| LAlt + Num, | Haupt- / Nebenstrecke umschalten |
| Entf, nochmal Entf (innerhalb 3 s) | Auswahl löschen – **nicht rückgängig zu machen** |
| Num0 | Kopieren beenden / Auswahl aufheben |

Kopiert werden die Verbindungen zwischen den ausgewählten Punkten (mit ihrer Art) und die Nebenstrecken-Markierung. AD-Ziele werden nicht kopiert, weil AutoDrive jeden Zielnamen nur einmal erlaubt.

## Draufsicht und AutoDrive bearbeiten

- Der Baukasten **startet in der Draufsicht** über dem Traktor bzw. der Person, in deren Blickrichtung, **Num+** schaltet sie aus und wieder ein: W A S D bewegen, Mausrad zoomen, **Leertaste halten + Maus ziehen** dreht und kippt (Pos1 = Drehen ohne Leertaste). Esc oder Num+ zurück.
- **Num*** zeigt das AutoDrive-Netz in der Umgebung, auch zu Fuß.
- **Kurzer Rechtsklick / Num Enter** pausiert das Bauen und gibt Maus und Tasten an den AutoDrive-Editor. AutoDrive bearbeitet mit der Maus nur im Editor-Modus „erweitert“ (**Num/** stellt ihn ein), bei eingeblendetem AD-HUD und wenn du in einem Fahrzeug sitzt. Das Panel zeigt diese Punkte an.

## Gut zu wissen

- **Mehrspieler:** Der Mod muss auf dem Server und bei allen Spielern in derselben Version installiert sein.
- **Anbindung:** Die neue Strecke wird nur dort mit dem bestehenden Netz verbunden, wo du es mit Num0 festlegst. Alles andere verbindest du im AutoDrive-Editor.
- **Rückfahr-Buchten:** Von dem Punkt, an dem das Rückwärtsfahren beginnt, darf keine weitere Strecke abgehen – sonst findet AutoDrive den Weg ins Ziel nicht mehr.
- **Deutsche Tastatur:** Beim Bauen nimmt „Rückgängig“ sowohl LStrg + LAlt + **Z** als auch **Y**. Außerhalb des Baukastens richtet sich das Spiel nach der Tastenposition der US-Tastatur – dort ist es auf deutscher Tastatur **LStrg + LAlt + Y**. Ändern lässt sich das unter Optionen → Steuerung („AD Strecken-Baukasten: letzte Strecke rückgängig“).
- Einstellungen werden lokal in `modSettings/FS25_AutoDriveRouteBuilder.xml` gespeichert.
- Texte und Schaubilder gibt es auf Deutsch und Englisch.

## Unterstützen

Der Mod ist kostenlos. Wenn er dir Zeit spart und du etwas zurückgeben möchtest, freue ich mich über eine kleine Spende – ganz freiwillig.

[![Spenden mit PayPal](https://img.shields.io/badge/Spenden-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

## Fehler und Wünsche

Bitte als [Issue](../../issues) melden – am besten mit Screenshot und der `log.txt`.

## Ersteller

Toneslin
