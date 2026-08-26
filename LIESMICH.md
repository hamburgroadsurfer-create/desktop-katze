# Desktop-Katzen 🐈‍⬛ 🐈

**Minka** (zart lavendel-weiß, mit rosa Schleife am Ohr) und ihre Freundin **Luna**
(dunkles Schiefergrau mit rotem Halsband und Glöckchen) leben am
unteren Bildschirmrand. Sie laufen herum, putzen
sich, gähnen, schlafen, spielen mit einem Wollknäuel, beobachten Schmetterlinge, jagen
die Maus — **und sie beschäftigen sich miteinander.** Reines PowerShell + WPF, keine
Installation, keine Abhängigkeiten, kein Internet.

## Starten / Beenden

| Was | Wie |
|---|---|
| Starten | Doppelklick auf **Katze starten.vbs** (oder Verknüpfung *Desktop-Katze* auf dem Desktop) |
| Beenden | Rechtsklick **auf eine Katze** → *Katzen beenden*, Tray-Icon → *Beenden*, oder **Katze stoppen.cmd** |

Beide Katzen laufen in einem Prozess (~250 MB, ~1 % CPU). Luna kannst du jederzeit
wegschicken und wieder holen: Tray-Icon oder Rechtsklick → *Freundin wegschicken / holen*.
Ohne sie starten: `katze.ps1 -OhneFreundin`.

## Was die beiden miteinander machen

Alle 1–2 Minuten fängt eine Begegnung an — der Ablauf:

1. **Hingehen** — beide laufen auf einen Treffpunkt in der Mitte zwischen ihnen zu.
2. **Begrüßen** — sie stehen sich gegenüber, Hals vorgestreckt, Ohren nach vorn,
   Schwänze hoch, Näschen aneinander. Dabei steigen Herzchen auf.
3. Danach eines von vier Dingen:
   * **Fangen spielen** — eine flüchtet, die andere jagt sie quer über den Bildschirm;
     wer erwischt wird, tauscht die Rolle (bis zu fünf Mal)
   * **Zusammensitzen**, wobei eine die andere putzt
   * **Aneinander schmiegen** — sie drücken sich langsam aneinander, Herzchen steigen auf
   * **Gemeinsames Nickerchen** — beide legen sich Nase an Nase hin und schlafen ein
     (20–45 s), danach schüttelt sich die eine und die andere gähnt

Beim Herumlaufen weichen sie einander aus, statt sich zu überlappen. Wenn du eine
hochhebst, streichelst oder die Maus-Jagd einschaltest, bricht die Begegnung ab und
wird später neu angefangen. Sofort auslösen: Tray-Icon → *Jetzt begrüßen*.

## Mit ihnen spielen

| Aktion | Ergebnis |
|---|---|
| Klick auf eine Katze | Streicheln — sie setzt sich, Augen zu, Herzchen |
| Doppelklick | Zoomies — sie flitzt wie verrückt hin und her |
| Ziehen | Sie hängt zappelnd am Zeiger; loslassen → sie fällt und landet federnd |
| **Aus großer Höhe loslassen** | Ein rosa **Fallschirm** öffnet sich und sie schwebt sanft pendelnd zu Boden |
| Rechtsklick auf eine Katze | Menü **für genau diese Katze**: Maus jagen · Schlafen · Zoomies · Fell (5 Farben) · Freundin holen/wegschicken · Babykatzen · Beenden |
| Tray-Icon (Doppelklick) | Wollknäuel werfen |
| Tray-Icon (Rechtsklick) | Freundin · Babykatzen · Maus jagen (beide) · Wollknäuel · Schmetterling · Jetzt begrüßen · Pause · Monitor wechseln · Größe · Beenden |

**Babykatzen:** Über das Tray- oder Rechtsklick-Menü kommen **Krümel und Fussel** dazu —
zwei winzige Kätzchen mit noch größeren Köpfen und zufälligem Fell. Sie tun vor allem
eines: **die Großen nerven.** Sie rennen zu einer hin und patschen nach ihr, bis die
einen Katzenbuckel macht, genervt wegrennt, sich schüttelt oder Protest maunzt — auch
aus dem Schlaf werden die Großen so geweckt. Dazwischen: Zoomies, Anschleichen,
Wollknäuel-Klauen und kurze Nickerchen. Streicheln, Werfen und Ziehen (samt Fallschirm)
funktioniert bei ihnen genauso. Wegschicken jederzeit über dasselbe Menü.

**Wollknäuel:** Taucht von allein auf (erstmals nach ~45 s, dann alle 2–5 min) oder per
Menü. Die Katze, die näher dran ist, pirscht sich heran und schlägt mit der Pfote danach;
das Knäuel rollt mit Drehung und Reibung weg und prallt an den Bildschirmrändern ab.

**Schmetterling:** Flattert in Wellenlinien über ihnen und bleibt in ihrer Reichweite.
Sie setzen sich hin, verfolgen ihn mit dem Kopf und springen gelegentlich danach — dann
flieht er kurz nach oben.

**Maus jagen:** Sie rennen dem Mauszeiger nach, schlagen mit der Pfote danach und springen
hoch, wenn er über ihnen ist. Auf einem anderen Monitor rennen sie zum Rand und springen
hinüber.

## Was jede von allein macht

Laufen · Rennen · Sitzen · Sich putzen (erst die Pfote ablecken, dann damit über Ohr und
Wange wischen) · Sich hinterm Ohr kratzen · Auf dem Rücken wälzen · Gähnen (Maul weit auf) ·
Maunzen (mit „miau") · Als Fellnase-Loaf schlafen · Zusammengerollt schlafen (mit z-z-z) ·
Strecken · **Katzenbuckel machen** · **Sich schütteln** (nach dem Aufwachen und nach dem
Hochheben) · **Am Boden schnuppern** und dabei im Schneckentempo weiterschleichen ·
**Mit den Vorderpfoten scharren** (mit aufstiebendem Staub) · **Männchen machen und
betteln** · **Mit der Pfote winken** · Anschleichen und Hechtsprung · Am Bildschirmrand
aufrichten und kratzen · Blinzeln · Ohrenzucken · Schwanzwedeln · Atmen.

Im Sitzen und im Leerlauf **verfolgt ihr Kopf deinen Mauszeiger** — und dabei **blinzelt
sie dich manchmal langsam an**, was bei Katzen Zuneigung bedeutet. Ist der Mauszeiger nah,
**winkt oder bettelt** sie dich gezielt an. Die Zustände gehen sinnvoll ineinander über
(Schlafen → Schütteln → Gähnen → Strecken → Buckel → Losspazieren; Scharren → Schnuppern →
Weiterlaufen). Beide haben eigene Zeitgeber, atmen also nicht im Gleichschritt.

## Rücksichtnahme

* **Vollbild = weg.** Läuft auf dem Monitor, auf dem eine Katze sitzt, eine Vollbild-App
  (Spiel, Video, Präsentation), verstecken sich beide automatisch und die Animation setzt
  komplett aus — dann kosten sie praktisch keine CPU. Danach kommen sie von selbst zurück.
  Läuft das Vollbild auf einem *anderen* Monitor, bleiben sie sichtbar.
* **Wenn du weg bist, dösen sie.** Nach 5 Minuten ohne Maus- oder Tastatureingabe legen
  sie sich schlafen und es taucht kein neues Spielzeug mehr auf. Sobald du zurück bist,
  schütteln sie sich und machen weiter.
* **Klickdurchlässig:** Jedes Katzenfenster fängt Mausklicks *nur* dort ab, wo tatsächlich
  Katze gezeichnet ist (pixelgenauer WPF-Hit-Test + `WS_EX_TRANSPARENT`).
* Kein Alt-Tab-Eintrag, keine Taskleiste, klaut niemals den Fokus.
* Sie starten auf dem Monitor, an dem du gerade arbeitest.

## Technisch

* Jede Katze, das Wollknäuel und der Schmetterling haben ein eigenes transparentes
  Fenster — deshalb können sie sich frei über den ganzen Bildschirm bewegen.
* **DPI- und multimonitorfest im Betrieb:** Eine Wartungsroutine prüft jede Sekunde die
  Bildschirmskalierung neu (wird sie nur beim Start gelesen, sitzen die Katzen nach einem
  Monitorwechsel an der falschen Stelle) und holt eine Katze zurück, die durch Abdocken
  außerhalb aller Monitore gelandet ist.
* **Fehler sind auffindbar:** Die Animationsschleife läuft in `try/catch`. Ein Fehler
  darin würde sonst lautlos verschluckt — die Katzen blieben einfach stehen, ohne Spur.
  Stattdessen landet er mit Zeitstempel und Zeilennummer in
  `%TEMP%\desktop-katze-fehler.log` (maximal 8 Einträge, damit nichts zumüllt), und die
  Katzen laufen weiter. Ist die Datei nicht da, ist auch nichts passiert.

## Optionen

```powershell
powershell -STA -File katze.ps1 -Fur grau -Size 1.4 -OhneFreundin
```

* `-Fur` — Fell von Minka: `weiss` (Standard, lavendel-weiß), `orange`, `grau`, `schwarz`, `siam`
* `-Size` — 0.6 klein … 1.6 riesig (Standard 0.8; Luna ist immer ~6 % kleiner)
* `-OhneFreundin` — nur Minka
* `-MitBabykatzen` — Krümel und Fussel sind von Anfang an dabei
* `-Pose sit` — hält eine Pose fest (zum Ansehen)
* `-Sheet C:\pfad` — rendert alle 27 Posen als PNG (Entwicklungshilfe)
* `-Fast` — staffelt zum Testen: Begrüßung nach 4 s, Knäuel nach 28 s, Falter nach 48 s

## Wie das gebaut ist

Jede Katze ist ein Objekt (`$c`) mit eigenem Fenster, eigenem *Rig* aus WPF-Vektorformen
und eigener Zustandsmaschine; `$G` hält alles Gemeinsame. Im Rig hängen Rumpf, Kopf, vier
einzeln steuerbare Beine, Ohren, Augen, Maul und Schwanz an eigenen Transformationen. Die
Beine drehen sich mit dem Rumpf mit, haben aber zusätzlich eigene Hüftwinkel und Längen —
deshalb funktioniert der aufrechte Sitz genauso wie das Kratzen mit der Hinterpfote.

**Das Aussehen** ist ein flacher Sticker-Stil: eine einzige Pastellfarbe, keine Konturen,
Streifen oder Verläufe. Weil Kopf und Rumpf dieselbe flache Farbe haben, verschmelzen sie
zu einer weichen Silhouette. Dazu Punktaugen, ein kleines ω-Mäulchen, zarte Wangenröte,
kurze runde Stummelbeine (die hinteren einen Ton dunkler), ein dicker runder Schwanz und
kleine weiche Öhrchen (Dreiecke mit dicker runder Kontur in Fellfarbe). Das **Gesicht ist
spiegelsymmetrisch** um eine Mittelachse gebaut (`Mirror-Pts` spiegelt Ohren, Augenlider,
Maul und Wangen) — der Rumpf bleibt im Profil, das Gesicht schaut nach vorn. Deshalb wirkt
es nicht schief und bleibt beim Umdrehen der Katze gleich.

Jeder Zustand ist eine **Pose** aus 21 Zahlen (Winkel, Versätze, Streckung, Maulöffnung).
Zwischen Posen wird weich überblendet, obendrauf kommen Schwingungen (Schrittzyklus, Atmen,
Schwanzwedeln, Pfotenschlag). Der Schwanz ist eine dicke, rund gestrichelte Bézier-Kurve.
Fürs Rückenwälzen wird der
Rumpf um seine eigene Mitte gekippt, damit der Bauch nach oben zeigt.

Das Miteinander steuert ein kleiner Koordinator (`Update-Social`) mit den Zuständen
`none → meet → greet → tag | snuggle`. Während einer Begegnung sind die Katzen *gesperrt*,
damit ihre eigene Zufallslogik nicht dazwischenfunkt.

### Fallen, über die ich gestolpert bin

* `R` ist in PowerShell ein Alias für `Invoke-History` — Aliase gewinnen gegen eigene
  Funktionen. Die Zufallsfunktion heißt deshalb `Rnd`.
* `$env` als Variablenname liefert **innerhalb einer Funktion** `$null` (Kollision mit dem
  `env:`-Provider), am Skriptrand aber den erwarteten Wert. Das hat das Gähnen lahmgelegt.
* `if` als Ausdruck funktioniert in PowerShell 5.1 nicht innerhalb eines Hashtable-Literals.
* `Get-CimInstance Win32_Process | Where CommandLine -like '*katze.ps1*'` findet auch den
  eigenen Abfrage-Prozess, weil dessen Kommandozeile das Suchmuster enthält.
* Ereignis-Handler pro Katze brauchen `{ ... }.GetNewClosure()`, damit sie ihr eigenes
  `$c` behalten — `$this` ist dafür zu unzuverlässig. `GetNewClosure` macht eine
  Wertkopie des Gültigkeitsbereichs, funktioniert also auch in Schleifen korrekt.
* `PrintWindow` liefert für durchsichtige Bereiche Schwarz. Montiert man zwei
  Katzenfenster in ein Bild, überdeckt das zweite das erste — ein Artefakt der Aufnahme,
  nicht der Darstellung.
