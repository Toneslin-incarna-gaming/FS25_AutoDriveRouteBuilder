<img src="docs/images/icon_routeBuilder.png" width="96" align="right">

# AutoDrive Strecken-Baukasten (`FS25_AutoDriveRouteBuilder`)

**Deutsch** | [English](README.en.md)

[![Spenden mit PayPal](https://img.shields.io/badge/Spenden-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

Baut AutoDrive-Strecken aus Einstellungen und platziert sie mit der Maus – statt jeden Wegpunkt einzeln zu setzen. Die Punkte werden mit AutoDrives eigenen Funktionen angelegt und im Mehrspieler an alle verteilt.

## Video

Teil 1: Rückfahr-Bucht – Bild anklicken, um das Video auf YouTube zu öffnen:

[![Video: AutoDrive Strecken-Baukasten Teil 1 – Rückfahr-Bucht](https://img.youtube.com/vi/RU473sKUrjU/hqdefault.jpg)](https://youtu.be/RU473sKUrjU)

## So sieht's aus

Buchten automatisch ins Fahrsilo setzen – Maus ins Silo, Num9, fertig:

![Num9 im Fahrsilo](docs/images/silo_fit_de.png)

Zufahrt an eine Hilfslinie anlegen – der Radius bleibt, der Anschluss an die Bucht wird berechnet:

![Zufahrt an Hilfslinie](docs/images/bay_align_de.png)

## Voraussetzungen

- Landwirtschafts-Simulator 25
- [FS25_AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive) (entwickelt mit AutoDrive 3.0.1.4)
- Mehrspieler / Dedicated Server: auf dem Server **und** bei allen Spielern in derselben Version installieren.

## Installation

1. Die Zip-Datei aus den [Releases](../../releases) laden (nicht entpacken).
2. In den Mods-Ordner legen: `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods`
3. Beim Laden des Spielstands zusammen mit AutoDrive aktivieren.

## Inhalt

- [Start](#start)
- [Bauarten](#bauarten)
- [Tasten beim Platzieren](#tasten-beim-platzieren)
- [Hilfslinien](#hilfslinien)
- [An Hilfslinien anlegen](#an-hilfslinien-anlegen)
- [AutoDrive-Punkte bearbeiten](#autodrive-punkte-bearbeiten)
- [Hindernisse anzeigen](#hindernisse-anzeigen)
- [Draufsicht und AutoDrive bearbeiten](#draufsicht-und-autodrive-bearbeiten)
- [Gut zu wissen](#gut-zu-wissen)
- [Unterstützen](#unterstützen)

## Start

1. LStrg + LAlt + B startet den Baukasten – in der Draufsicht und mit der Bauart Hilfslinie.
2. Num1 öffnet das Bauart-Menü, eine Zahl oder ein Klick wählt die Bauart.
3. Nochmal LStrg + LAlt + B öffnet die Einstellungen der Bauart, die du gerade benutzt (rechts eine Erklärung, unten ein Schaubild). „Platzieren“ oder „Zurück“ führt an dieselbe Stelle zurück, geänderte Werte bleiben in beiden Fällen erhalten.
4. Linksklick baut. Der Baukasten bleibt aktiv, du kannst gleich weiterbauen.
5. Ende beendet den Baukasten.

LStrg + LAlt + P startet das Platzieren direkt mit den zuletzt benutzten Werten. LStrg + LAlt + Z nimmt die letzte Strecke zurück.

Beim Platzieren zeigt ein Panel links oben die aktuellen Werte und alle Tasten der Bauart (Num- klappt es ein / aus).

## Bauarten

Mit Num1 öffnet sich beim Platzieren ein Menü mit allen Bauarten – Zahl drücken oder anklicken.

Verbindungsarten (Kurve, Bogen, Gerade, Verzweigung): V = Einbahn vorwärts, B = beidseitig, R = rückwärts.

### 1. Rückfahr-Bucht

Eine oder mehrere Buchten nebeneinander (Silo, Parkplatz, Abladestelle): vorwärts rein bis zum Wendestück, rückwärts ins Ziel, vorwärts über die Abfahrt raus. Mit AD-Zielen (Zielname + fortlaufende Nummer) und Sammelstraßen bei mehreren Buchten.

<img src="docs/images/diagram_de.png" width="100%" alt="Rückfahr-Bucht">

### 2. Freie Kurve

Eine Kurve ab der Mausposition mit Seite, Winkel, Radius und Punktzahl.

<img src="docs/images/curve_de.png" width="100%" alt="Freie Kurve">

### 3. Hilfslinie / Kreuz

Eine Linie mit Querlinie und Lineal zum Ausrichten. Nur du siehst sie, AutoDrive baut nichts.

<img src="docs/images/guide_de.png" width="100%" alt="Hilfslinie / Kreuz">

### 4. Gerade auf Hilfslinie

Erster Klick = Start, zweiter Klick = Ende, beide werden auf die Hilfslinie gesetzt. Die Punkte werden gleichmäßig verteilt (Abstand höchstens „max. Punktabstand“).

<img src="docs/images/line_de.png" width="100%" alt="Gerade auf Hilfslinie">

### 5. Bogen

Ein Bogen, der die letzten zwei Hilfslinien berührt. Die Maus wählt Ecke und Größe.

<img src="docs/images/arc_de.png" width="100%" alt="Bogen">

### 6. Verzweigung

Zulauf, Abzweige nach links und/oder rechts (jeder mit eigenem Winkel, Radius und Beginn), wahlweise geradeaus weiter. Zum Zusammenführen gibt es die Zuführung (7).

<img src="docs/images/branch_de.png" width="100%" alt="Verzweigung">

### 7. Zuführung

Das Gegenstück: Strecken von links und/oder rechts hinten laufen auf eine Linie zusammen.

<img src="docs/images/merge_de.png" width="100%" alt="Zuführung">

### 8. Auswählen / Verschieben

Bestehende AD-Punkte mit dem Kasten auswählen, verschieben, kopieren, löschen.

<img src="docs/images/connections_de.png" width="100%" alt="Auswählen / Verschieben">

### 9. Fahrzeug-Schablone

Ein grobes Modell eines LKW (Zugfahrzeug + Anhänger oder Auflieger) zum Prüfen, ob der Platz reicht. Es wird nichts gebaut. Mit der Maus in der Nähe einer AD-Strecke steht das Modell mit der Front darauf, in Fahrtrichtung, und der Anhänger folgt der Strecke nach hinten, auch durch Kurven. Grün = passt, rot = stößt an ein Hindernis. Die Seite, die anstößt (links, rechts, vorne oder hinten), wird zusätzlich kräftig rot ausgefüllt.

### 10. Feldrand

Baut eine Strecke rund um ein Feld, so wie das Feld jetzt ist. Anders als AutoDrives „Feldrand Punkte generieren“ (das den Feldumriss aus der Karte nimmt) tastet der Mod die echte Feldfläche ab. Zusammengepflügte, vergrößerte oder verkleinerte Felder werden deshalb richtig erkannt. Im Bauart-Menü ist es die Taste 0.

## Tasten beim Platzieren

Im Spiel gibt es zwei Fenster: oben die aktuellen Werte, links die Tasten der Bauart. Beide lassen sich mit der Maus verschieben, die Position bleibt gespeichert. Num- zeigt alle Tasten, nochmal Num- blendet die Hilfe aus. LStrg + Num- blendet die Werte aus und ein.

### Für alle Bauarten

| Was du machen willst | So geht's |
|---|---|
| Bauen | Linksklick (der Baukasten bleibt aktiv) |
| Baukasten beenden | Ende |
| Drehen | LUmschalt + Mausrad oder `,` / `.` |
| Fein drehen | LUmschalt + LAlt + Mausrad (mit LStrg noch feiner) |
| Fein verschieben | Num8 / Num2 / Num4 / Num6 (mit LStrg 0,01 m) |
| Position festhalten | Num5 |
| An einen AD-Punkt setzen | Num0 |
| Andere Bauart | Num1, dann Zahl oder Klick |
| Draufsicht an / aus | Num+ |
| Draufsicht zurück zu dir / zum Fahrzeug | LStrg + Num+ |
| Draufsicht bewegen / drehen | W A S D / Leertaste halten + Maus ziehen |
| Kamera zoomen / umsehen | Mausrad / mittlere Maustaste oder Num/ |
| AutoDrive-Netz zeigen | Num* |
| Selbst mit AutoDrive bearbeiten | kurzer Rechtsklick oder Num Enter |
| Letzte Strecke rückgängig | LStrg + LAlt + Z |
| Einstellungen der Bauart | LStrg + LAlt + B |
| Hilfe kurz / alle Tasten / aus | Num- (mehrmals drücken) |
| Hilfskreise ein / aus | H |
| Echte Hindernisse anzeigen | LStrg + H |
| Werte-Fenster ein / aus | LStrg + Num- |
| Fenster verschieben | mit der linken Maustaste ziehen (die Position wird gespeichert) |

### 1. Rückfahr-Bucht

| Was du machen willst | So geht's |
|---|---|
| Kurven größer / kleiner | LStrg + Mausrad |
| Mehr / weniger Punkte in den Kurven | LAlt + Mausrad |
| Nur Zu- oder nur Abfahrt ändern | Maus auf die Kurve (wird weiß), dann Mausrad wie oben |
| Zu- oder Abfahrt nur bei dieser Bucht weglassen | Maus auf die Kurve, Entf |
| Zu- oder Abfahrt immer weglassen | Einstellmenü: Zufahrt / Abfahrt Seite = keine |
| Entfernte Zu- / Abfahrt zurückholen | LUmschalt + Entf |
| Buchten automatisch ins Fahrsilo setzen | Maus ins Silo (nahe der Einfahrt), dann Num9 |
| Maus an der ersten Bucht / in der Mitte | Num3 |
| Zu- oder Abfahrt an eine Hilfslinie anlegen | LStrg + Linksklick auf die Kurve, dann auf die Linie |
| Zu- oder Abfahrt auf die andere Seite | LAlt + Linksklick auf die Kurve |

### 2. Freie Kurve und 5. Bogen

| Was du machen willst | So geht's |
|---|---|
| Kurve größer / kleiner | LStrg + Mausrad |
| Mehr / weniger Punkte | LAlt + Mausrad |
| Richtung: vorwärts / umgedreht / beidseitig | LStrg + Num, (oder Num,) |
| Haupt- / Neben- / Rückfahrstrecke | LAlt + Num, |
| Bogen: Ecke und Größe wählen | Maus bewegen |

### 3. Hilfslinie

| Was du machen willst | So geht's |
|---|---|
| Hilfslinie setzen | Linksklick |
| Linie länger / kürzer | LStrg + Mausrad |
| Linie seitlich verschieben | LAlt + Mausrad |
| Parallel zu Linie, Silowand oder Gebäude | LStrg + Linksklick daran |
| Linie löschen / zurückholen | Entf / LUmschalt + Entf |
| Alle Hilfslinien löschen | LStrg + LAlt + L |

### 4. Gerade auf Hilfslinie

| Was du machen willst | So geht's |
|---|---|
| Start setzen | erster Linksklick nahe der Hilfslinie |
| Ende setzen und bauen | zweiter Linksklick |
| Abstand der Punkte | LAlt + Mausrad |
| Richtung: vorwärts / umgedreht / beidseitig | LStrg + Num, (oder Num,) |
| Haupt- / Neben- / Rückfahrstrecke | LAlt + Num, |
| Start verwerfen | Num0 |

### 6. Verzweigung und 7. Zuführung

| Was du machen willst | So geht's |
|---|---|
| Kurven größer / kleiner | LStrg + Mausrad |
| Mehr / weniger Punkte | LAlt + Mausrad |
| Einbahn / beidseitig | Num, |
| An einen AD-Punkt anschließen | Num0 |
| Abzweig an eine Hilfslinie anlegen | LStrg + Linksklick auf den Abzweig, dann auf die Linie |
| Einen Abzweig weglassen / zurückholen | LAlt + Linksklick auf die Seite |

### 9. Fahrzeug-Schablone

| Was du machen willst | So geht's |
|---|---|
| Modell auf das AD-Netz setzen | Maus in die Nähe einer Strecke |
| In die andere Richtung stellen | Num3 |
| Länge Zugfahrzeug | LStrg + Mausrad |
| Länge Anhänger / Auflieger (0 = keiner) | LAlt + Mausrad |
| Breite, Höhe, Kupplung | im Einstellungsfenster (LStrg + LAlt + B) |
| Modell stehen lassen (zum Vergleichen) | Linksklick |
| Stehen gelassene Modelle entfernen | Num0 |

Beispiele: Sattelzug 6 m + 13,6 m, Kupplung 1,5 m vor dem Heck, Breite 2,55 m. Traktor mit Anhänger 6 m + 10 m, Kupplung -1 (1 m hinter dem Heck). Das Modell ist bewusst grob: Kasten-Formen, der Anhänger folgt der Strecke ungefähr.

### 10. Feldrand

| Was du machen willst | So geht's |
|---|---|
| Feld erkennen | Linksklick aufs Feld, kurz warten |
| Feldrand bauen | nochmal Linksklick |
| Verwerfen | Num0 |
| Zu- / Abfahrt | LStrg + Linksklick auf den Start, dann auf das Ende: ein AD-Punkt der Straße, der gefundene Feldrand oder ein schon gebauter Feldrand. Die Reihenfolge ist die Fahrtrichtung |
| Nur Zu- / Abfahrten bauen (Feldrand gibt es schon) | ohne Feld zu erkennen: Zu- / Abfahrten setzen, dann Linksklick |
| Letzte Zu- / Abfahrt entfernen | LStrg + Num0 |
| Rand nach außen / innen verschieben | LAlt + Mausrad (+ = außen, - = innen). Jedes neue Drücken von LAlt ändert den Schritt: 1 m → 0,5 m → 0,1 m → 0,01 m |
| Kurvenradius: nur die Ecke bei der Maus (gelb markiert), sonst alle Ecken (Standard 10 m) | LStrg + Mausrad |
| Punkte: im Bogen bei der Maus, sonst Punktabstand auf den Geraden | LStrg + LUmschalt + Mausrad |
| Ecke wieder wie alle | Entf (Maus an der Ecke) |
| Richtung: vorwärts / umgedreht / beidseitig | LStrg + Num, (oder Num,) |
| Haupt- / Neben- / Rückfahrstrecke | LAlt + Num, |

Die Ecken werden mit dem eingestellten Kurvenradius abgerundet. Ist eine Kante dafür zu kurz, wird der Radius dort kleiner, das Werte-Fenster zeigt dann die engste Kurve. Im Einstellungsfenster: Versatz, Punktabstand, Kurvenradius, Raster (kleiner = genauer, aber langsamer, Standard 2 m) und die größte Fläche (Standard 100 ha), damit nicht eine ganze Wiese abgetastet wird. Felder, die nur durch einen Grasstreifen getrennt sind, bleiben getrennt. Zu- und Abfahrten sind weiche Kurven: an der Straße in deren Fahrtrichtung, am Feldrand entlang des Randes. Sie werden zusammen mit dem Feldrand gebaut.

## Hilfslinien

Hilfslinien helfen beim genauen Bauen. Nur du siehst sie, AutoDrive baut daraus nichts.

- Linie setzen: Bauart 3, Linksklick. Die Linie hat ein Lineal mit Metern.
- Parallel ausrichten: LStrg + Linksklick an eine andere Hilfslinie, eine Silowand oder eine Gebäudekante. Die neue Linie dreht sich parallel dazu.
- Abstand sehen: Solange die Linie parallel ist, zeigt eine gelbe Linie den Abstand.
- Seitlich verschieben: LAlt + Mausrad. Jedes neue Drücken von LAlt macht die Schritte kleiner: 1 m, 0,5 m, 0,1 m, 0,01 m.
- Löschen: Entf löscht die Linie bei der Maus, LUmschalt + Entf holt sie zurück, LStrg + LAlt + L löscht alle.
- Die Linien bleiben im Spielstand gespeichert. Die letzten zwei (orange und türkis) braucht der Bogen.

![Hilfslinie parallel zur Silowand](docs/images/guide_parallel_de.png)

## An Hilfslinien anlegen

Geht bei Rückfahr-Bucht (Zu- und Abfahrt), Verzweigung und Zuführung:

1. LStrg + Linksklick auf die Kurve oder den Abzweig.
2. LStrg + Linksklick auf die Hilfslinie.
3. Fertig: Die Kurve beginnt bzw. endet jetzt genau auf der Linie.

LStrg + Num0 hebt das wieder auf. Statt Linksklick geht auch eine Seitentaste der Maus.

## AutoDrive-Punkte bearbeiten

Bauart 8 (Auswählen / Verschieben), am besten in der Draufsicht:

| Was du machen willst | So geht's |
|---|---|
| Punkte auswählen | linke Maustaste halten und Kasten ziehen |
| Mehr Punkte dazu / Punkte abwählen | Kasten mit LUmschalt / mit LStrg |
| Einen Punkt auswählen | Linksklick auf den Punkt |
| Alle zusammenhängenden Punkte dazu | LStrg + A (höchstens so viele wie im Einstellungsfenster eingestellt, Standard 500) |
| Auswahl aufheben | Num0 |
| Auswahl verschieben | ausgewählten Punkt mit der linken Maustaste ziehen |
| Fein verschieben | Num8 / Num2 / Num4 / Num6 (mit LStrg 0,01 m) |
| Nur entlang / quer zur Hilfslinie schieben | Num3 |
| Auswahl gerade auf die Hilfslinie legen | Num7 (Num9: dazu gleichmäßig verteilen) |
| Richtung: vorwärts / umgedreht / beidseitig | LStrg + Num, (oder Num,) |
| Haupt- / Neben- / Rückfahrstrecke | LAlt + Num, |
| Punkte einer Kurve ändern | Kurve wählen, LAlt + Mausrad, dann Linksklick |
| Gerade zwischen zwei Punkten | 2 Punkte wählen, Num/, dann Linksklick |
| AD-Ziel setzen / umbenennen / löschen | 1 Punkt wählen, Num5 |
| Auswahl kopieren | LStrg + C, Linksklick fügt ein, Num0 = fertig |
| Auswahl löschen | Entf, dann nochmal Entf – **nicht rückgängig zu machen** |
| Rückgängig | LStrg + LAlt + Z |

Tipp: Bei einer langen Strecke reicht es, den ersten und den letzten Punkt zu wählen. AD-Ziele werden nicht mitkopiert.

## Hindernisse anzeigen

LStrg + H zeigt rund um die Maus (25 m), wo wirklich etwas im Weg ist. Rot markiert ist die unsichtbare Kollision von Bäumen, Masten, Gebäuden und Objekten, nicht das sichtbare Modell. Der Mod prüft das genauso wie AutoDrive beim Fahren.

- Rot gefüllte Flächen mit gelbem Rand: hier ist eine Kollision (von 0,3 m bis 4 m über dem Boden). Gezeichnet knapp über dem Boden und in 4 m Höhe, dazu ein roter Pfosten. Unter Baumkronen sieht man es am besten mit geneigter Kamera (Leertaste + Maus).
- Rote Linie über der Vorschau: an diesem Stück würde ein 3 m breites Fahrzeug anstoßen. Das Werte-Fenster zeigt, wie viele Stücke betroffen sind.
- Nochmal LStrg + H schaltet es aus.

## Draufsicht und AutoDrive bearbeiten

- Der Baukasten startet in der Draufsicht über dir bzw. deinem Fahrzeug.
- Kurzer Rechtsklick oder Num Enter: Bauen pausiert, du bearbeitest mit dem normalen AutoDrive-Editor. Num Enter bringt dich zurück.
- AutoDrive bearbeitet mit der Maus nur, wenn du in einem Fahrzeug sitzt, das AD-HUD an ist und der Editor auf „erweitert“ steht (Num/). Das Panel zeigt dir, was fehlt.

## Gut zu wissen

- Mehrspieler: Der Mod muss auf dem Server **und** bei allen Spielern in derselben Version sein. Rückgängig nimmt nur Strecken zurück, die du selbst gebaut hast.
- Neue Strecken werden nur dort mit dem AD-Netz verbunden, wo du Num0 benutzt. Den Rest verbindest du im AutoDrive-Editor.
- Rückfahr-Bucht: Dort, wo das Rückwärtsfahren beginnt, darf keine andere Strecke abzweigen.
- Deutsche Tastatur: Rückgängig geht mit LStrg + LAlt + Z oder Y.
- Ziffernblock: LUmschalt zusammen mit Ziffernblock-Tasten vermeiden. Bei eingeschaltetem NumLock macht Windows daraus andere Tasten (z. B. Num, → Entf). Darum nutzt der Mod dafür LStrg.
- Texte und Bilder gibt es auf Deutsch und Englisch.

## Unterstützen

Der Mod ist kostenlos. Wenn er dir Zeit spart und du etwas zurückgeben möchtest, freue ich mich über eine kleine Spende – ganz freiwillig.

[![Spenden mit PayPal](https://img.shields.io/badge/Spenden-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

## Fehler und Wünsche

Bitte als [Issue](../../issues) melden – am besten mit Screenshot und der `log.txt`.

## Lizenz

Alle Rechte vorbehalten. Kostenlos im Spiel nutzen, auch auf Servern, ist erlaubt. Woanders hochladen, verkaufen oder geänderte Versionen veröffentlichen nur mit meiner Erlaubnis. Bitte verlinke stattdessen auf diese Seite. Details: [LICENSE](LICENSE)

## Ersteller

Toneslin
