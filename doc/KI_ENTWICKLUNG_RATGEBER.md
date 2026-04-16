# Wie ich mit KI ein Computerspiel entwickelt habe
### Ein ehrlicher Erfahrungsbericht — für alle verständlich, nicht nur für Programmierer

---

Ich bin kein Berufsprogrammierer. Trotzdem habe ich in wenigen Wochen ein vollständiges 3D-Labyrinth-Spiel entwickelt — mit Monstern, Videos, Virtual-Reality-Unterstützung und prozedural generierten Levels. Das wäre ohne KI nicht möglich gewesen. Aber es war auch kein Selbstläufer. In diesem Dokument beschreibe ich ehrlich, welche Probleme aufgetaucht sind, wie sie gelöst wurden, und was ich dabei über die Arbeit mit KI gelernt habe.

---

## Inhaltsverzeichnis

1. Was ist das für ein Spiel?
2. Das Spiel ruckelte extrem — warum und was dagegen zu tun war
3. Videos im Spiel blieben schwarz oder liefen heimlich weiter
4. Videos sahen nach dem Umwandeln grauenhaft aus
5. Das Spiel fror beim Start einfach ein
6. Der Spieler fiel plötzlich durch den Boden
7. Der Spieler war in einem Raumabschnitt gefangen
8. Virtual Reality funktionierte nicht richtig
9. Kaputte Bilddateien haben alles verlangsamt
10. Wie weiß man überhaupt, warum etwas langsam ist?
11. Was ich über das Arbeiten mit KI gelernt habe

---

## 1. Was ist das für ein Spiel?

Das Spiel ist ein riesiges 3D-Labyrinth. Jedes Mal, wenn man es startet, sieht das Labyrinth komplett anders aus — es wird vom Computer jedes Mal neu zufällig generiert, so wie ein Würfelwurf. Das Labyrinth ist 30 mal 30 Felder groß, hat also 900 einzelne Räume. Darin gibt es Monster, die einen verfolgen, Fahrstühle, die zwischen Ebenen wechseln, und besondere Galerien, in denen auf großen Leinwänden Videos laufen. Am Ende sollte das alles auch mit einer VR-Brille (PlayStation VR2) spielbar sein.

Das klingt nach einem langen Projekt für ein großes Team. Es war ein Einzelpersonenprojekt, geführt mit KI als Assistent.

---

## 2. Das Spiel ruckelte extrem

### Was passiert ist

Das Spiel lief mit etwa 15 Bildern pro Sekunde — das ist so ruckelig, dass es kaum spielbar ist. Zum Vergleich: Flüssiges Spielen braucht mindestens 60 Bilder pro Sekunde. Interessanterweise war die Grafikkarte dabei kaum ausgelastet. Das bedeutete: Die Grafikkarte war nicht das Problem, irgendwas anderes war der Flaschenhals.

### Die Ursache erklärt ohne Fachbegriffe

Stell dir vor, du organisierst einen Umzug und musst 5.000 Kartons von Zimmer A nach Zimmer B bringen. Du könntest für jeden einzelnen Karton einen Freund losschicken, der ihn trägt — aber das würde bedeuten, dass du 5.000 separate Anweisungen gibst, 5.000 mal die Tür aufmachst, 5.000 mal wartest. Viel effizienter wäre es, alle Kartons zu sortieren und in einer LKW-Ladung rüberzubringen.

Genau das war das Problem mit dem Spiel. Das Labyrinth hat 900 Räume, jeder Raum hat Wände, Böden und Decken. Jedes dieser Einzelteile wurde dem Computer einzeln übergeben mit dem Auftrag „zeig das bitte an". Der Computer war damit beschäftigt, diese tausenden von Einzelaufträgen abzuarbeiten — und hatte keine Zeit mehr, das Spiel selbst zu berechnen.

### Wie es gelöst wurde

Die KI erklärte das Problem sofort, als man die Symptombeschreibung (wenige Bilder pro Sekunde, Grafikkarte kaum ausgelastet) eingab. Die Lösung war konzeptionell simpel: Statt tausende Einzelteile einzeln zu übergeben, sammelt man sie alle erst und schickt sie in einer einzigen großen Ladung an die Grafikkarte. Das ist genau wie der Umzug mit dem LKW statt mit 5.000 Einzelgängen.

Nach dieser Umstellung fiel die Zahl der Einzelaufträge an die Grafikkarte von über 8.000 auf unter 200. Das Spiel lief danach stabil mit 60 Bildern pro Sekunde.

### Was man daraus mitnehmen kann

Wenn ein Spiel langsam läuft, liegt es nicht immer an zu viel Grafik oder zu schönen Effekten. Manchmal liegt es daran, wie die Informationen organisiert werden — nicht daran, was angezeigt wird, sondern wie es übergeben wird. Die KI konnte aus der Fehlerbeschreibung sofort auf die richtige Ursache schließen, weil dieses Muster in der Spieleentwicklung sehr bekannt ist.

---

## 3. Videos im Spiel blieben schwarz oder liefen heimlich weiter

### Was passiert ist

Im Labyrinth gibt es Bereiche, in denen auf großen Bildschirmen Videos abgespielt werden. Die Idee war: Wenn der Spieler nah genug an einem Bildschirm ist und ihn anschaut, soll das Video starten. Geht der Spieler weg, soll es stoppen — damit nicht alle Videos gleichzeitig laufen und den Computer überlasten.

In der Praxis passierten zwei Dinge, die nicht zusammenpassen sollten: Die Videos blieben schwarz, egal wie nah man heranging. Und gleichzeitig stieg die Belastung des Computers mit der Zeit immer weiter an, obwohl man gar nichts sah.

### Die Ursachen

Es gab gleich drei verschiedene Fehler gleichzeitig, die sich gegenseitig überdeckten.

**Fehler eins** war ein klassischer Denkfehler im Regelwerk für die Videos. Die Regel, die eigentlich bestimmen sollte wann ein Video stoppt, war so formuliert, dass sie unter bestimmten Umständen nie ausgeführt werden konnte. Die Videos starteten irgendwann, und es gab dann keine Bedingung mehr, die sie wirklich stoppen konnte. Sie liefen einfach weiter — unsichtbar, ohne Ton, aber der Computer rechnete trotzdem dafür.

**Fehler zwei** war eine falsche Annahme darüber, was „pausieren" bedeutet. Es gibt einen Unterschied zwischen „das Bild einfrieren" und „die Berechnung im Hintergrund stoppen". Das Video sah aus wie pausiert, aber der Computer berechnete weiterhin jeden Frame im Hintergrund — so wie jemand, der ein Radio auf stumm dreht und sich wundert, warum der Akku trotzdem leer wird.

**Fehler drei** war Speicherverschwendung. Für jeden Video-Bildschirm hatte der Computer einen Puffer reserviert — einen unsichtbaren Ort, an dem das aktuelle Videobild zwischengespeichert wird. Dieser Puffer blieb auch dann in voller Größe belegt, wenn das Video gar nicht lief. Bei zehn Bildschirmen summiert sich das zu einer beträchtlichen Menge an unnötig belegtem Grafikspeicher.

### Wie es gelöst wurde

Die KI half dabei, alle drei Fehler nach und nach zu identifizieren. Der erste Fehler wurde gefunden, indem man das Regelwerk Schritt für Schritt mit der KI durchgegangen ist und gefragt hat: „Kann dieser Fall je eintreten?" — woraufhin klar wurde, dass er es nicht konnte.

Der zweite Fehler wurde gelöst, indem man nicht mehr „pausieren", sondern wirklich „stoppen" nutzt — zwei Befehle, die ähnlich klingen aber fundamental unterschiedlich funktionieren. Der dritte Fehler wurde behoben, indem der Speicherpuffer beim Stoppen auf ein absolutes Minimum geschrumpft wird und erst beim Start wieder aufgebläht wird.

### Was man daraus mitnehmen kann

Mehrere kleine Fehler, die gleichzeitig auftreten, sind schwerer zu finden als ein großer. Die KI ist dabei hilfreich, weil man ihr die Situation beschreiben kann und sie systematisch nach möglichen Ursachen sucht — ohne emotional investiert zu sein oder Annahmen darüber zu treffen, was „sicher schon richtig ist".

---

## 4. Videos sahen nach dem Umwandeln grauenhaft aus

### Was passiert ist

Das Spielprogramm, das ich benutze, kann nur ein bestimmtes Video-Format abspielen. Alle anderen Videos — zum Beispiel normale Handy-Videos oder YouTube-Downloads — müssen erst umgewandelt werden. Nach dieser Umwandlung sahen die Videos im Spiel aus wie ein kaputter Fernseher: Grüne Rechtecke, weiße Klötze, zerrissene Bilder. Besonders schlimm war es bei Videos mit viel Bewegung.

### Die Ursache

Das war kein Fehler des Spielprogramms. Es war ein Problem beim Umwandlungsprozess selbst.

Video-Komprimierung funktioniert so: Statt jedes Bild komplett zu speichern, speichert man nur die Unterschiede zum vorherigen Bild. Das spart enorm viel Speicherplatz. Um diese Unterschiede zu berechnen, schätzt der Algorithmus, wie sich Objekte von Bild zu Bild bewegt haben.

Bei bestimmten Videos — vor allem wenn die ursprüngliche Datei ein verstecktes Miniaturbild als extra Datenspur enthält (was viele Videos haben, ohne dass man es weiß) — macht diese Schätzung vollständig falsche Berechnungen. Das Ergebnis sind diese grünen und weißen Blöcke.

### Wie es gelöst wurde

Die KI kannte dieses Problem sofort. Die Lösung ist, dem Umwandlungsprogramm zu sagen: „Speichere jedes Bild komplett, keine Unterschiedsberechnung." Das bedeutet, die Datei wird größer — aber die Fehler verschwinden vollständig, weil es keine Bewegungsschätzung mehr gibt, die schiefgehen könnte.

Außerdem muss man dem Programm sagen, die versteckte Miniaturbildspur zu ignorieren — damit diese nicht versehentlich in die Berechnung einfließt. Mit diesen zwei Anpassungen sind die Videos seitdem immer perfekt.

### Was man daraus mitnehmen kann

Manchmal liegt das Problem nicht dort, wo man es vermutet. Der erste Gedanke war: „Das Spielprogramm hat einen Bug." Die KI hat sofort erkannt, dass das Spielprogramm gar nicht involviert war — das Problem entstand bereits beim Umwandeln. Gute Fehlerbeschreibung führt zur richtigen Diagnose.

---

## 5. Das Spiel fror beim Start komplett ein

### Was passiert ist

Nach einer größeren Überarbeitung des Codes startete das Spiel — und blieb dann einfach stehen. Kein Absturz, keine Fehlermeldung, nichts. Der Ladebildschirm erschien kurz, und dann passierte einfach gar nichts mehr. Minutenlang. Den Computer beenden und neu starten war die einzige Option.

Das ist eine der frustrierendsten Situationen: Ein Absturz mit einer Fehlermeldung ist einfach zu lösen — die Meldung sagt dir, wo das Problem ist. Aber ein stilles Einfrieren gibt dir keinen Hinweis.

### Die Diagnose

Die KI schlug eine clevere Methode vor: Während das Spiel läuft, schreibt es nach jedem wichtigen Schritt eine kleine Datei auf die Festplatte — wie Brotkrümel im Wald. Wenn das Spiel einfriert, schaut man nach, welche Datei als letztes geschrieben wurde. Die nächste Datei, die fehlt, markiert genau die Stelle, an der das Spiel zum Stillstand gekommen ist.

### Die Ursache

Auf diese Weise wurde schnell gefunden, wo das Problem lag: Das Spiel versuchte beim Start automatisch eine Navigationskarte zu berechnen — eine Art unsichtbarer Stadtplan, den Computergegner benutzen können, um sich im Labyrinth zu bewegen. Bei 900 Räumen und tausenden von Einzelteilen dauerte diese Berechnung so lange, dass das Spiel in dieser Zeit komplett blockiert war. Nicht abgestürzt — wartend. Und das Warten endete nicht.

### Wie es gelöst wurde

Die einfachste Lösung war die richtige: Diese automatische Navigationskarte komplett deaktivieren. Stattdessen wurde ein eigenes, viel einfacheres System entwickelt: Schon beim Generieren des Labyrinths merkt sich das Spiel für jede Position, in welche Richtung die nächste Halle liegt. Das reicht für Monster vollkommen aus, um sich sinnvoll zu bewegen — und es kostet fast keine Zeit.

### Was man daraus mitnehmen kann

Manchmal ist die Lösung das Weglassen einer Funktion, nicht deren Reparatur. Die automatische Navigationskarte klang nach einer guten eingebauten Funktion — aber für dieses spezifische Spiel war sie überdimensioniert und zu langsam. Eine einfachere eigene Lösung war besser. Die KI hat das sehr klar erklärt und geholfen, das einfachere System zu entwickeln.

---

## 6. Der Spieler fiel plötzlich durch den Boden

### Was passiert ist

Nach der großen Überarbeitung, bei der die Darstellung aller Wände und Böden auf das neue, schnellere System umgestellt wurde — der Spieler fiel einfach durch den Boden. Oder er lief durch Wände, als wären sie gar nicht da. Das Labyrinth sah perfekt aus, aber der Spieler konnte sich einfach hindurchbewegen.

### Die Ursache

In einem Computerspiel gibt es zwei völlig getrennte Systeme: das, was man sieht, und das, was der Computer als physisch vorhanden behandelt. Das ist wie ein Bühnenbild im Theater — die Säulen, die Wände, die Treppe sehen aus wie echtes Mauerwerk, aber eine Schauspielerin kann problemlos hindurchgehen, weil es nur bemalte Pappe ist.

Das neue, schnelle Darstellungssystem zeigt die Wände und Böden, hat aber keine physische Existenz. Es ist rein visuell. Beim Umbau auf dieses System wurde vergessen, die unsichtbare physikalische Seite — die tatsächliche Kollision, gegen die der Spieler läuft — separat beizubehalten.

### Wie es gelöst wurde

Die Kollision und die Darstellung wurden komplett getrennt behandelt. Die Darstellung läuft über das neue schnelle System. Die Kollision — also das, womit der Spieler tatsächlich interagiert — wird separat und unsichtbar aufgebaut. Der Spieler sieht die Wand und läuft auch wirklich gegen sie. Beides funktioniert unabhängig voneinander.

### Was man daraus mitnehmen kann

Bei größeren Umbauten ist es wichtig, alle Auswirkungen zu bedenken — nicht nur das, was man gerade anfasst. Die KI hat dabei geholfen, die Checkliste der betroffenen Systeme durchzugehen: Was ändert sich noch, wenn wir das ändern?

---

## 7. Der Spieler war in einem Raumabschnitt gefangen

### Was passiert ist

Im Labyrinth gibt es besondere lange Korridore, in denen die Video-Bildschirme stehen. Diese Korridore werden zufällig generiert und mitten ins Labyrinth eingefügt. Nach der Implementierung berichtete das Testen: Man betrat den Korridor — und kam nicht mehr heraus. Alle vier Seiten hatten Wände, überall.

### Die Ursache

Beim Generieren dieser Korridore wurde korrekt bestimmt, wo sie anfangen und wo sie enden. Dann wurden alle Wände gesetzt, um den Korridor zu umschließen. Aber: Es wurde vergessen, die Zugänge aufzubrechen. Der Korridor war ein perfekt verschlossener Kasten ohne Türen.

Es ist wie jemanden zu bitten, einen Raum zu bauen — er baut vier Wände, Boden, Decke, alles korrekt. Aber er vergisst die Tür. Der Raum ist perfekt, aber nicht zu betreten. Oder in diesem Fall: nicht zu verlassen.

### Wie es gelöst wurde

Nach dem Setzen aller Wände wurde ein expliziter Schritt hinzugefügt: An jedem Ende des Korridors wird eine Wand entfernt — sowohl die Wand des Korridors selbst als auch die Wand des benachbarten Raumes. So entsteht ein echter Durchgang.

### Was man daraus mitnehmen kann

Beim Entwickeln von Systemen, die automatisch Strukturen erzeugen, muss man immer auch an die Verbindungen zwischen diesen Strukturen denken. Die KI hat geholfen, das Problem schnell zu erkennen, weil die Fehlerbeschreibung präzise war: „Der Spieler kommt rein, aber nicht mehr raus."

---

## 8. Virtual Reality funktionierte nicht richtig

### Was passiert ist

Das Labyrinth sollte auch mit einer VR-Brille spielbar sein — einer PlayStation VR2, die man an einen PC anschließen kann. Die Brille erkannte das Spiel. Man tauchte ins Labyrinth ein. Aber es war seltsam: Der Spieler schwebte auf der falschen Höhe — manchmal mitten in der Luft, manchmal halb im Boden. Der FPS-Anzeiger und andere Informationen, die auf dem Bildschirm erscheinen sollten, waren komplett verschwunden. Und wenn man den Kopf drehte, bewegte sich die Welt manchmal doppelt so schnell wie erwartet — was schnell unangenehm wird.

### Die Ursachen

**Höhenproblem:** Eine VR-Brille muss wissen, wo in der Spielwelt sie sich befindet. Das Spiel benötigt einen speziellen Ankerpunkt dafür. Ohne diesen Ankerpunkt rät die Brille — und rät falsch.

**Verschwundene Anzeigen:** Anzeigen wie der FPS-Counter werden normalerweise wie eine Folie über das Spielbild gelegt — man sieht sie immer, egal was im Spiel passiert. In VR gibt es diese Folie nicht. Beide Augen der Brille sehen die 3D-Welt direkt, ohne Overlay. Die Anzeigen renderten zwar, aber auf dem falschen Display, das man in VR nicht sehen kann.

**Doppelte Drehung:** Die VR-Brille dreht die Kamera mit, wenn man den Kopf dreht. Gleichzeitig war noch der alte Code aktiv, der die Kamera auch bei Mausbewegung dreht. Beide Systeme arbeiteten gleichzeitig — das Ergebnis war, dass jede Kopfbewegung doppelt so stark wirkte, was schnell zu Schwindelgefühl führt.

### Wie es gelöst wurde

**Höhe:** Ein Ankerpunkt wurde korrekt eingerichtet, der der Brille sagt, wo in der Spielwelt sie sich befindet. Die Höhe wurde angepasst, sodass die Augenhöhe des Spielers der realen Augenhöhe entspricht.

**Anzeigen:** Statt einer 2D-Folie über dem Bild wurde die FPS-Anzeige direkt in die 3D-Welt gebaut — als kleines Schild, das 60 Zentimeter vor dem Auge des Spielers in der Luft schwebt. Es bewegt sich mit dem Kopf mit und ist immer sichtbar, egal wohin man schaut.

**Doppelte Drehung:** Der Code, der die Kamera auf- und abwärts bewegt, wurde im VR-Modus einfach deaktiviert. Die Brille macht das bereits von allein — man braucht es nicht doppelt.

### Was man daraus mitnehmen kann

VR ist eine andere Art zu spielen und braucht teilweise komplett andere Lösungen als normale Bildschirmspiele. Was auf dem Monitor selbstverständlich funktioniert, kann in VR falsch oder unangenehm sein. Die KI kannte die typischen VR-Fehler sofort, weil das bekannte Probleme sind, die viele Entwickler vor uns hatten.

---

## 9. Kaputte Bilddateien haben alles verlangsamt

### Was passiert ist

Das Labyrinth hat eine Galerie, in der Fotos aus echten Urlauben an den Wänden hängen. Die Fotos wurden von einer Kamera kopiert und ins Spiel eingebunden. Beim Start erschien das Spiel plötzlich sehr träge und die Fehlermeldungen im Hintergrund häuften sich massiv — hunderte pro Sekunde. Das machte es unmöglich, echte Probleme von diesem Rauschen zu unterscheiden.

### Die Ursache

Einige der Fotos waren subtil kaputt — entweder durch einen Fehler beim Kopieren oder weil das Spielprogramm bestimmte Kamera-Formate nicht vollständig versteht. Außerdem enthält jeder importierte Dateiordner automatisch unsichtbare Begleitdateien, die das Spielprogramm für sich selbst anlegt. Diese Begleitdateien wurden versehentlich auch als Fotos behandelt — was natürlich scheiterte.

Das Spiel versuchte darum, jede kaputte Datei zu laden, scheiterte dabei, meldete den Fehler, wartete kurz, und machte dann mit dem nächsten weiter. Dieser Prozess hunderte Male pro Sekunde hat das Spiel spürbar verlangsamt.

### Wie es gelöst wurde

Das Ladeverhalten wurde defensiver gemacht: Bevor das Spiel eine Datei als Bild behandelt, prüft es zuerst, ob sie überhaupt ein Bild sein kann, und ob das Laden erfolgreich war. Wenn nicht, wird die Datei einfach stillschweigend übersprungen — ohne Fehlermeldung, ohne Lautstärke, ohne Verlangsamung. Das Spiel funktioniert dann mit den Bildern, die funktionieren, und ignoriert den Rest.

### Was man daraus mitnehmen kann

Software muss mit dem Unerwarteten umgehen können. Nicht jede Datei, die wie ein Bild aussieht, ist wirklich eines. Robuste Software geht davon aus, dass externe Daten fehlerhaft sein könnten, und behandelt Fehler still statt laut.

---

## 10. Wie weiß man überhaupt, warum etwas langsam ist?

### Das Problem ohne Messung

„Das Spiel läuft langsam" ist eine Beobachtung, keine Diagnose. Es ist wie zu einem Arzt zu gehen und zu sagen: „Mir geht's nicht gut." Ohne mehr Information kann niemand helfen. Welche Bilder pro Sekunde? Wo speziell — überall oder nur in bestimmten Bereichen? Seit wann? Verbessert es sich, wenn man weniger Licht anmacht?

### Was eingebaut wurde

Direkt im laufenden Spiel erscheint eine kleine Anzeige in einer Ecke des Bildschirms. Sie zeigt in Echtzeit: wie viele Bilder pro Sekunde gerade berechnet werden, wie viel Arbeit die Grafikkarte gerade hat, wie viele Gegner gerade aktiv sind, und wie viele Videos gerade laufen. Die Farbe der Anzeige wechselt je nach Leistung — grün wenn alles gut ist, gelb wenn es anfängt zu ruckeln, rot wenn es ein Problem gibt.

Zusätzlich schreibt das Spiel im Hintergrund permanent eine Protokolldatei — wie ein Tagebuch der Leistung. Alle paar Sekunden notiert es: Uhrzeit, Bilder pro Sekunde, Position des Spielers im Labyrinth, Anzahl aktiver Effekte. Diese Datei kann man danach in einem Tabellenkalkulationsprogramm öffnen und sehen, in welchem Bereich des Labyrinths die Leistung eingebrochen ist.

### Was das gebracht hat

Mit dieser Protokolldatei konnte man sehen, dass das Spiel in Video-Galerien generell etwas langsamer wurde. Das führte direkt zur Lösung, dass Videos wirklich gestoppt werden müssen, wenn man sie nicht sieht — nicht nur der Bildschirm eingefroren, sondern die gesamte Berechnung im Hintergrund.

### Was man daraus mitnehmen kann

Messen ist wichtiger als raten. Wenn man weiß, wo das Problem ist, ist die Lösung oft offensichtlich. Ohne diese Information tappt man im Dunkeln und verbessert vielleicht die falschen Dinge.

---

## 11. Was ich über das Arbeiten mit KI gelernt habe

### KI ist kein Zauberer

Die KI baut nicht von alleine ein Spiel. Sie schreibt keinen Code ohne klare Anweisungen, sie erfindet keine Game-Design-Ideen, und sie kann das Spiel nicht spielen, um es zu testen. Was sie sehr gut kann: erklären, vorschlagen, bekannte Probleme erkennen, und schnell Lösungen ausformulieren — wenn man ihr sagt, was das Problem ist.

### Die Qualität der Frage bestimmt die Qualität der Antwort

Das ist der wichtigste Satz dieses Dokuments. Wer sagt „Das Spiel ist langsam", bekommt allgemeine Tipps. Wer sagt „Das Spiel hat 15 Bilder pro Sekunde, die Grafikkarte ist zu 20% ausgelastet, es gibt 8000 Einzelaufträge an sie, und das Problem begann nach dem Hinzufügen der 900 Zellen" — der bekommt eine präzise, umsetzbare Antwort.

Die wichtigste Fähigkeit beim Arbeiten mit KI ist nicht das Programmieren. Es ist das **genaue Beschreiben von Problemen**.

### KI hat kein schlechtes Gewissen beim Falschliegen

Das bedeutet: KI kann sehr selbstsicher klingende Antworten geben, die trotzdem falsch sind. Sie merkt es nicht, schämt sich nicht, und warnt meistens nicht. Man muss das Ergebnis immer ausprobieren und nicht blind vertrauen.

### Die besten Momente mit KI

Die KI war besonders wertvoll bei:
- **Unbekannten Fehlern erklären** — wenn etwas passierte, das man noch nie gesehen hatte, konnte man es beschreiben und bekam sofort Hypothesen.
- **Bekannte Probleme der Branche** — viele Probleme (wie das Ruckeln durch zu viele Aufträge an die Grafikkarte, oder die Video-Dekodierungs-Falle) sind in der Spieleentwicklung wohlbekannt. Die KI kennt diese Muster.
- **Komplexe technische Themen vereinfachen** — wenn etwas unklar war, konnte man fragen „Erkläre das nochmal, als würdest du es einem Zehnjährigen erklären" und bekam tatsächlich eine einfachere Version.

### Die Grenzen der KI

- **Was sich gut anfühlt**, kann nur ein Mensch beurteilen, der das Spiel wirklich spielt.
- **Kreative Entscheidungen** — welche Mechanik Spaß macht, welche Farbe besser passt, wie die Atmosphäre sein soll — das wird von der KI ausprobieren, aber nicht wirklich gespürt.
- **Das finale Urteil** liegt immer beim Menschen. Die KI ist ein Werkzeug, kein Entscheider.

---

## Fazit

In wenigen Wochen, mit KI als Assistenten, ist ein 3D-Labyrinth-Spiel entstanden, das in VR spielbar ist, Videos in Echtzeit abspielt, zufällig generierte Level hat, und stabil mit 60 Bildern pro Sekunde läuft.

Ohne KI wäre das nicht möglich gewesen. Aber ohne die Bereitschaft, Probleme genau zu beschreiben, ohne das Verständnis dafür was man will, und ohne das Testen und Hinterfragen der Antworten — wäre die KI nutzlos gewesen.

KI-gestützte Entwicklung ist kein Autopilot. Es ist eine Partnerschaft. Man selbst ist der Pilot — die KI ist das beste Navigationssystem, das es je gab.

---

*Dieser Bericht basiert auf einem echten Entwicklungsprojekt im April 2026.*
