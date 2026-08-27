# ============================================================================
#  Desktop-Katzen  -  Minka (weiss) und ihre Freundin Luna (schwarz)
#  Start:  Katze starten.vbs        Stop:  Katze stoppen.cmd  oder Tray-Icon
#
#  Aufbau: jede Katze ist ein Objekt ($c) mit eigenem transparenten Fenster,
#  eigenem Rig aus WPF-Formen und eigener Zustandsmaschine. $G haelt alles
#  Gemeinsame (Bildschirm-Skalierung, Spielzeug, Sozialverhalten).
# ============================================================================
param(
    [double]$Size = 0.8,
    [ValidateSet('orange','grau','schwarz','weiss','siam')]
    [string]$Fur = 'weiss',
    [switch]$OhneFreundin,
    # Debug-Hilfen: -Pose haelt eine Pose fest, -Sheet rendert alle Posen als PNG,
    # -Fast laesst Wollknaeuel, Schmetterling und Begegnungen sofort passieren
    [string]$Pose = '',
    [string]$Sheet = '',
    [switch]$Fast,
    [switch]$MitBabykatzen
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase,
                       System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class CatNative {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
    [DllImport("kernel32.dll")] public static extern uint GetTickCount();
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }

    // Sekunden seit der letzten Maus- oder Tastatureingabe
    public static double IdleSeconds() {
        LASTINPUTINFO li = new LASTINPUTINFO();
        li.cbSize = (uint)Marshal.SizeOf(li);
        if (!GetLastInputInfo(ref li)) return 0;
        return (GetTickCount() - li.dwTime) / 1000.0;
    }

    // Deckt das Vordergrundfenster einen ganzen Monitor ab? (Spiel, Video, Praesentation)
    // Der Desktop selbst und die Taskleiste zaehlen nicht.
    public static bool ForegroundIsFullscreen(int mLeft, int mTop, int mRight, int mBottom) {
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return false;
        StringBuilder cn = new StringBuilder(64);
        GetClassName(h, cn, 64);
        string k = cn.ToString();
        if (k == "Progman" || k == "WorkerW" || k == "Shell_TrayWnd" || k == "Windows.UI.Core.CoreWindow") return false;
        RECT r;
        if (!GetWindowRect(h, out r)) return false;
        return (r.Left <= mLeft && r.Top <= mTop && r.Right >= mRight && r.Bottom >= mBottom);
    }
}
'@

# Silhouetten-Mathematik in C#: Anker transformieren und per Catmull-Rom zu
# Bezier-Punkten verbinden. In PowerShell waeren das ~1000 Anweisungen pro
# Frame und Katze (~35 % eines Kerns); hier ist es ein Aufruf.
# Kopf: Skalierung um (128,128), Drehung um (112,142) - identisch zu $headG.
Add-Type -ReferencedAssemblies @([System.Windows.Point].Assembly.Location, [System.Windows.Media.PointCollection].Assembly.Location) -TypeDefinition @'
using System;
using System.Windows;
using System.Windows.Media;
public static class CatSil {
    public static Point Compute(double[] X, double[] Y, int[] G, double[] S, int[] E, double[] W, int n,
        double bcx, double ground, double belly, double earbx, double earby,
        double bsx, double bsy, double brot, double bdx, double bdy,
        double hrot, double hdx, double hdy, double hk, double ear,
        double pFNx, double pFNy, double pBNx, double pBNy, PointCollection pts) {
        double br = brot * 0.0174533, cb = Math.Cos(br), sb = Math.Sin(br);
        double hr = hrot * 0.0174533, hc = Math.Cos(hr), hs = Math.Sin(hr);
        double er = ear * 0.0174533;
        double hx = bdx + hdx, hy = bdy + hdy;
        double fF = Math.Max(0.0, Math.Min(1.0, 1 + pFNy / 17.0));
        double fB = Math.Max(0.0, Math.Min(1.0, 1 + pBNy / 17.0));
        double[] px = new double[n], py = new double[n];
        for (int i = 0; i < n; i++) {
            double x = X[i], y = Y[i]; int g = G[i];
            if (g == 1) {
                int e = E[i];
                if (e != 0) {
                    double bx = 128 + e * earbx, by = earby;
                    double ca = Math.Cos(er * e), sa = Math.Sin(er * e);
                    double dx0 = x - bx, dy0 = y - by;
                    x = bx + dx0 * ca - dy0 * sa; y = by + dx0 * sa + dy0 * ca;
                }
                x = 128 + (x - 128) * hk; y = 128 + (y - 128) * hk;
                double dx = x - 112, dy = y - 142;
                x = 112 + dx * hc - dy * hs + hx;
                y = 142 + dx * hs + dy * hc + hy;
            } else {
                if (g == 3)      { x += pFNx; y = belly + (y - belly) * fF; }
                else if (g == 2) { x += pBNx; y = belly + (y - belly) * fB; }
                double dx = (x - bcx) * bsx, dy = (y - ground) * bsy;
                x = bcx + dx * cb - dy * sb + bdx;
                y = ground + dx * sb + dy * cb + bdy;
                double w = W[i];
                if (w > 0) {
                    double kx = 128 + (X[i] - 128) * hk, ky = 128 + (Y[i] - 128) * hk;
                    double ddx = kx - 112, ddy = ky - 142;
                    kx = 112 + ddx * hc - ddy * hs + hx;
                    ky = 142 + ddx * hs + ddy * hc + hy;
                    x = x * (1 - w) + kx * w; y = y * (1 - w) + ky * w;
                }
            }
            px[i] = x; py[i] = y;
        }
        for (int i = 0; i < n; i++) {
            int i0 = (i + n - 1) % n, i1 = (i + 1) % n, i2 = (i + 2) % n;
            double s1 = S[i], s2 = S[i1];
            pts[3 * i]     = new Point(px[i]  + (px[i1] - px[i0]) * s1, py[i]  + (py[i1] - py[i0]) * s1);
            pts[3 * i + 1] = new Point(px[i1] - (px[i2] - px[i])  * s2, py[i1] - (py[i2] - py[i])  * s2);
            pts[3 * i + 2] = new Point(px[i1], py[i1]);
        }
        return new Point(px[0], py[0]);
    }
}
'@

# --- Leinwand-Geometrie (Entwurfskoordinaten, Katze schaut nach rechts) ------
$CW = 190.0      # Breite
$CH = 190.0      # Hoehe (oberer Bereich = Platz fuer Herzchen / Z-Z-Z)
$GROUND = 182.0  # Bodenlinie
$CAT_CX = 90.0   # optische Mitte der Katze
$BCX = 83.0      # Koerpermittelpunkt (Drehzentrum)
$BCY = 142.0
$NOSE_DX = 60.0  # Nase liegt so weit vor der Fenstermitte (fuers Naschen-Beruehren)
$PAD = 14.0      # Rand um die Katze im Fenster, damit der weiche Schatten nicht an der Fensterkante abgeschnitten wird

$GWL_EXSTYLE = -20
$WS_EX_TRANSPARENT = 0x20
$WS_EX_TOOLWINDOW = 0x80
$WS_EX_NOACTIVATE = 0x8000000

function Rnd($a, $b) { $a + (Get-Random -Minimum 0.0 -Maximum 1.0) * ($b - $a) }

# ============================================================================
#  Gemeinsamer Zustand
# ============================================================================
$G = @{
    sx = 1.0; sy = 1.0            # DPI-Skalierung (physische Pixel je DIP)
    last = 0.0; paused = $false
    cats = New-Object System.Collections.ArrayList
    kits = New-Object System.Collections.ArrayList   # Babykatzen (auf Bedarf)
    toy = $null; fly = $null      # Wollknaeuel, Schmetterling
    toyT = 45.0; flyT = 85.0
    soc = @{ mode = 'none'; t = 0.0; cool = 60.0; runner = 0; swaps = 0; dur = 0.0; heartT = 0.0 }
    hkT = 1.0                     # Zaehler fuer die Wartungsroutine
    dt = 0.024                    # letzte Frame-Dauer (fuer Apply-Pose)
    hidden = $false               # versteckt, weil eine Vollbild-App laeuft
    away = $false                 # niemand am Rechner -> Katzen doesen
    errLog = (Join-Path $env:TEMP 'desktop-katze-fehler.log')
    errCount = 0
}

# ============================================================================
#  Farben
# ============================================================================
function New-Brush([string]$hex) {
    $c = [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $b = New-Object System.Windows.Media.SolidColorBrush($c)
    $b.Freeze()
    $b
}

$PALETTES = @{
    orange  = @{ fur='#F5BE93'; stripe='#E7A87A'; cream='#FFF3E6'; inner='#F3A9A9'; nose='#E4837C'; eye='#5B3A2C'; edge='#5B3A2C' }
    grau    = @{ fur='#C8CEDC'; stripe='#B3BACB'; cream='#F2F4F9'; inner='#F0AEB4'; nose='#DE8B86'; eye='#3E4660'; edge='#3E4660' }
    schwarz = @{ fur='#4C5166'; stripe='#3E4356'; cream='#EAE7EF'; inner='#C98F8E'; nose='#C97C79'; eye='#2E3345'; edge='#F1F3FA' }
    weiss   = @{ fur='#EEF1FA'; stripe='#D8DEEF'; cream='#FFFFFF'; inner='#F4B3C0'; nose='#E8918B'; eye='#3E4660'; edge='#3E4660' }
    siam    = @{ fur='#F0E4D3'; stripe='#DECDB5'; cream='#FFF8EC'; inner='#EEA9A9'; nose='#C98882'; eye='#5A4636'; edge='#5A4636' }
}

# heller (f > 0) oder dunkler (f < 0) machen
function Tint([System.Windows.Media.Color]$col, [double]$f) {
    if ($f -ge 0) {
        $r = $col.R + (255 - $col.R) * $f
        $g = $col.G + (255 - $col.G) * $f
        $b = $col.B + (255 - $col.B) * $f
    } else {
        $r = $col.R * (1 + $f); $g = $col.G * (1 + $f); $b = $col.B * (1 + $f)
    }
    [System.Windows.Media.Color]::FromRgb([byte]$r, [byte]$g, [byte]$b)
}

# weicher Verlauf von oben hell nach unten etwas dunkler - gibt dem Fell Volumen
function New-VGrad([string]$hex, [double]$topF, [double]$botF) {
    $base = [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $br = New-Object System.Windows.Media.LinearGradientBrush
    $br.StartPoint = [System.Windows.Point]::new(0.3, 0.0)
    $br.EndPoint   = [System.Windows.Point]::new(0.62, 1.0)
    $br.GradientStops.Add((New-Object System.Windows.Media.GradientStop((Tint $base $topF), 0.0)))
    $br.GradientStops.Add((New-Object System.Windows.Media.GradientStop((Tint $base $botF), 1.0)))
    $br.Freeze()
    $br
}

function Get-Palette([string]$name) {
    $p = $PALETTES[$name]
    @{
        fur    = New-Brush $p.fur
        furG   = New-VGrad $p.fur 0.14 -0.09      # Rumpf und Kopf
        stripe = New-Brush $p.stripe
        cream  = New-Brush $p.cream
        creamG = New-VGrad $p.cream 0.10 -0.07    # Bauch, Brust, Schnauze
        inner  = New-Brush $p.inner
        nose   = New-Brush $p.nose
        eye    = New-Brush $p.eye
        eyeG   = New-VGrad $p.eye 0.30 -0.22      # Iris
        edge   = New-Brush $p.edge
        dark   = New-Brush '#3B3B45'
        white  = New-Brush '#FFFFFF'
    }
}

# ============================================================================
#  Bau-Helfer.  $BUILD zeigt beim Bauen auf die Katze, die gerade entsteht -
#  darueber finden New-Ell & Co. die richtige Farbpalette und Formenliste.
# ============================================================================
$BUILD = $null

function Add-Paint($el, $fillRole, $strokeRole) {
    if ($fillRole)   { $el.Fill   = $BUILD.col[$fillRole];   [void]$BUILD.fill[$fillRole].Add($el) }
    if ($strokeRole) { $el.Stroke = $BUILD.col[$strokeRole]; [void]$BUILD.stroke[$strokeRole].Add($el) }
}

function New-Ell($cx, $cy, $rx, $ry, $fill, $strokeRole, $sw) {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $rx * 2; $e.Height = $ry * 2
    [System.Windows.Controls.Canvas]::SetLeft($e, $cx - $rx)
    [System.Windows.Controls.Canvas]::SetTop($e, $cy - $ry)
    Add-Paint $e $fill $strokeRole
    if ($sw) { $e.StrokeThickness = $sw }
    $e
}

function New-Poly($pts, $fill, $strokeRole, $sw) {
    $p = New-Object System.Windows.Shapes.Polygon
    $pc = New-Object System.Windows.Media.PointCollection
    foreach ($q in $pts) { $pc.Add([System.Windows.Point]::new($q[0], $q[1])) }
    $p.Points = $pc
    Add-Paint $p $fill $strokeRole
    if ($sw) { $p.StrokeThickness = $sw }
    $p
}

function New-Line($pts, $strokeRole, $sw) {
    $l = New-Object System.Windows.Shapes.Polyline
    $pc = New-Object System.Windows.Media.PointCollection
    foreach ($q in $pts) { $pc.Add([System.Windows.Point]::new($q[0], $q[1])) }
    $l.Points = $pc
    Add-Paint $l $null $strokeRole
    $l.StrokeThickness = $sw
    $l.StrokeStartLineCap = 'Round'; $l.StrokeEndLineCap = 'Round'
    $l.StrokeLineJoin = 'Round'
    $l
}

function New-Canv() {
    $c = New-Object System.Windows.Controls.Canvas
    $c.Width = $CW; $c.Height = $CH
    $c
}

# spiegelt eine Punktliste an einer senkrechten Achse - damit ist das Gesicht
# nachweislich symmetrisch, statt Seite fuer Seite von Hand gesetzt zu werden
function Mirror-Pts($pts, $ax) {
    $out = @()
    foreach ($p in $pts) { $out += , @((2 * $ax - $p[0]), $p[1]) }
    $out
}

# Fernes Bein: ein kleiner runder Blob HINTER der Silhouette in Fellfarbe. Er
# wird im Schrittzyklus verschoben und schrumpft beim Anheben zur Bauchlinie -
# genau wie die Bein-Ausbuchtungen der Silhouette, damit nie eine Kante unter
# dem Bauch hervorschaut.
function New-Foot($x, $y, $w, $h, $furRole) {
    $c = New-Object System.Windows.Controls.Canvas
    $c.Width = $w; $c.Height = $h
    [System.Windows.Controls.Canvas]::SetLeft($c, $x - $w / 2)
    [System.Windows.Controls.Canvas]::SetTop($c, $y)
    $r = New-Object System.Windows.Shapes.Rectangle
    $r.Width = $w; $r.Height = $h; $r.RadiusX = $w / 2; $r.RadiusY = $w / 2
    Add-Paint $r $furRole $null
    [void]$c.Children.Add($r)
    $sc = New-Object System.Windows.Media.ScaleTransform(1, 1)
    $sc.CenterX = $w / 2; $sc.CenterY = $SIL_BELLY - $y      # Bauchlinie in lokalen Koordinaten
    $tr = New-Object System.Windows.Media.TranslateTransform(0, 0)
    $tg = New-Object System.Windows.Media.TransformGroup
    $tg.Children.Add($sc); $tg.Children.Add($tr)
    $c.RenderTransform = $tg
    @{ el = $c; tr = $tr; sc = $sc }
}

# ============================================================================
#  Silhouette: die ganze Katze ist EINE geschlossene weiche Kurve durch
#  Ankerpunkte - Rumpf, Kopf, Oehrchen und die Beine als Ausbuchtungen.
#  Pro Frame werden die Anker transformiert (Rumpf: Skalierung/Drehung um die
#  Bodenlinie; Kopf: eigene Drehung/Verschiebung; Beine: Schrittversatz, beim
#  Anheben schrumpfen sie in den Bauch) und per Catmull-Rom zu Bezier-Kurven
#  verbunden. So gibt es keine Einzelteile, die abstehen koennten.
#  Katze schaut nach rechts, Boden y=182, Bauchlinie 165, Kopfmitte (128,128).
#  g: 0 Rumpf, 1 Kopf, 2 Hinterbein, 3 Vorderbein  s: Glaette (1 rund, 0 Ecke)
#  e: Ohrspitze (+1 rechts, -1 links) - dreht sich um die Ohrbasis
#  optional 6. Feld: Kopfgewicht 0..1 - Uebergangs-Anker (Brust, Nacken) folgen
#  dem Kopf anteilig, damit die Kontur am Hals nicht faltet
# ============================================================================
$SIL_DEF = @(
    @(52,122,0,1,0),   @(44,140,0,1,0),   @(46,156,0,1,0),                       # Ruecken hinten, Po, unten hinten (schlank)
    @(48,167,2,1,0),   @(49,178,2,1,0),   @(60,182,2,1,0),  @(71,178,2,1,0), @(72,167,2,1,0),   # Hinterbein
    @(86,161,0,1,0),                                                            # Bauch (hoeher = schlanker)
    @(100,167,3,1,0),  @(101,178,3,1,0),  @(112,182,3,1,0), @(123,178,3,1,0), @(124,167,3,1,0), # Vorderbein
    @(132,160,0,0.6,0,0.45),                                                    # Brust (folgt dem Kopf zu 45 %)
    @(145,150,1,1,0),  @(153,134,1,1,0),  @(154,120,1,1,0),                      # Kinn, Wange, Gesicht (symmetrisch zum Hinterkopf)
    @(148,113,1,0.45,0), @(144,95,1,0.3,1), @(138,101,1,0.45,0),                # Ohr rechts (winzig, rund)
    @(128,100,1,1,0),                                                           # Kopf oben
    @(118,101,1,0.45,0), @(112,95,1,0.3,-1), @(108,113,1,0.45,0),               # Ohr links (winzig, rund)
    @(102,121,1,1,0),                                                           # Hinterkopf (runder, leichte Wange)
    @(90,120.5,0,0.6,0,0.4), @(66,120,0,1,0,0.25)                              # Nacken (40 % Kopf), Ruecken (25 %) - tiefer = schlanker
)
$SIL_N = $SIL_DEF.Count
$SIL_X = New-Object double[] $SIL_N; $SIL_Y = New-Object double[] $SIL_N
$SIL_G = New-Object int[] $SIL_N;    $SIL_S = New-Object double[] $SIL_N; $SIL_E = New-Object int[] $SIL_N
$SIL_W = New-Object double[] $SIL_N   # Kopfgewicht der Uebergangs-Anker (6. Feld, sonst 0)
for ($i = 0; $i -lt $SIL_N; $i++) {
    $SIL_X[$i] = $SIL_DEF[$i][0]; $SIL_Y[$i] = $SIL_DEF[$i][1]; $SIL_G[$i] = $SIL_DEF[$i][2]
    $SIL_S[$i] = $SIL_DEF[$i][3] / 6.0; $SIL_E[$i] = $SIL_DEF[$i][4]
    $SIL_W[$i] = 0.0; if ($SIL_DEF[$i].Count -gt 5) { $SIL_W[$i] = $SIL_DEF[$i][5] }
}
$SIL_BELLY = 161.0     # Bauchlinie: hierhin schrumpfen angehobene Pfoetchen
$SIL_EARBX = 15.0; $SIL_EARBY = 107.0     # Ohrbasis-Mitte: (128 +/- 15.0, 107.0)

# kleines Accessoire im Kopf-Verband: Schleife am Ohr (Luna traegt nichts).
# Feste Farben - bleiben beim Fellwechsel gleich.
function Add-Accessory($hg, [string]$kind) {
    if ($kind -eq 'bow') {
        # Schleife am rechten Ohr, in sich symmetrisch um den Knoten (147,98)
        $pink  = New-Brush '#F3A2C2'
        $pinkD = New-Brush '#CC6E94'
        $petal = @(@(147,98),@(153.6,93.2),@(154.2,101.8))
        foreach ($t in @($petal, (Mirror-Pts $petal 147))) {
            $p = New-Object System.Windows.Shapes.Polygon
            $pc = New-Object System.Windows.Media.PointCollection
            foreach ($q in $t) { $pc.Add([System.Windows.Point]::new($q[0], $q[1])) }
            $p.Points = $pc
            $p.Fill = $pink; $p.Stroke = $pinkD; $p.StrokeThickness = 0.9
            [void]$hg.Children.Add($p)
        }
        $knot = New-Object System.Windows.Shapes.Ellipse
        $knot.Width = 4.8; $knot.Height = 4.8; $knot.Fill = $pinkD
        [System.Windows.Controls.Canvas]::SetLeft($knot, 144.6)
        [System.Windows.Controls.Canvas]::SetTop($knot, 95.6)
        [void]$hg.Children.Add($knot)
    }
}

# Punktauge im Sticker-Stil: Punkt in Linienfarbe + Pupille; ScaleY blinzelt
function New-Eye($cx, $cy, $r) {
    $g = New-Canv
    [void]$g.Children.Add((New-Ell $cx $cy $r ($r * 1.2) 'edge' $null 0))
    # Pupille: bei hellem Fell gleiche Farbe (ein dunkler Punkt), bei dunklem
    # Fell dunkel im hellen Auge - so bleibt der Glanzpunkt sichtbar
    [void]$g.Children.Add((New-Ell $cx $cy ($r * 0.72) ($r * 0.72 * 1.2) 'eye' $null 0))
    $sc = New-Object System.Windows.Media.ScaleTransform(1, 1)
    $sc.CenterX = $cx; $sc.CenterY = $cy
    $g.RenderTransform = $sc
    @{ el = $g; scl = $sc }
}

# ============================================================================
#  Eine Katze bauen: Fenster + Rig + Zustand
# ============================================================================
function New-Cat([string]$fur, [double]$size, [string]$name, [string]$title, [string]$acc, [double]$headK = 1.14) {
    $c = @{
        name = $name; fur = $fur; size = $size; acc = $acc
        col = (Get-Palette $fur); fill = @{}; stroke = @{}
        x = 0.0; y = 0.0; vx = 0.0; vy = 0.0; facing = 1.0
        groundY = 700.0; screen = $null
        state = 'walk'; stateT = 0.0; stateDur = 3.0; phase = 0.0
        t = (Rnd 0 40); pxs = $size
        blinkT = (Rnd 1 5); blink = 0.0; blinkDur = 0.16
        swipe = 0.0; edgeT = 0.0; chase = $false
        clickThrough = $true
        dragging = $false; dragMoved = 0.0; downPos = $null; zoomies = $false
        particles = New-Object System.Collections.ArrayList
        zT = 0.0; heartT = 0.0; meowT = 0.0; batNext = 0.0; digT = 0.0
        look = 0.0; lookY = 0.0
        locked = $false; meetX = 0.0
        kit = $false; target = $null; chuteOn = $false; headK = $headK
        rel = 1.0; gripDX = 0.0; gripDY = 0.0
        svx = 0.0; fvis = 1.0; earT = (Rnd 2 6); earFlick = 0.0
        pose = $null; base = $null
    }
    foreach ($k in 'fur','furG','stripe','cream','creamG','inner','nose','eye','eyeG','edge','dark','white') {
        $c.fill[$k]   = New-Object System.Collections.ArrayList
        $c.stroke[$k] = New-Object System.Collections.ArrayList
    }
    $script:BUILD = $c

    $win = New-Object System.Windows.Window
    $win.WindowStyle = 'None'
    $win.AllowsTransparency = $true
    $win.Background = [System.Windows.Media.Brushes]::Transparent
    $win.Topmost = $true
    $win.ShowInTaskbar = $false
    $win.ResizeMode = 'NoResize'
    $win.ShowActivated = $false
    $win.Title = $title
    $win.Width = ($CW + 2 * $PAD) * $size
    $win.Height = ($CH + $PAD) * $size
    $c.win = $win

    $root = New-Canv
    $root.HorizontalAlignment = 'Left'; $root.VerticalAlignment = 'Top'
    $c.rootScale = New-Object System.Windows.Media.ScaleTransform($size, $size)
    $c.rootPad = New-Object System.Windows.Media.TranslateTransform(($PAD * $size), 0)
    $rtg = New-Object System.Windows.Media.TransformGroup
    $rtg.Children.Add($c.rootScale); $rtg.Children.Add($c.rootPad)
    $root.RenderTransform = $rtg
    $win.Content = $root
    $c.root = $root

    $flip = New-Canv
    $c.flipScale = New-Object System.Windows.Media.ScaleTransform(1, 1)
    $c.flipScale.CenterX = $CW / 2; $c.flipScale.CenterY = 0
    $flip.RenderTransform = $c.flipScale
    [void]$root.Children.Add($flip)

    # --- Schatten am Boden --------------------------------------------------
    $shadow = New-Object System.Windows.Shapes.Ellipse
    $shadow.Width = 100; $shadow.Height = 18
    [System.Windows.Controls.Canvas]::SetLeft($shadow, 83 - 50)
    [System.Windows.Controls.Canvas]::SetTop($shadow, 178 - 9)
    $sg = New-Object System.Windows.Media.RadialGradientBrush
    $sg.GradientStops.Add((New-Object System.Windows.Media.GradientStop(([System.Windows.Media.Color]::FromArgb(110,0,0,0)), 0.0)))
    $sg.GradientStops.Add((New-Object System.Windows.Media.GradientStop(([System.Windows.Media.Color]::FromArgb(0,0,0,0)), 1.0)))
    $shadow.Fill = $sg
    $c.shadowScale = New-Object System.Windows.Media.ScaleTransform(1, 1)
    $c.shadowScale.CenterX = 50; $c.shadowScale.CenterY = 9
    $shadow.RenderTransform = $c.shadowScale
    $shadow.IsHitTestVisible = $false
    $c.shadow = $shadow
    [void]$flip.Children.Add($shadow)

    # --- Rumpf-Verband: Schwanz und ferne Beine haengen an der Rumpf-
    # Transformation (Skalierung/Drehung um die Bodenlinie), damit sie bei
    # jeder Pose mit der Silhouette mitgehen.
    $bodyC = New-Canv
    $c.tailPts  = New-Object System.Windows.Media.PointCollection
    $c.tailPts2 = New-Object System.Windows.Media.PointCollection   # von Set-Tail mitgefuehrt, hier ungenutzt
    for ($i = 0; $i -le 12; $i++) {
        $c.tailPts.Add([System.Windows.Point]::new(0, 0))
        $c.tailPts2.Add([System.Windows.Point]::new(0, 0))
    }
    $tail = New-Object System.Windows.Shapes.Polyline
    $tail.Points = $c.tailPts
    Add-Paint $tail $null 'fur'
    $tail.StrokeThickness = 17
    $tail.StrokeStartLineCap = 'Round'; $tail.StrokeEndLineCap = 'Round'; $tail.StrokeLineJoin = 'Round'
    [void]$bodyC.Children.Add($tail)
    $c.tailTip = New-Ell 0 0 9.5 9.5 'fur' $null 0     # sanft dickere, runde Spitze = Fluff
    [void]$bodyC.Children.Add($c.tailTip)
    $c.legBF = New-Foot 52 152 17 26 'fur';  [void]$bodyC.Children.Add($c.legBF.el)
    $c.legFF = New-Foot 104 152 17 26 'fur'; [void]$bodyC.Children.Add($c.legFF.el)

    $c.bodyScl = New-Object System.Windows.Media.ScaleTransform(1, 1)
    $c.bodyScl.CenterX = $BCX; $c.bodyScl.CenterY = $GROUND
    $c.bodyRot = New-Object System.Windows.Media.RotateTransform(0)
    $c.bodyRot.CenterX = $BCX; $c.bodyRot.CenterY = $GROUND
    $c.bodyTr = New-Object System.Windows.Media.TranslateTransform(0, 0)
    $btg = New-Object System.Windows.Media.TransformGroup
    $btg.Children.Add($c.bodyScl); $btg.Children.Add($c.bodyRot); $btg.Children.Add($c.bodyTr)
    $bodyC.RenderTransform = $btg
    [void]$flip.Children.Add($bodyC)

    # --- Kopf-Transformation: dieselben Zahlen wendet Apply-Pose auf die
    # Kopf-Anker der Silhouette an, damit Kontur und Gesicht zusammenbleiben.
    $headScl = New-Object System.Windows.Media.ScaleTransform($headK, $headK)
    $headScl.CenterX = 128; $headScl.CenterY = 128
    $c.headRot = New-Object System.Windows.Media.RotateTransform(0)
    $c.headRot.CenterX = 112; $c.headRot.CenterY = 142
    $c.headTr = New-Object System.Windows.Media.TranslateTransform(0, 0)
    $htg = New-Object System.Windows.Media.TransformGroup
    $htg.Children.Add($headScl); $htg.Children.Add($c.headRot); $htg.Children.Add($c.headTr)

    # --- Silhouette: ein Pfad, Bezier-Punkte werden in Apply-Pose gesetzt ---
    $c.silPts = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -lt 3 * $SIL_N; $i++) { $c.silPts.Add([System.Windows.Point]::new(0, 0)) }
    $seg = New-Object System.Windows.Media.PolyBezierSegment
    $seg.Points = $c.silPts
    $c.silFig = New-Object System.Windows.Media.PathFigure
    $c.silFig.IsClosed = $true; $c.silFig.IsFilled = $true
    $c.silFig.Segments.Add($seg)
    $geo = New-Object System.Windows.Media.PathGeometry
    $geo.Figures.Add($c.silFig)
    $geo.FillRule = [System.Windows.Media.FillRule]::Nonzero   # Schleifen fuellen statt Loecher
    $sil = New-Object System.Windows.Shapes.Path
    $sil.Data = $geo
    Add-Paint $sil 'fur' $null
    [void]$flip.Children.Add($sil)

    # --- Gesicht: nur das Noetigste - zwei Punkte und ein w-Maeulchen. Alles
    # spiegelsymmetrisch zur Achse $FX; der Kopf selbst ist Teil der Silhouette.
    $headG = New-Canv
    $FX = 128.0

    # Maul (offen): kleines warm-rosa Oval, klappt unter der Lippenlinie auf
    $mouthG = New-Canv
    $mo = New-Ell $FX 140.4 2.8 3.0 $null $null 0
    $mo.Fill = New-Brush '#A3555C'
    [void]$mouthG.Children.Add($mo)
    $tng = New-Ell $FX 142.0 1.7 1.4 $null $null 0
    $tng.Fill = New-Brush '#EF9BA4'
    [void]$mouthG.Children.Add($tng)
    $c.mouthScl = New-Object System.Windows.Media.ScaleTransform(1, 0)
    $c.mouthScl.CenterX = $FX; $c.mouthScl.CenterY = 137.4
    $mouthG.RenderTransform = $c.mouthScl
    [void]$headG.Children.Add($mouthG)

    # zwei Punktaugen
    $c.eyeF = New-Eye ($FX - 7.5) 133 2.9; [void]$headG.Children.Add($c.eyeF.el)
    [void]$c.eyeF.el.Children.Add((New-Ell ($FX - 8.4) 131.9 1.0 1.0 'white' $null 0))
    $c.eyeN = New-Eye ($FX + 7.5) 133 2.9; [void]$headG.Children.Add($c.eyeN.el)
    [void]$c.eyeN.el.Children.Add((New-Ell ($FX + 6.6) 131.9 1.0 1.0 'white' $null 0))
    foreach ($bx in @(($FX - 13), ($FX + 13))) {
        $cheek = New-Ell $bx 137.5 3.4 2.1 'inner' $null 0; $cheek.Opacity = 0.25
        [void]$headG.Children.Add($cheek)
    }

    # geschlossene Augen: kleine zufriedene Boegen
    $lidRp = @(@(($FX + 4.3),133.2), @(($FX + 7.5),134.8), @(($FX + 10.7),133.2))
    $c.lidN = New-Line $lidRp 'edge' 1.2
    $c.lidF = New-Line (Mirror-Pts $lidRp $FX) 'edge' 1.2
    $c.lidF.Opacity = 0; $c.lidN.Opacity = 0
    [void]$headG.Children.Add($c.lidF); [void]$headG.Children.Add($c.lidN)

    # w-Maeulchen: zwei weiche runde Boegen (je 5 Punkte statt spitzem Knick)
    $lipRp = @(@($FX,137.4), @(($FX + 1.05),138.7), @(($FX + 2.1),139.2), @(($FX + 3.15),138.7), @(($FX + 4.2),137.5))
    $c.lipN = New-Line $lipRp 'edge' 1.3
    $c.lipF = New-Line (Mirror-Pts $lipRp $FX) 'edge' 1.3
    [void]$headG.Children.Add($c.lipF); [void]$headG.Children.Add($c.lipN)

    Add-Accessory $headG $c.acc

    $headG.RenderTransform = $htg
    [void]$flip.Children.Add($headG)

    # --- weicher Sticker-Schatten um die ganze Silhouette (nur mit
    # Hardware-Rendering, sonst kostet der Weichzeichner zu viel CPU)
    if (([System.Windows.Media.RenderCapability]::Tier -shr 16) -ge 2) {
        $shadowFx = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadowFx.BlurRadius = 7; $shadowFx.ShadowDepth = 2; $shadowFx.Direction = 270; $shadowFx.Opacity = 0.22
        $shadowFx.Color = [System.Windows.Media.Colors]::Black
        $flip.Effect = $shadowFx
    }

    # --- Fallschirm: rosa Kuppel mit Leinen, nur sichtbar beim Fall aus
    # grosser Hoehe (Set-Chute). Pendelt um den Aufhaengepunkt (95,126).
    $chuteG = New-Canv
    $chuteCol  = New-Brush '#F3A2C2'
    $chuteEdge = New-Brush '#CC6E94'
    foreach ($s in @(@(55,42,72,124), @(95,46,95,118), @(135,42,118,124))) {
        $ln = New-Object System.Windows.Shapes.Polyline
        $lp2 = New-Object System.Windows.Media.PointCollection
        $lp2.Add([System.Windows.Point]::new($s[0], $s[1]))
        $lp2.Add([System.Windows.Point]::new($s[2], $s[3]))
        $ln.Points = $lp2
        $ln.Stroke = $chuteEdge; $ln.StrokeThickness = 1.4
        $ln.StrokeStartLineCap = 'Round'; $ln.StrokeEndLineCap = 'Round'
        [void]$chuteG.Children.Add($ln)
    }
    $dome = New-Object System.Windows.Controls.Canvas
    $dome.Width = $CW; $dome.Height = $CH
    # Zuschnitt: Kuppelform = Ellipse, unten glatt abgeschnitten
    $domeEll = New-Object System.Windows.Media.EllipseGeometry
    $domeEll.Center = [System.Windows.Point]::new(95, 34)
    $domeEll.RadiusX = 46; $domeEll.RadiusY = 27
    $dome.Clip = New-Object System.Windows.Media.CombinedGeometry('Intersect', $domeEll,
                 (New-Object System.Windows.Media.RectangleGeometry([System.Windows.Rect]::new(47, 5, 96, 37))))
    [void]$dome.Children.Add((New-Oval 95 34 46 27 0 $chuteCol $chuteEdge 2.6))
    [void]$dome.Children.Add((New-Oval 95 34 15 27 0 (New-Brush '#FFF6FA') $null 0))
    foreach ($bx in @(65, 125)) {
        $bl = New-Oval $bx 34 12 26.5 0 $null $chuteEdge 1.0
        $bl.Opacity = 0.55
        [void]$dome.Children.Add($bl)
    }
    [void]$chuteG.Children.Add($dome)
    $hem = New-Object System.Windows.Shapes.Polyline
    $hp = New-Object System.Windows.Media.PointCollection
    foreach ($q in @(@(50,40),@(72,44.5),@(95,45.8),@(118,44.5),@(140,40))) {
        $hp.Add([System.Windows.Point]::new($q[0], $q[1]))
    }
    $hem.Points = $hp
    $hem.Stroke = $chuteEdge; $hem.StrokeThickness = 1.6
    $hem.StrokeStartLineCap = 'Round'; $hem.StrokeEndLineCap = 'Round'
    [void]$chuteG.Children.Add($hem)
    $c.chuteRot = New-Object System.Windows.Media.RotateTransform(0)
    $c.chuteRot.CenterX = 95; $c.chuteRot.CenterY = 126
    $chuteG.RenderTransform = $c.chuteRot
    $chuteG.Visibility = 'Collapsed'
    $chuteG.IsHitTestVisible = $false
    $c.chuteG = $chuteG
    [void]$flip.Children.Add($chuteG)

    $c.pose = (NewPose $null)
    $c.base = $POSES['walk']

    # --- Fensterstil + Mausbedienung -------------------------------------
    # GetNewClosure() bindet $c an den Handler - so weiss jeder Handler,
    # zu welcher Katze er gehoert.
    $win.Add_SourceInitialized({
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($c.win)).Handle
        $ex = [CatNative]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        $ex = $ex -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE -bor $WS_EX_TRANSPARENT
        [void][CatNative]::SetWindowLong($hwnd, $GWL_EXSTYLE, $ex)
        $c.clickThrough = $true
        $src = [System.Windows.PresentationSource]::FromVisual($c.win)
        if ($null -ne $src) {
            $m = $src.CompositionTarget.TransformToDevice
            if ($m.M11 -gt 0) { $G.sx = $m.M11 }
            if ($m.M22 -gt 0) { $G.sy = $m.M22 }
        }
        $c.pxs = $c.size * $G.sx
    }.GetNewClosure())

    $root.Add_MouseLeftButtonDown({
        $c.downPos = [System.Windows.Forms.Cursor]::Position
        $c.dragMoved = 0.0
        $c.dragging = $true
        Clear-Particles $c
        if (-not $c.kit) { Abort-Social }     # Kaetzchen anfassen bricht die Grossen nicht ab
        Set-State $c 'drag' 999
        $c.vx = 0; $c.vy = 0
        # Griffpunkt merken: die Katze bleibt genau dort haengen, wo sie gepackt wurde
        $c.gripDX = $c.x - $c.downPos.X
        $c.gripDY = ($c.downPos.Y / $G.sy) - $c.win.Top
        Set-Chute $c $false
        $c.root.CaptureMouse() | Out-Null
        if ($_.ClickCount -eq 2) { $c.zoomies = $true }
    }.GetNewClosure())

    $root.Add_MouseMove({
        if ($c.dragging -and $null -ne $c.downPos) {
            $cur = [System.Windows.Forms.Cursor]::Position
            $d = [Math]::Abs($cur.X - $c.downPos.X) + [Math]::Abs($cur.Y - $c.downPos.Y)
            if ($d -gt $c.dragMoved) { $c.dragMoved = $d }
        }
    }.GetNewClosure())

    $root.Add_MouseLeftButtonUp({
        if (-not $c.dragging) { return }
        $c.dragging = $false
        $c.root.ReleaseMouseCapture()
        if ($c.dragMoved -lt 6) {
            if ($c.zoomies) {
                $c.zoomies = $false
                $c.y = 0; $c.vy = 0
                Set-State $c 'run' (Rnd 3.5 5.5)
            } else {
                $c.y = 0; $c.vy = 0
                Set-State $c 'pet' (Rnd 2.4 3.4)
                $c.heartT = 0.05
            }
        } else {
            $c.zoomies = $false
            if ($c.y -gt 2) {
                Set-State $c 'fall' 5; $c.vy = 0
                # aus grosser Hoehe losgelassen? dann geht der Fallschirm auf
                $waH = $c.screen.WorkingArea.Height / $G.sy
                if ($c.y -gt $waH * 0.30) { Set-Chute $c $true }
            } else { Do-Land $c }
        }
    }.GetNewClosure())

    # Capture-Verlust (Rechtsklick-Menue, Alt+Tab, Fenster wird versteckt):
    # wirkt wie Loslassen, sonst klebt die Katze fuer immer am Zeiger
    $root.Add_LostMouseCapture({
        if (-not $c.dragging) { return }
        $c.dragging = $false; $c.zoomies = $false
        if ($c.y -gt 2) { Set-State $c 'fall' 5; $c.vy = 0 } else { Do-Land $c }
    }.GetNewClosure())

    $script:BUILD = $null
    $c
}

# ============================================================================
#  Posen
# ============================================================================
# Pfoetchen: pFNx/pFNy = Verschiebung des vorderen nahen Pfoetchens in Pixeln.
# y negativ = angehoben, 0 = am Boden. F = fern, N = nah, F/B = vorn/hinten.
$POSE_KEYS = @('bdx','bdy','brot','bsx','bsy','hdx','hdy','hrot',
               'pFNx','pFNy','pFFx','pFFy','pBNx','pBNy','pBFx','pBFy',
               'tailA','tailC','eye','ear','mouth')
$DEFAULT_POSE = @{
    bdx=0.0; bdy=0.0; brot=0.0; bsx=1.0; bsy=1.0
    hdx=0.0; hdy=0.0; hrot=0.0
    pFNx=0.0; pFNy=0.0; pFFx=0.0; pFFy=0.0
    pBNx=0.0; pBNy=0.0; pBFx=0.0; pBFy=0.0
    tailA=38.0; tailC=0.45; eye=1.0; ear=0.0; mouth=0.0
    bflip=1.0          # -1 = Rumpf gekippt (Bauch oben); wird nicht interpoliert
}
function PoseFrom($basePose, [hashtable]$over) {
    $p = $basePose.Clone()
    if ($over) { foreach ($k in $over.Keys) { $p[$k] = [double]$over[$k] } }
    $p
}
function NewPose([hashtable]$over) { PoseFrom $DEFAULT_POSE $over }

# Sitzen: der Koerper richtet sich auf - schmaler und hoeher. Skaliert wird um
# die Bodenlinie, die Fuesse bleiben also stehen; der Kopf rueckt nach oben.
$SIT = NewPose @{ bsx=0.82; bsy=1.28; hdx=-9; hdy=-16; hrot=4; pFNx=6; pFFx=4; tailA=6; tailC=0.95 }

$POSES = @{
    idle   = NewPose @{ tailA=40; tailC=0.5 }
    walk   = NewPose @{ tailA=42; tailC=0.55 }
    run    = NewPose @{ brot=-3; bsx=1.08; tailA=24; tailC=0.4; ear=-9; hdy=1 }
    sit    = $SIT
    # Loaf: flach und breit, Pfoetchen ganz eingezogen, Bauch auf dem Boden
    # (bdy = (182 - 161) * bsy: die skalierte Bauchlinie sinkt bis zur Bodenlinie 182)
    sleep  = NewPose @{ bdy=16.8; bsx=1.14; bsy=0.80; pFNy=-17; pFFy=-17; pBNy=-17; pBFy=-17;
                        hdx=2; hdy=9; hrot=0; tailA=-25; tailC=1.5; eye=0.05; ear=-6 }
    # zusammengerollt: kompakt, alle Pfoetchen weg, Kopf tief
    curl   = NewPose @{ bdy=18.9; bsx=0.96; bsy=0.90; pFNy=-17; pFFy=-17; pBNy=-17; pBFy=-17;
                        hdx=-8; hdy=10; hrot=16; tailA=-30; tailC=1.5; eye=0.05; ear=-10 }
    groom  = PoseFrom $SIT @{ pFNx=12; pFNy=-12; hdx=-8; hdy=-8; hrot=40; tailA=10; tailC=0.9; eye=0.25 }
    stretch= NewPose @{ bsx=1.18; bsy=0.88; pFNx=8; pFFx=6; pBNx=-6; pBFx=-5;
                        hdx=4; hdy=9; hrot=12; tailA=74; tailC=0.2; eye=0.3 }
    crouch = NewPose @{ bsy=0.82; bsx=1.05; pFNy=-4; pFFy=-3; pBNy=-4; pBFy=-3;
                        hdy=8; hrot=4; tailA=10; tailC=0.6; ear=-7 }
    leap   = NewPose @{ bsy=1.06; bsx=1.08; brot=-6;
                        pFNx=9; pFNy=-10; pFFx=8; pFFy=-9; pBNx=-9; pBNy=-8; pBFx=-8; pBFy=-7;
                        tailA=58; tailC=-0.3 }
    land   = NewPose @{ bsy=0.76; bsx=1.16; pFNx=6; pFFx=5; pBNx=-6; pBFx=-5;
                        hdy=6; tailA=34; tailC=0.6; ear=-4 }
    fall   = NewPose @{ bsy=0.96; pFNx=7; pFNy=-8; pFFx=6; pFFy=-7;
                        pBNx=-7; pBNy=-8; pBFx=-6; pBFy=-7; tailA=82; tailC=-0.5; ear=-6 }
    drag   = NewPose @{ brot=6; bsy=1.04; pFNx=3; pFNy=-6; pFFx=2; pFFy=-5; pBNx=-3; pBNy=-6; pBFx=-2; pBFy=-5;
                        tailA=100; tailC=-0.4; ear=-11 }
    pet    = PoseFrom $SIT @{ hdy=-20; hrot=16; tailA=86; tailC=0.26; eye=0.08; ear=5 }
    chase  = NewPose @{ bsy=0.94; hdy=3; tailA=12; tailC=0.5; ear=-5 }
    yawn   = PoseFrom $SIT @{ hdx=-8; hdy=-20; hrot=2; tailA=12; tailC=0.9; eye=0.06; mouth=1.0; ear=-3 }
    meow   = PoseFrom $SIT @{ hdx=-8; hdy=-18; hrot=8; tailA=20; tailC=0.85; mouth=0.7 }
    watch  = PoseFrom $SIT @{ hdx=-7; hdy=-18; hrot=10; tailA=30; tailC=0.8; ear=3 }
    scratch= PoseFrom $SIT @{ pBNx=14; pBNy=-14; hdx=-12; hdy=-10; hrot=26; tailA=2; eye=0.35; ear=8 }
    # lang hingestreckt auf der Seite luemmeln (ersetzt das Waelzen)
    roll   = NewPose @{ bdy=16.4; bsx=1.18; bsy=0.78; pFNx=6; pFNy=-17; pFFx=4; pFFy=-17; pBNx=-6; pBNy=-17; pBFx=-4; pBFy=-17;
                        hdx=-4; hdy=10; hrot=-18; eye=0.5; mouth=0.15; ear=-6; tailA=30; tailC=0.6 }
    # aufrichten am Bildschirmrand: hoch und schmal, Kopf ganz oben
    edge   = NewPose @{ bsx=0.9; bsy=1.25; brot=-5; pFNx=6; pFNy=-17; pFFx=4; pFFy=-17;
                        hdx=-4; hdy=-14; hrot=-6; tailA=-58; tailC=0.25; ear=-2 }
    wave   = PoseFrom $SIT @{ pFNx=12; pFNy=-14; hdx=-6; hrot=14; tailA=20; tailC=0.8; ear=4 }
    sniff  = NewPose @{ bsy=0.96; pFNy=-2; pBNy=-2; hdx=6; hdy=12; hrot=34; ear=5; tailA=30; tailC=0.4 }
    arch   = NewPose @{ bsy=1.16; bsx=0.92; pFNx=-4; pFFx=-3; pBNx=4; pBFx=3;
                        hdx=-2; hdy=6; hrot=20; tailA=98; tailC=-0.12; ear=-6; eye=0.55 }
    shake  = NewPose @{ eye=0.25; ear=-4; tailA=40; tailC=0.3 }
    dig    = NewPose @{ bsy=0.94; pBNy=-4; pBFy=-3; hdy=6; hrot=18; tailA=24; tailC=0.5; ear=2 }
    # Maennchen machen: wie 'edge', Ohren nach vorn
    beg    = NewPose @{ bsx=0.9; bsy=1.25; brot=-5; pFNx=6; pFNy=-17; pFFx=4; pFFy=-17;
                        hdx=-4; hdy=-14; hrot=-2; tailA=-58; tailC=0.3; ear=6 }
    rub    = NewPose @{ hdx=-2; hrot=-8; tailA=104; tailC=0.2; ear=5; eye=0.45 }
    bat    = NewPose @{ bsy=0.92; pFNx=12; pFNy=-8; pBNy=-4; pBFy=-3; hdy=4; hrot=10; tailA=30; tailC=0.4; ear=-3 }
    greet  = NewPose @{ hdx=9; hdy=3; hrot=7; tailA=92; tailC=0.28; ear=6 }
    # --- neue Aktivitaeten (Designer-Wettbewerb 27.08.) ---
    # Katzenbrot: wie 'sleep' flach am Boden, aber wach - Augen offen, Kopf
    # ein Stueck hoeher, Oehrchen aufgestellt, Schwanz um den Koerper gelegt
    loaf   = NewPose @{ bdy=17.2; bsx=1.12; bsy=0.82; pFNy=-17; pFFy=-17; pBNy=-17; pBFy=-17;
                        hdx=1; hdy=5; hrot=0; tailA=-25; tailC=1.5; eye=1.0; ear=2 }
    # Freudenhopser: aufrecht, Schwanz hoch, froehlich offenes Maeulchen
    hop    = NewPose @{ tailA=62; tailC=0.3; ear=4; mouth=0.3 }
    # Kopf schief legen (Gesicht ist frontal, hrot liest sich als Neigen)
    tilt   = PoseFrom $SIT @{ hdx=-8; hdy=-17; hrot=-17; ear=6; tailA=14; tailC=0.9 }
    # Koepfchen geben: Kopf hoch, Stirn nach vorn, Augen schmal, Schwanz hoch
    bunt   = NewPose @{ bsy=1.02; pFNx=3; pFFx=2; hdx=6; hdy=-6; hrot=-14; eye=0.45; ear=-6; tailA=80; tailC=0.22; mouth=0.05 }
    # Katzenkuss: aufrecht sitzen, Kinn leicht gehoben, Schwanz um die Fuesse
    blink  = PoseFrom $SIT @{ hdy=-18; hrot=-3; tailA=8; tailC=1.0; ear=2; mouth=0.06 }
    # Schnurren mit Milchtritt (nach dem Streicheln): entspannt, Augen zu Schlitzen
    purr   = PoseFrom $SIT @{ hdy=-14; hrot=-2; pFNx=7; pFFx=5; eye=0.2; ear=-4; tailA=12; tailC=1.0; mouth=0.08 }
    # Popo-Wackeln vor dem Sprung: Vorderkoerper tief, Hinterteil hoch, Blick starr
    wiggle = NewPose @{ bsy=0.86; bsx=1.04; brot=4; bdy=-1; hdy=6; hrot=2; pBNy=-2; pBFy=-2;
                        tailA=18; tailC=0.5; ear=2 }
}

# Zustaende, die sich eine Pose mit einem anderen teilen
$POSE_ALIAS = @{ toychase='chase'; approach='walk'; flee='run'; tagchase='chase'; nuzzle='groom'
                 pester='chase'; kitbat='bat' }

# ============================================================================
#  Partikel (Herzchen, Z-Z-Z, "miau", Staub)
# ============================================================================
function Add-Particle($c, [string]$kind, $x, $y) {
    $el = $null
    if ($kind -eq 'heart') {
        $el = New-Object System.Windows.Controls.TextBlock
        $el.Text = [char]0x2665
        $el.FontSize = (Rnd 15 22)
        $el.Foreground = (New-Brush '#FF7DA0')
    } elseif ($kind -eq 'meow') {
        $el = New-Object System.Windows.Controls.TextBlock
        $el.Text = 'miau'
        $el.FontSize = 14
        $el.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
        $el.FontStyle = 'Italic'
        $el.Foreground = (New-Brush '#7C8BA6')
    } elseif ($kind -eq 'z') {
        $el = New-Object System.Windows.Controls.TextBlock
        $el.Text = 'z'
        $el.FontSize = (Rnd 13 20)
        $el.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
        $el.FontWeight = 'Bold'
        $el.Foreground = (New-Brush '#8FA8C8')
    } else {
        $el = New-Object System.Windows.Shapes.Ellipse
        $d = Rnd 5 11
        $el.Width = $d; $el.Height = $d
        $el.Fill = (New-Brush '#B9B2A6')
    }
    $el.IsHitTestVisible = $false
    [System.Windows.Controls.Canvas]::SetLeft($el, $x)
    [System.Windows.Controls.Canvas]::SetTop($el, $y)
    [void]$c.root.Children.Add($el)
    if ($kind -eq 'dust') {
        $mx = 0.55; $vx0 = Rnd -55 55; $vy0 = Rnd -30 -8
    } else {
        $mx = 1.9;  $vx0 = Rnd -9 9;   $vy0 = Rnd -34 -22
    }
    [void]$c.particles.Add(@{ el=$el; x=$x; y=$y; kind=$kind; life=0.0; max=$mx; vx=$vx0; vy=$vy0 })
}

function Update-Particles($c, $dt) {
    for ($i = $c.particles.Count - 1; $i -ge 0; $i--) {
        $p = $c.particles[$i]
        $p.life += $dt
        if ($p.life -ge $p.max) {
            [void]$c.root.Children.Remove($p.el)
            $c.particles.RemoveAt($i)
            continue
        }
        $p.x += $p.vx * $dt
        $p.y += $p.vy * $dt
        if ($p.kind -eq 'dust') { $p.vy += 90 * $dt } else { $p.vx += [Math]::Sin($p.life * 6) * 14 * $dt }
        [System.Windows.Controls.Canvas]::SetLeft($p.el, $p.x)
        [System.Windows.Controls.Canvas]::SetTop($p.el, $p.y)
        $p.el.Opacity = [Math]::Max(0, 1 - ($p.life / $p.max))
    }
}

function Clear-Particles($c) {
    foreach ($p in @($c.particles)) { [void]$c.root.Children.Remove($p.el) }
    $c.particles.Clear()
}

# ============================================================================
#  Spielzeug: Wollknaeuel und Schmetterling
#  Beide leben in eigenen kleinen Fenstern, damit sie sich frei ueber den
#  ganzen Bildschirm bewegen koennen (ein Katzenfenster ist nur 190x190).
# ============================================================================
function Get-RefCat($x) {
    # die Katze, die einem Punkt am naechsten ist (fuer Boden und Bildschirm)
    $best = $null; $bd = [double]::MaxValue
    foreach ($c in $G.cats) {
        $d = [Math]::Abs($c.x - $x)
        if ($d -lt $bd) { $bd = $d; $best = $c }
    }
    $best
}

function New-SpriteWindow($w, $h, $title, $size) {
    $sw2 = New-Object System.Windows.Window
    $sw2.WindowStyle = 'None'
    $sw2.AllowsTransparency = $true
    $sw2.Background = [System.Windows.Media.Brushes]::Transparent
    $sw2.Topmost = $true
    $sw2.ShowInTaskbar = $false
    $sw2.ResizeMode = 'NoResize'
    $sw2.ShowActivated = $false
    $sw2.Title = $title
    $sw2.Width = $w * $size; $sw2.Height = $h * $size
    $sw2.Left = -500; $sw2.Top = -500
    $cv = New-Object System.Windows.Controls.Canvas
    $cv.Width = $w; $cv.Height = $h
    $cv.RenderTransform = New-Object System.Windows.Media.ScaleTransform($size, $size)
    $sw2.Content = $cv
    $sw2.Show()
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($sw2)).Handle
    if ($hwnd -ne [IntPtr]::Zero) {
        $ex = [CatNative]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        [void][CatNative]::SetWindowLong($hwnd, $GWL_EXSTYLE,
              ($ex -bor $WS_EX_TRANSPARENT -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE))
    }
    @{ win = $sw2; cv = $cv; w = $w; h = $h; size = $size }
}

function Set-SpritePos($sp, $px, $py) {
    $sp.win.Left = ($px / $G.sx) - ($sp.w * $sp.size / 2)
    $sp.win.Top  = ($py / $G.sy) - ($sp.h * $sp.size / 2)
}

function New-Oval($cx, $cy, $rx, $ry, $ang, $fill, $stroke, $sw) {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $rx * 2; $e.Height = $ry * 2
    [System.Windows.Controls.Canvas]::SetLeft($e, $cx - $rx)
    [System.Windows.Controls.Canvas]::SetTop($e, $cy - $ry)
    if ($fill)   { $e.Fill = $fill }
    if ($stroke) { $e.Stroke = $stroke; $e.StrokeThickness = $sw }
    if ($ang -ne 0) {
        $rt = New-Object System.Windows.Media.RotateTransform($ang)
        $rt.CenterX = $rx; $rt.CenterY = $ry
        $e.RenderTransform = $rt
    }
    $e
}

function New-Yarn($size) {
    $sp = New-SpriteWindow 56 56 'Katzen-Wollknaeuel' $size
    $yarn   = New-Brush '#E4646B'
    $light  = New-Brush '#F5989D'
    $thread = New-Brush '#9E2B37'
    $spin = New-Object System.Windows.Controls.Canvas
    $spin.Width = 56; $spin.Height = 56
    $ball = New-Object System.Windows.Controls.Canvas
    $ball.Width = 56; $ball.Height = 56
    $cl = New-Object System.Windows.Media.EllipseGeometry
    $cl.Center = [System.Windows.Point]::new(28, 28); $cl.RadiusX = 15; $cl.RadiusY = 15
    $ball.Clip = $cl
    [void]$ball.Children.Add((New-Oval 28 28 15 15 0 $yarn $null 0))
    $gl2 = New-Oval 23.5 23 9.5 9 0 $light $null 0
    $gl2.Opacity = 0.5
    [void]$ball.Children.Add($gl2)
    # unregelmaessige Wicklung: versetzte Ovale in wechselnden Winkeln
    foreach ($f in @(@(26,28.5,15,7,16), @(30,26.5,13.5,6,72), @(27,30,14,5.5,126), @(28.5,25.5,11.5,4.5,158))) {
        [void]$ball.Children.Add((New-Oval $f[0] $f[1] $f[2] $f[3] $f[4] $null $thread 1.7))
    }
    [void]$spin.Children.Add($ball)
    $loose = New-Object System.Windows.Shapes.Polyline
    $lp = New-Object System.Windows.Media.PointCollection
    foreach ($q in @(@(40,20),@(46,17),@(43,12),@(48,10))) { $lp.Add([System.Windows.Point]::new($q[0], $q[1])) }
    $loose.Points = $lp
    $loose.Stroke = $thread; $loose.StrokeThickness = 1.8
    $loose.StrokeStartLineCap = 'Round'; $loose.StrokeEndLineCap = 'Round'; $loose.StrokeLineJoin = 'Round'
    [void]$spin.Children.Add($loose)
    $rot = New-Object System.Windows.Media.RotateTransform(0)
    $rot.CenterX = 28; $rot.CenterY = 28
    $spin.RenderTransform = $rot
    [void]$sp.cv.Children.Add($spin)
    $sp.rot = $rot
    $sp
}

function New-Butterfly($size) {
    $sp = New-SpriteWindow 46 36 'Katzen-Schmetterling' $size
    $wingA = New-Brush '#9CB9EC'
    $wingB = New-Brush '#C4A4E8'
    $spot  = New-Brush '#EDF3FF'
    $dark  = New-Brush '#463F52'
    # Fuehler zuerst (liegen hinter den Fluegeln, ragen oben heraus)
    foreach ($a2 in @(@(22,12),@(17,3)), @(@(24,12),@(29,3))) {
        $ant = New-Object System.Windows.Shapes.Polyline
        $pc2 = New-Object System.Windows.Media.PointCollection
        foreach ($q in $a2) { $pc2.Add([System.Windows.Point]::new($q[0], $q[1])) }
        $ant.Points = $pc2; $ant.Stroke = $dark; $ant.StrokeThickness = 1.4
        $ant.StrokeStartLineCap = 'Round'; $ant.StrokeEndLineCap = 'Round'
        [void]$sp.cv.Children.Add($ant)
    }
    # linkes und rechtes Fluegelpaar, jeweils als Gruppe zum Schlagen
    $wgL = New-Object System.Windows.Controls.Canvas
    $wgL.Width = 46; $wgL.Height = 36
    [void]$wgL.Children.Add((New-Oval 13.5 16 9 6.5 -24 $wingA $null 0))
    [void]$wgL.Children.Add((New-Oval 16.5 26 6 4.8 -14 $wingB $null 0))
    [void]$wgL.Children.Add((New-Oval 11 14.5 2 1.8 0 $spot $null 0))
    $wgR = New-Object System.Windows.Controls.Canvas
    $wgR.Width = 46; $wgR.Height = 36
    [void]$wgR.Children.Add((New-Oval 32.5 16 9 6.5 24 $wingA $null 0))
    [void]$wgR.Children.Add((New-Oval 29.5 26 6 4.8 14 $wingB $null 0))
    [void]$wgR.Children.Add((New-Oval 35 14.5 2 1.8 0 $spot $null 0))
    $sL = New-Object System.Windows.Media.ScaleTransform(1, 1); $sL.CenterX = 23; $sL.CenterY = 18
    $sR = New-Object System.Windows.Media.ScaleTransform(1, 1); $sR.CenterX = 23; $sR.CenterY = 18
    $wgL.RenderTransform = $sL; $wgR.RenderTransform = $sR
    [void]$sp.cv.Children.Add($wgL); [void]$sp.cv.Children.Add($wgR)
    [void]$sp.cv.Children.Add((New-Oval 23 21 2.3 7.5 0 $dark $null 0))
    [void]$sp.cv.Children.Add((New-Oval 23 11.5 2.7 2.7 0 $dark $null 0))
    $sp.wl = $sL; $sp.wr = $sR
    $sp
}

function Spawn-Yarn {
    if ($G.cats.Count -eq 0) { return }
    if ($G.toy) { $G.toy.life = [Math]::Max($G.toy.life, 30); return }
    $ref = $G.cats[(Get-Random -Minimum 0 -Maximum $G.cats.Count)]
    $side = 1.0
    if ((Rnd 0 1) -lt 0.5) { $side = -1.0 }
    $wa = $ref.screen.WorkingArea
    $x = $ref.x + $side * 170 * $ref.pxs
    if ($x -lt $wa.Left + 40)  { $x = $wa.Left + 40;  $side = 1.0 }
    if ($x -gt $wa.Right - 40) { $x = $wa.Right - 40; $side = -1.0 }
    $G.toy = @{ sp = (New-Yarn $ref.size); x = $x; vx = (-$side * 200 * $ref.pxs)
                rot = 0.0; life = (Rnd 40 70); hits = 0 }
    $G.toyT = Rnd 150 320
}

function Despawn-Yarn {
    if ($G.toy) { $G.toy.sp.win.Close(); $G.toy = $null }
}

function Update-Yarn($dt) {
    if (-not $G.toy) { return }
    $ty = $G.toy
    $ty.life -= $dt
    if ($ty.life -le 0) { Despawn-Yarn; return }
    $ref = Get-RefCat $ty.x
    if (-not $ref) { return }
    $ty.x += $ty.vx * $dt
    $ty.vx = $ty.vx * [Math]::Pow(0.22, $dt)
    if ([Math]::Abs($ty.vx) -lt 1.5) { $ty.vx = 0 }
    $wa = $ref.screen.WorkingArea
    $r = 21 * $ref.pxs
    if ($ty.x -lt ($wa.Left + $r))  { $ty.x = $wa.Left + $r;  $ty.vx = [Math]::Abs($ty.vx) * 0.45 }
    if ($ty.x -gt ($wa.Right - $r)) { $ty.x = $wa.Right - $r; $ty.vx = -[Math]::Abs($ty.vx) * 0.45 }
    $ty.rot += ($ty.vx * $dt) * (2.6 / [Math]::Max(0.2, $ref.pxs))
    $ty.sp.rot.Angle = $ty.rot
    Set-SpritePos $ty.sp $ty.x ($ref.groundY - 16 * $ref.pxs)
    if ($ty.life -lt 1.5) { $ty.sp.win.Opacity = $ty.life / 1.5 }
}

function Spawn-Fly {
    if ($G.cats.Count -eq 0) { return }
    if ($G.fly) { $G.fly.life = [Math]::Max($G.fly.life, 25); return }
    $ref = $G.cats[0]
    $dir = 1.0
    if ((Rnd 0 1) -lt 0.5) { $dir = -1.0 }
    $G.fly = @{ sp = (New-Butterfly $ref.size); x = ($ref.x - $dir * 220 * $ref.pxs); y = 0.0; ph = 0.0
                vx = ($dir * (Rnd 26 46) * $ref.pxs); life = (Rnd 30 55); scared = 0.0 }
    $G.flyT = Rnd 200 420
}

function Despawn-Fly {
    if ($G.fly) { $G.fly.sp.win.Close(); $G.fly = $null }
}

function Update-Fly($dt) {
    if (-not $G.fly) { return }
    $fl = $G.fly
    $fl.life -= $dt
    if ($fl.life -le 0) { Despawn-Fly; return }
    $ref = Get-RefCat $fl.x
    if (-not $ref) { return }
    $fl.ph += $dt
    if ($fl.scared -gt 0) { $fl.scared -= $dt }
    $spd = 1.0
    if ($fl.scared -gt 0) { $spd = 3.2 }
    $fl.x += $fl.vx * $dt * $spd
    $wa = $ref.screen.WorkingArea
    if ($fl.x -lt ($wa.Left + 30))  { $fl.x = $wa.Left + 30;  $fl.vx = [Math]::Abs($fl.vx) }
    if ($fl.x -gt ($wa.Right - 30)) { $fl.x = $wa.Right - 30; $fl.vx = -[Math]::Abs($fl.vx) }
    # bleibt in Reichweite der naechsten Katze, sonst hat keine etwas davon
    $away = $fl.x - $ref.x
    if ($away -gt  430 * $ref.pxs -and $fl.vx -gt 0) { $fl.vx = -$fl.vx }
    if ($away -lt -430 * $ref.pxs -and $fl.vx -lt 0) { $fl.vx = -$fl.vx }
    $hi = 78 + 46 * [Math]::Sin($fl.ph * 0.62) + 11 * [Math]::Sin($fl.ph * 3.9)
    if ($fl.scared -gt 0) { $hi += 55 }
    $fl.y = $ref.groundY - $hi * $ref.pxs
    $flap = 0.22 + 0.78 * [Math]::Abs([Math]::Sin($fl.ph * 12))
    $fl.sp.wl.ScaleX = $flap; $fl.sp.wr.ScaleX = $flap
    Set-SpritePos $fl.sp $fl.x $fl.y
    if ($fl.life -lt 1.5) { $fl.sp.win.Opacity = $fl.life / 1.5 }
}

# ============================================================================
#  Bildschirm / Position
# ============================================================================
function Get-ScreenAt($px, $py) {
    [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new([int]$px, [int]$py))
}

function Update-Ground($c) {
    $probeY = [int]($c.groundY - 20)
    $scr = Get-ScreenAt $c.x $probeY
    $c.screen = $scr
    $c.groundY = [double]$scr.WorkingArea.Bottom
}

function Move-ToScreen($c, $scr, $offset) {
    $c.screen = $scr
    $c.x = $scr.WorkingArea.Left + $scr.WorkingArea.Width / 2.0 + $offset
    $c.groundY = [double]$scr.WorkingArea.Bottom
    $c.y = 0; $c.vy = 0
    Set-Chute $c $false
    Add-Particle $c 'dust' ($CAT_CX - 10) ($GROUND - 14)
    Add-Particle $c 'dust' ($CAT_CX + 6) ($GROUND - 10)
}

function Update-WindowPos($c) {
    $c.win.Left = ($c.x / $G.sx) - (($CAT_CX + $PAD) * $c.size)
    $c.win.Top  = ($c.groundY / $G.sy) - ($GROUND * $c.size) - $c.y
}

function Get-Partner($c) {
    foreach ($o in $G.cats) { if ($o -ne $c) { return $o } }
    $null
}

# ============================================================================
#  Zustandsmaschine
# ============================================================================
function Set-State($c, [string]$name, [double]$dur) {
    $c.state = $name
    $c.stateT = 0.0
    $c.stateDur = $dur
    $pn = $name
    if ($POSE_ALIAS.ContainsKey($name)) { $pn = $POSE_ALIAS[$name] }
    if ($POSES.ContainsKey($pn)) { $c.base = $POSES[$pn] }
    if (@('walk','run','chase','toychase','approach','flee','tagchase','pester') -contains $name) {
        $c.phase = Rnd 0 6.28
    }
}

function Am-I-Closest($c, $x) {
    $mine = [Math]::Abs($c.x - $x)
    foreach ($o in $G.cats) {
        if ($o -ne $c -and [Math]::Abs($o.x - $x) -lt $mine) { return $false }
    }
    $true
}

# Zustandswahl der Babykatzen: hauptsaechlich die Grossen aergern, dazwischen
# Zoomies, Anschleichen und kurze Nickerchen
function Next-KitState($c) {
    switch ($c.state) {
        'crouch'  { Set-State $c 'leap' 0.9; $c.vy = 265 * $c.size; $c.vx = 250 * $c.facing * $c.pxs; return }
        'sleep'   { Set-State $c 'shake' 1.1; return }
        'curl'    { Set-State $c 'yawn' 1.6; return }
        'shake'   { Set-State $c 'yawn' 1.6; return }
        'yawn'    { Set-State $c 'stretch' 1.7; return }
        'stretch' { Set-State $c 'walk' (Rnd 1.5 3.5); return }
    }
    if ($G.away) {
        if ((Rnd 0 1) -lt 0.6) { Set-State $c 'sleep' 9999 } else { Set-State $c 'curl' 9999 }
        return
    }
    if ($G.toy -and $G.toy.life -gt 4 -and (Rnd 0 1) -lt 0.5) { Set-State $c 'toychase' (Rnd 3 7); return }
    $r = Rnd 0 1
    if ($r -lt 0.42 -and $G.cats.Count -gt 0) {
        # such dir eine Grosse aus und geh ihr auf die Nerven
        $c.target = $G.cats[(Get-Random -Minimum 0 -Maximum $G.cats.Count)]
        Set-State $c 'pester' (Rnd 8 16)
    }
    elseif ($r -lt 0.51) { Set-State $c 'run'     (Rnd 2 3.5) }
    elseif ($r -lt 0.55) { Set-State $c 'hop'     (Rnd 1.8 2.8) }
    elseif ($r -lt 0.65) { Set-State $c 'crouch'  (Rnd 0.6 1.1) }
    elseif ($r -lt 0.75) { Set-State $c 'walk'    (Rnd 3 7) }
    elseif ($r -lt 0.82) { Set-State $c 'meow'    (Rnd 1.4 2.4) }
    elseif ($r -lt 0.89) { Set-State $c 'roll'    (Rnd 4 8) }
    elseif ($r -lt 0.95) { Set-State $c 'sit'     (Rnd 3 6) }
    else                 { Set-State $c 'scratch' (Rnd 1.8 3) }
}

function Next-State($c) {
    if ($c.kit) { Next-KitState $c; return }
    if ($c.chase) { Set-State $c 'chase' (Rnd 5 11); return }

    # feste Abfolgen: aus dem Schlaf kommt Gaehnen und Strecken, usw.
    switch ($c.state) {
        'crouch' {
            Set-State $c 'leap' 0.9
            $c.vy = 265 * $c.size
            $c.vx = 250 * $c.facing * $c.pxs
            return
        }
        'sleep'   { if ((Rnd 0 1) -lt 0.55) { Set-State $c 'curl' (Rnd 20 50) } else { Set-State $c 'shake' 1.1 }; return }
        'curl'    { if ((Rnd 0 1) -lt 0.5) { Set-State $c 'shake' 1.1 } else { Set-State $c 'yawn' 1.6 }; return }
        'shake'   { Set-State $c 'yawn' 1.6; return }
        'yawn'    { Set-State $c 'stretch' 1.7; return }
        'stretch' { Set-State $c 'arch' (Rnd 1.6 2.6); return }
        'arch'    { Set-State $c 'walk' (Rnd 6 14); return }
        'scratch' { Set-State $c 'sit' (Rnd 4 8); return }
        'roll'    { Set-State $c 'sit' (Rnd 4 8); return }
        'meow'    { Set-State $c 'sit' (Rnd 4 8); return }
        'wave'    { Set-State $c 'sit' (Rnd 4 8); return }
        'beg'     { Set-State $c 'sit' (Rnd 4 8); return }
        'dig'     { Set-State $c 'sniff' (Rnd 4 8); return }
        'sniff'   { Set-State $c 'walk' (Rnd 5 10); return }
        'edge'    { $c.facing = -$c.facing; Set-State $c 'walk' (Rnd 6 14); return }
        # --- neue Aktivitaeten ---
        'pet'     { $rp = Rnd 0 1; if ($rp -lt 0.55) { Set-State $c 'purr' (Rnd 4 7); return } elseif ($rp -lt 0.8) { Set-State $c 'hop' (Rnd 2.0 3.0); return } }
        'purr'    { Set-State $c 'sit' (Rnd 3 6); return }
        'blink'   { Set-State $c 'sit' (Rnd 3 6); return }
        'hop'     { if ($G.fly) { Set-State $c 'watch' (Rnd 3 6) } else { Set-State $c 'sit' (Rnd 3 6) }; return }
        'tilt'    { if ((Rnd 0 1) -lt 0.3) { Set-State $c 'meow' (Rnd 1.6 3) } else { Set-State $c 'sit' (Rnd 3 6) }; return }
        'bunt'    { if ((Rnd 0 1) -lt 0.6) { Set-State $c 'purr' (Rnd 3.5 6) } else { Set-State $c 'sit' (Rnd 3 6) }; return }
        'loaf'    { if ((Rnd 0 1) -lt 0.3) { Set-State $c 'stretch' 2.2 } else { Set-State $c 'sit' (Rnd 4 8) }; return }
        'wiggle'  {
            # nach dem Popo-Wackeln: Absprung, etwas kraeftiger als aus der Hocke
            Set-State $c 'leap' 0.9
            $c.vy = 290 * $c.size
            $c.vx = 270 * $c.facing * $c.pxs
            if ($G.fly) { $G.fly.scared = 1.8 }
            return
        }
        'bat'     {
            if ($G.toy) { Set-State $c 'toychase' (Rnd 3 8) } else { Set-State $c 'sit' (Rnd 2 4) }
            return
        }
        'toychase' { if (-not $G.toy) { Set-State $c 'idle' (Rnd 1.5 3); return } }
        'watch'    { if (-not $G.fly) { Set-State $c 'sit' (Rnd 2 4); return } }
        'land'     {
            if ($G.toy -and (Am-I-Closest $c $G.toy.x)) { Set-State $c 'toychase' (Rnd 3 7); return }
            if ((Rnd 0 1) -lt 0.45) { Set-State $c 'shake' 1.1; return }
        }
    }

    # Niemand am Rechner: einschlafen und schlafen bleiben, bis jemand zurueckkommt
    # (Update-Housekeeping weckt sie dann mit 'shake')
    if ($G.away) {
        if ((Rnd 0 1) -lt 0.6) { Set-State $c 'sleep' 9999 } else { Set-State $c 'curl' 9999 }
        return
    }

    # Spielzeug geht vor - aber nur fuer die Katze, die naeher dran ist
    if ($G.toy -and $G.toy.life -gt 4 -and (Am-I-Closest $c $G.toy.x) -and (Rnd 0 1) -lt 0.85) {
        Set-State $c 'toychase' (Rnd 4 9); return
    }
    if ($G.fly -and $G.fly.life -gt 4 -and (Rnd 0 1) -lt 0.7) { Set-State $c 'watch' (Rnd 3 7); return }

    # am Bildschirmrand richtet sie sich manchmal auf und kratzt daran
    $wa = $c.screen.WorkingArea
    if (($c.x -lt ($wa.Left + 80 * $c.pxs)) -and (Rnd 0 1) -lt 0.25) {
        $c.facing = -1.0; Set-State $c 'edge' (Rnd 2.5 5); return
    }
    if (($c.x -gt ($wa.Right - 80 * $c.pxs)) -and (Rnd 0 1) -lt 0.25) {
        $c.facing = 1.0; Set-State $c 'edge' (Rnd 2.5 5); return
    }

    # Mauszeiger in der Naehe: winken, betteln, Kopf schief legen, Katzenkuss oder Koepfchen geben
    $cp = [System.Windows.Forms.Cursor]::Position
    if (-not $G.away -and [Math]::Abs($cp.X - $c.x) -lt 260 * $c.pxs -and (Rnd 0 1) -lt 0.2) {
        if ($cp.X -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 }
        $rc = Rnd 0 1
        if     ($rc -lt 0.22) { Set-State $c 'wave'  (Rnd 3 5) }
        elseif ($rc -lt 0.42) { Set-State $c 'beg'   (Rnd 3 5) }
        elseif ($rc -lt 0.62) { Set-State $c 'tilt'  (Rnd 2.5 4) }
        elseif ($rc -lt 0.82) { Set-State $c 'blink' (Rnd 5 8) }
        else                  { Set-State $c 'bunt'  (Rnd 4 7) }
        return
    }

    $r = Get-Random -Minimum 0.0 -Maximum 1.0
    if     ($r -lt 0.15) { Set-State $c 'walk'    (Rnd 6 16) }
    elseif ($r -lt 0.21) { Set-State $c 'sit'     (Rnd 8 20) }
    elseif ($r -lt 0.26) { Set-State $c 'loaf'    (Rnd 10 25) }
    elseif ($r -lt 0.32) { Set-State $c 'groom'   (Rnd 7 12) }
    elseif ($r -lt 0.36) { Set-State $c 'scratch' (Rnd 2.5 4.5) }
    elseif ($r -lt 0.41) { Set-State $c 'idle'    (Rnd 5 12) }
    elseif ($r -lt 0.45) { Set-State $c 'run'     (Rnd 1.5 3) }
    elseif ($r -lt 0.49) { Set-State $c 'crouch'  (Rnd 0.9 1.6) }
    elseif ($r -lt 0.53) { Set-State $c 'wiggle'  (Rnd 1.2 1.9) }
    elseif ($r -lt 0.56) { Set-State $c 'roll'    (Rnd 5 10) }
    elseif ($r -lt 0.60) { Set-State $c 'meow'    (Rnd 1.6 3) }
    elseif ($r -lt 0.64) { Set-State $c 'stretch' 2.2 }
    elseif ($r -lt 0.68) { Set-State $c 'yawn'    2.0 }
    elseif ($r -lt 0.71) { Set-State $c 'hop'     (Rnd 2.0 3.2) }
    elseif ($r -lt 0.75) { Set-State $c 'wave'    (Rnd 3 5) }
    elseif ($r -lt 0.80) { Set-State $c 'sniff'   (Rnd 5 10) }
    elseif ($r -lt 0.84) { Set-State $c 'dig'     (Rnd 3 5) }
    elseif ($r -lt 0.87) { Set-State $c 'arch'    (Rnd 2 3.5) }
    elseif ($r -lt 0.90) { Set-State $c 'beg'     (Rnd 3 5) }
    elseif ($r -lt 0.93) { Set-State $c 'blink'   (Rnd 5 8) }
    else                 { Set-State $c 'sleep'   (Rnd 30 90) }
}

function Set-Chute($c, [bool]$on) {
    if ($c.chuteOn -eq $on) { return }
    $c.chuteOn = $on
    if ($on) { $c.chuteG.Visibility = 'Visible' }
    else { $c.chuteG.Visibility = 'Collapsed'; $c.chuteRot.Angle = 0 }
}

function Do-Land($c) {
    Set-Chute $c $false
    $c.y = 0; $c.vy = 0; $c.vx = 0
    Set-State $c 'land' 0.34
    Add-Particle $c 'dust' ($CAT_CX - 16) ($GROUND - 12)
    Add-Particle $c 'dust' ($CAT_CX + 12) ($GROUND - 8)
    Add-Particle $c 'dust' ($CAT_CX - 2)  ($GROUND - 16)
}

# Reaktion der Grossen, wenn ein Kaetzchen nach ihnen patscht: Buckel machen,
# genervt wegrennen, schuetteln, Protest-Miau - oder stoisch ignorieren
function Annoy-Adult($adult, $kit) {
    if ($adult.dragging) { return }
    if (@('drag','pet','fall','leap') -contains $adult.state) { return }
    if ($adult.locked) { Abort-Social }
    $away = 1.0
    if ($kit.x -gt $adult.x) { $away = -1.0 }
    $r = Rnd 0 1
    if     ($r -lt 0.30) { $adult.facing = -$away; Set-State $adult 'arch' (Rnd 1.4 2.4) }
    elseif ($r -lt 0.55) { $adult.facing = $away;  Set-State $adult 'run'  (Rnd 0.9 1.8) }
    elseif ($r -lt 0.72) { Set-State $adult 'shake' 1.1 }
    elseif ($r -lt 0.88) { $adult.facing = -$away; Set-State $adult 'meow' (Rnd 1.2 2) }
}

function Update-Behaviour($c, $dt) {
    $c.stateT += $dt

    # Blinken - wenn sie gerade zum Mauszeiger schaut, auch mal ein langsames
    # Blinzeln (bei Katzen ein Zeichen von Zuneigung)
    $c.blinkT -= $dt
    if ($c.blinkT -le 0) {
        $c.blinkDur = 0.16
        if ([Math]::Abs($c.look) -gt 4 -and (Rnd 0 1) -lt 0.35) { $c.blinkDur = 0.85 }
        if ($c.state -eq 'loaf') { $c.blinkDur = 1.2 }     # im Katzenbrot immer zufrieden-langsam
        $c.blink = $c.blinkDur
        $c.blinkT = Rnd 1.6 6.5
    }
    if ($c.blink -gt 0) { $c.blink -= $dt }
    if ($c.swipe -gt 0) { $c.swipe -= $dt }
    # Ohrenzucken alle paar Sekunden
    $c.earT -= $dt
    if ($c.earT -le 0) { $c.earT = Rnd 3 9; $c.earFlick = 0.3 }
    if ($c.earFlick -gt 0) { $c.earFlick -= $dt }

    switch ($c.state) {
        'walk'  { $c.vx = 64 * $c.facing * $c.pxs; $c.phase += $dt * 7.6 * (Gait-Factor $c) }
        'run'   { $c.vx = 205 * $c.facing * $c.pxs; $c.phase += $dt * 15.5 * (Gait-Factor $c) }
        'crouch' { $c.vx = 0 }
        'chase' {
            $cur = [System.Windows.Forms.Cursor]::Position
            $catScr = $c.screen
            $curScr = Get-ScreenAt $cur.X $cur.Y
            if ($null -ne $catScr -and $curScr.DeviceName -ne $catScr.DeviceName) {
                # Maus auf anderem Monitor: an den Rand rennen, dann hinueberspringen
                $tx = if ($cur.X -gt $c.x) { $catScr.WorkingArea.Right - 40 } else { $catScr.WorkingArea.Left + 40 }
                $dx = $tx - $c.x
                $c.facing = if ($dx -ge 0) { 1.0 } else { -1.0 }
                $c.vx = [Math]::Max(-235 * $c.pxs, [Math]::Min(235 * $c.pxs, $dx * 3.4))
                $c.phase += $dt * (9 + [Math]::Abs($c.vx) * 0.05)
                if ([Math]::Abs($dx) -lt 45) {
                    $c.edgeT += $dt
                    if ($c.edgeT -gt 0.5) { Move-ToScreen $c $curScr 0; $c.edgeT = 0 }
                } else { $c.edgeT = 0 }
            } else {
                $dx = $cur.X - $c.x
                if ([Math]::Abs($dx) -gt 8) { $c.facing = if ($dx -ge 0) { 1.0 } else { -1.0 } }
                if ([Math]::Abs($dx) -gt 48) {
                    $c.vx = [Math]::Max(-240 * $c.pxs, [Math]::Min(240 * $c.pxs, $dx * 3.4))
                    $c.phase += $dt * (8 + [Math]::Abs($c.vx) * 0.055)
                } else {
                    $c.vx = $c.vx * 0.75
                    if ($c.swipe -le 0) { $c.swipe = 0.5 }
                    # Maus deutlich ueber dem Boden -> Sprung danach
                    $curYdip = $cur.Y / $G.sy
                    $catFeet = ($c.groundY / $G.sy)
                    if (($catFeet - $curYdip) -gt (95 * $c.size) -and (Rnd 0 1) -lt 0.06) {
                        Set-State $c 'leap' 0.9
                        $c.vy = 300 * $c.size
                        $c.vx = 90 * $c.facing * $c.pxs
                    }
                }
            }
        }
        'toychase' {
            if (-not $G.toy) {
                $c.vx = 0; Set-State $c 'sit' (Rnd 1 2)     # Spielzeug weg: nicht ins Leere starren
            } else {
                $dxt = $G.toy.x - $c.x
                if ([Math]::Abs($dxt) -gt 8) {
                    if ($dxt -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                }
                if ([Math]::Abs($dxt) -gt 46 * $c.pxs) {
                    $c.vx = [Math]::Max(-215 * $c.pxs, [Math]::Min(215 * $c.pxs, $dxt * 3.2))
                    $c.phase += $dt * (8 + [Math]::Abs($c.vx) * 0.055)
                } else {
                    $c.vx = 0
                    Set-State $c 'bat' (Rnd 1.3 2.8)
                    $c.batNext = 0.35
                }
            }
        }
        'bat' {
            $c.vx = 0
            if (-not $G.toy) {
                Set-State $c 'sit' (Rnd 1.5 3)
            } else {
                $c.batNext -= $dt
                if ($c.batNext -le 0) {
                    $c.batNext = 0.62
                    $dxb = $G.toy.x - $c.x
                    if ([Math]::Abs($dxb) -lt 72 * $c.pxs) {
                        $G.toy.vx = $c.facing * (Rnd 190 330) * $c.pxs
                        $G.toy.hits += 1
                        Add-Particle $c 'dust' ($CAT_CX + 36) ($GROUND - 8)
                    } else {
                        Set-State $c 'toychase' (Rnd 3 7)
                    }
                }
            }
        }
        'watch' {
            $c.vx = 0
            if ($G.fly) {
                $dxf = $G.fly.x - $c.x
                if ([Math]::Abs($dxf) -gt 26 * $c.pxs) {
                    if ($dxf -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                }
                # tief genug und nah dran? dann Sprung nach dem Schmetterling
                $hgt = ($c.groundY - $G.fly.y) / [Math]::Max(0.2, $c.pxs)
                if ($hgt -lt 112 -and [Math]::Abs($dxf) -lt 130 * $c.pxs -and (Rnd 0 1) -lt 0.04) {
                    Set-State $c 'leap' 0.9
                    $c.vy = 325 * $c.size
                    $c.vx = [Math]::Max(-160 * $c.pxs, [Math]::Min(160 * $c.pxs, $dxf * 2.2))
                    $G.fly.scared = 1.8
                }
            }
        }
        # --- neue Aktivitaeten -----------------------------------------------
        'loaf'   { $c.vx = 0 }
        'tilt'   {
            $c.vx = 0
            # zum Mauszeiger drehen, falls er hinter ihr ist (kleine Totzone)
            $cpt = [System.Windows.Forms.Cursor]::Position
            if ([Math]::Abs($cpt.X - $c.x) -gt 30 * $c.pxs) { if ($cpt.X -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 } }
        }
        'hop' {
            # Freudenhopser: bei jeder zweiten Landung ein Staubwoelkchen, manchmal ein Herzchen
            $c.vx = 0
            $hp = 0.72
            if ($c.stateT -gt 0.5 -and (($c.stateT % $hp) -lt (($c.stateT - $dt) % $hp))) {
                $c.digT += 1
                if (($c.digT % 2) -eq 0) {
                    Add-Particle $c 'dust' ($CAT_CX - 14) ($GROUND - 8)
                    Add-Particle $c 'dust' ($CAT_CX + 14) ($GROUND - 8)
                }
                if ((Rnd 0 1) -lt 0.3) { Add-Particle $c 'heart' (Rnd 118 148) 86 }
            }
        }
        'bunt' {
            # Koepfchen geben: gemuetlich zum Mauszeiger tapsen und dort mit der
            # Stirn anstupsen; ist der Zeiger weit weg oder niemand da, hinsetzen
            $cur = [System.Windows.Forms.Cursor]::Position
            $dxc = $cur.X - $c.x
            if ($G.away -or $c.locked -or [Math]::Abs($dxc) -gt 420 * $c.pxs) { $c.vx = 0; Set-State $c 'sit' (Rnd 2 4) }
            else {
                if ([Math]::Abs($dxc) -gt 12) { if ($dxc -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 } }
                if ([Math]::Abs($dxc) -gt 58 * $c.pxs) {
                    $c.vx = [Math]::Max(-46 * $c.pxs, [Math]::Min(46 * $c.pxs, $dxc * 1.2))
                    $c.phase += $dt * 5.6
                } else {
                    $c.vx = $c.vx * 0.7
                    $c.heartT -= $dt
                    if ($c.heartT -le 0) { $c.heartT = Rnd 1.2 2.0; Add-Particle $c 'heart' (Rnd 132 156) 86 }
                }
            }
        }
        'blink' {
            # Katzenkuss: genau wenn die Augen ganz zu sind, steigt ein Herzchen auf
            $c.vx = 0
            if ($c.heartT -gt 0) { $c.heartT -= $dt }
            if ([Math]::Sin($c.stateT * 1.7 + 0.4) -gt 0.97 -and $c.heartT -le 0) {
                $c.heartT = 2.0; Add-Particle $c 'heart' (Rnd 126 150) 88
            }
        }
        'purr' {
            $c.vx = 0
            $c.heartT -= $dt
            if ($c.heartT -le 0) { $c.heartT = Rnd 1.8 3.0; Add-Particle $c 'heart' (Rnd 112 148) 90 }
        }
        'wiggle' { $c.vx = 0 }
        # --- Babykatzen: die Grossen aergern -------------------------------
        'pester' {
            $tgt = $c.target
            if (-not $tgt -or -not $G.cats.Contains($tgt)) { $c.vx = 0; Set-State $c 'sit' (Rnd 1 2) }
            else {
                if ($c.screen -and $tgt.screen -and $c.screen.DeviceName -ne $tgt.screen.DeviceName) {
                    Move-ToScreen $c $tgt.screen (Rnd -80 80)
                }
                $dxk = $tgt.x - $c.x
                if ([Math]::Abs($dxk) -gt 8) {
                    if ($dxk -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                }
                if ([Math]::Abs($dxk) -gt 60 * $tgt.pxs) {
                    $c.vx = [Math]::Max(-230 * $c.pxs, [Math]::Min(230 * $c.pxs, $dxk * 3.4))
                    $c.phase += $dt * (9 + [Math]::Abs($c.vx) * 0.06)
                } else {
                    $c.vx = 0
                    Set-State $c 'kitbat' (Rnd 1.6 3.2)
                    $c.batNext = 0.3
                }
            }
        }
        'kitbat' {
            $c.vx = 0
            $tgt = $c.target
            if (-not $tgt -or -not $G.cats.Contains($tgt)) { Set-State $c 'sit' (Rnd 1 2) }
            else {
                $dxk = $tgt.x - $c.x
                if ([Math]::Abs($dxk) -gt 8) {
                    if ($dxk -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                }
                $c.batNext -= $dt
                if ($c.batNext -le 0) {
                    $c.batNext = 0.6
                    if ([Math]::Abs($dxk) -lt 85 * $tgt.pxs) {
                        Add-Particle $c 'dust' ($CAT_CX + 34) ($GROUND - 10)
                        if ((Rnd 0 1) -lt 0.3) { Add-Particle $c 'heart' (Rnd 120 148) 88 }
                        Annoy-Adult $tgt $c
                    } else {
                        Set-State $c 'pester' (Rnd 4 8)
                    }
                }
            }
        }
        # --- Miteinander -------------------------------------------------
        'approach' {
            $dxa = $c.meetX - $c.x
            if ([Math]::Abs($dxa) -gt 10 * $c.pxs) {
                if ($dxa -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                $c.vx = [Math]::Max(-150 * $c.pxs, [Math]::Min(150 * $c.pxs, $dxa * 2.4))
                $c.phase += $dt * (7 + [Math]::Abs($c.vx) * 0.05)
            } else {
                $c.vx = 0
                $p = Get-Partner $c
                if ($p) { if ($p.x -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 } }
            }
        }
        'greet' {
            $c.vx = 0
            $p = Get-Partner $c
            if ($p) { if ($p.x -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 } }
        }
        'flee' {
            $p = Get-Partner $c
            $away = 1.0
            if ($p -and $c.x -lt $p.x) { $away = -1.0 }
            $wa2 = $c.screen.WorkingArea
            # an der Wand ausweichen statt sich festzurennen
            if ($away -lt 0 -and $c.x -lt ($wa2.Left + 130 * $c.pxs))  { $away = 1.0 }
            if ($away -gt 0 -and $c.x -gt ($wa2.Right - 130 * $c.pxs)) { $away = -1.0 }
            $c.facing = $away
            $c.vx = 200 * $away * $c.pxs
            $c.phase += $dt * 15.5
        }
        'tagchase' {
            $p = Get-Partner $c
            if ($p) {
                $dxp = $p.x - $c.x
                if ([Math]::Abs($dxp) -gt 10) {
                    if ($dxp -ge 0) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                }
                $c.vx = [Math]::Max(-215 * $c.pxs, [Math]::Min(215 * $c.pxs, $dxp * 3.0))
                $c.phase += $dt * (9 + [Math]::Abs($c.vx) * 0.05)
            }
        }
        'nuzzle' {
            $c.vx = 0
            $p = Get-Partner $c
            if ($p) { if ($p.x -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 } }
        }
        'sniff' {
            # schnuppert sich im Schneckentempo vorwaerts
            $c.vx = 24 * $c.facing * $c.pxs
            $c.phase += $dt * 3.4
        }
        'dig' {
            $c.vx = 0
            $c.digT -= $dt
            if ($c.digT -le 0) {
                $c.digT = Rnd 0.22 0.4
                Add-Particle $c 'dust' (Rnd ($CAT_CX + 20) ($CAT_CX + 46)) ($GROUND - 6)
            }
        }
        'rub' {
            $p = Get-Partner $c
            if ($p) {
                if ($p.x -ge $c.x) { $c.facing = 1.0 } else { $c.facing = -1.0 }
                # ganz langsam an die Freundin herandruecken
                $gap = [Math]::Abs($p.x - $c.x)
                if ($gap -gt 62 * $c.pxs) { $c.vx = 22 * $c.facing * $c.pxs } else { $c.vx = 0 }
            } else { $c.vx = 0 }
        }
        'edge' { $c.vx = 0 }
        'leap' { }
        'fall' { }
        'drag' { }
        default { $c.vx = $c.vx * 0.8 }
    }

    # Kopf verfolgt ein Ziel: Schmetterling, Freundin oder Mauszeiger
    $ltx = $null; $lty = 0.0
    if ($c.state -eq 'watch' -and $G.fly) {
        $ltx = $G.fly.x; $lty = $G.fly.y
    } elseif (@('greet','nuzzle') -contains $c.state) {
        $p = Get-Partner $c
        if ($p) { $ltx = $p.x; $lty = $p.groundY - 70 * $p.pxs }
    } elseif (@('sit','idle','meow','loaf','tilt','blink','purr') -contains $c.state) {
        $cp = [System.Windows.Forms.Cursor]::Position
        if ([Math]::Abs($cp.X - $c.x) -lt 520 * $c.pxs) { $ltx = [double]$cp.X; $lty = [double]$cp.Y }
    }
    if ($null -ne $ltx) {
        $headY = $c.groundY - 70 * $c.pxs
        $dxl = ($ltx - $c.x) * $c.facing
        $ang = [Math]::Atan2(($lty - $headY), [Math]::Max(34 * $c.pxs, [Math]::Abs($dxl))) * 57.2958
        $tgt = [Math]::Max(-40, [Math]::Min(30, $ang))
        $c.look += ($tgt - $c.look) * [Math]::Min(1, $dt * 4)
    } else {
        $c.look += (0 - $c.look) * [Math]::Min(1, $dt * 3)
    }
    $c.lookY = $c.look * 0.05

    # Z-Z-Z beim Schlafen
    if ($c.state -eq 'sleep' -or $c.state -eq 'curl') {
        $c.zT -= $dt
        if ($c.zT -le 0) { $c.zT = Rnd 0.9 1.5; Add-Particle $c 'z' (Rnd 132 152) 84 }
    }
    # Herzchen beim Streicheln
    if ($c.state -eq 'pet') {
        $c.heartT -= $dt
        if ($c.heartT -le 0) { $c.heartT = Rnd 0.35 0.7; Add-Particle $c 'heart' (Rnd 108 148) 92 }
    }
    # "miau"
    if ($c.state -eq 'meow') {
        $c.meowT -= $dt
        if ($c.meowT -le 0) { $c.meowT = Rnd 0.9 1.5; Add-Particle $c 'meow' 144 80 }
    }

    if (-not $c.locked -and -not $Pose -and (@('leap','fall','drag') -notcontains $c.state)) {
        if ($c.stateT -ge $c.stateDur) { Next-State $c }
    }
}

# Schrittzyklus folgt der tatsaechlich angewandten Geschwindigkeit (weiches Anfahren)
function Gait-Factor($c) { [Math]::Min(1.0, [Math]::Abs($c.svx) / [Math]::Max(1.0, [Math]::Abs($c.vx))) }

function Update-Physics($c, $dt) {
    if ($c.state -eq 'drag') {
        $cur = [System.Windows.Forms.Cursor]::Position
        $c.x = [double]$cur.X + $c.gripDX; $c.svx = 0
        $scr = Get-ScreenAt $cur.X $cur.Y
        $c.screen = $scr
        $c.groundY = [double]$scr.WorkingArea.Bottom
        $topDip = ($cur.Y / $G.sy) - $c.gripDY
        $c.y = ($c.groundY / $G.sy) - ($GROUND * $c.size) - $topDip
        if ($c.y -lt 0) { $c.y = 0 }
        return
    }

    if ($c.state -eq 'leap' -or $c.state -eq 'fall') {
        $c.vy -= 1750 * $dt * $c.size
        if ($c.chuteOn) {
            # der Schirm bremst auf gemuetliche Sinkgeschwindigkeit und pendelt
            $term = -110 * $c.size
            if ($c.vy -lt $term) { $c.vy = $term }
            $c.x += [Math]::Sin($c.t * 1.7) * 30 * $c.pxs * $dt
            $c.chuteRot.Angle = 7 * [Math]::Sin($c.t * 1.7)
        }
        $c.y += $c.vy * $dt
        $c.x += $c.vx * $dt; $c.svx = $c.vx
        if ($c.y -le 0) { Do-Land $c }
    } else {
        # weich anfahren und abbremsen: die angewandte Geschwindigkeit folgt der Soll-Geschwindigkeit
        $c.svx += ($c.vx - $c.svx) * [Math]::Min(1.0, $dt * 7)
        $c.x += $c.svx * $dt
        if ($c.y -gt 0.5) { Set-State $c 'fall' 5; $c.vy = 0 }
    }

    Update-Ground $c
    $wa = $c.screen.WorkingArea
    $margin = 34 * $c.pxs
    if ($c.x -lt ($wa.Left + $margin)) {
        $c.x = $wa.Left + $margin
        if ($c.state -ne 'chase') { $c.facing = 1.0 } else { $c.vx = 0 }
    }
    if ($c.x -gt ($wa.Right - $margin)) {
        $c.x = $wa.Right - $margin
        if ($c.state -ne 'chase') { $c.facing = -1.0 } else { $c.vx = 0 }
    }

    # beim normalen Herumlaufen nicht in die andere hineinlaufen
    if (@('walk','run','sniff') -contains $c.state) {
        $p = Get-Partner $c
        if ($p -and $p.screen -and $c.screen.DeviceName -eq $p.screen.DeviceName) {
            $gap = $p.x - $c.x
            if ([Math]::Abs($gap) -lt 48 * $c.pxs -and ($gap * $c.facing) -gt 0) {
                $c.facing = -$c.facing
            }
        }
    }
}

# ============================================================================
#  Sozialverhalten: begruessen, fangen spielen, zusammen sitzen
# ============================================================================
$SOC_BUSY = @('drag','pet','fall','leap','land','toychase','bat','chase','bunt','hop','purr')

function Cat-Busy($c) { $c.chase -or ($SOC_BUSY -contains $c.state) }

function Abort-Social {
    $s = $G.soc
    if ($s.mode -eq 'none') { return }
    foreach ($c in $G.cats) {
        $c.locked = $false
        if (@('approach','greet','flee','tagchase','nuzzle','rub') -contains $c.state) {
            Set-State $c 'idle' (Rnd 1.5 3)
        } elseif ($c.stateDur -ge 99) {
            # Dauerzustaende aus 'snuggle'/'nap' (sit 99, sleep/curl 999) aufloesen,
            # sonst bleibt die Partnerin minutenlang eingefroren
            if (@('sleep','curl') -contains $c.state) { Set-State $c 'shake' 1.1 }
            else { Set-State $c 'sit' (Rnd 1.5 3) }
        }
    }
    $s.mode = 'none'; $s.t = 0.0; $s.cool = Rnd 90 180
}

function End-Social {
    $s = $G.soc
    foreach ($c in $G.cats) {
        $c.locked = $false
        Set-State $c 'sit' (Rnd 2 4)
    }
    $s.mode = 'none'; $s.t = 0.0; $s.cool = Rnd 100 220
}

function Update-Social($dt) {
    $s = $G.soc
    if ($G.cats.Count -lt 2) {
        if ($s.mode -ne 'none') { $s.mode = 'none' }
        return
    }
    $a = $G.cats[0]; $b = $G.cats[1]
    $s.t += $dt

    if ($s.mode -ne 'none') {
        # gezogen, gestreichelt oder auf verschiedenen Monitoren -> abbrechen
        if ($a.dragging -or $b.dragging -or $a.state -eq 'pet' -or $b.state -eq 'pet' -or
            $a.screen.DeviceName -ne $b.screen.DeviceName) {
            Abort-Social
            return
        }
    }

    switch ($s.mode) {
        'none' {
            $s.cool -= $dt
            if ($s.cool -le 0 -and -not $G.away -and -not (Cat-Busy $a) -and -not (Cat-Busy $b) -and
                $a.screen.DeviceName -eq $b.screen.DeviceName -and
                [Math]::Abs($a.x - $b.x) -lt 2400 * $a.pxs) {
                # Treffpunkt in der Mitte, jede geht auf ihre Seite
                $mid = ($a.x + $b.x) / 2.0
                $left = $a; $right = $b
                if ($b.x -lt $a.x) { $left = $b; $right = $a }
                $left.meetX  = $mid - ($NOSE_DX + 2) * $left.pxs
                $right.meetX = $mid + ($NOSE_DX + 2) * $right.pxs
                foreach ($c in @($a, $b)) { $c.locked = $true; Set-State $c 'approach' 99 }
                $s.mode = 'meet'; $s.t = 0.0
            }
        }
        'meet' {
            $near = [Math]::Abs($a.x - $b.x) -lt (($NOSE_DX * 2 + 16) * $a.pxs)
            $done = ([Math]::Abs($a.meetX - $a.x) -lt 14 * $a.pxs) -and
                    ([Math]::Abs($b.meetX - $b.x) -lt 14 * $b.pxs)
            if ($near -or $done -or $s.t -gt 20) {
                foreach ($c in @($a, $b)) { Set-State $c 'greet' 99 }
                $s.mode = 'greet'; $s.t = 0.0; $s.heartT = 0.6
            }
        }
        'greet' {
            $s.heartT -= $dt
            if ($s.heartT -le 0) {
                $s.heartT = Rnd 0.7 1.3
                $who = $a
                if ((Rnd 0 1) -lt 0.5) { $who = $b }
                Add-Particle $who 'heart' (Rnd 120 148) 88
            }
            if ($s.t -gt 2.6) {
                $pick = Rnd 0 1
                if ($pick -lt 0.38) {
                    # Fangen spielen
                    $s.runner = 0
                    if ((Rnd 0 1) -lt 0.5) { $s.runner = 1 }
                    $s.swaps = 0
                    $s.dur = Rnd 9 16
                    Set-State $G.cats[$s.runner] 'flee' 99
                    Set-State $G.cats[1 - $s.runner] 'tagchase' 99
                    $s.mode = 'tag'; $s.t = 0.0
                } elseif ($pick -lt 0.62) {
                    # zusammen sitzen
                    $s.dur = Rnd 15 35
                    foreach ($c in @($a, $b)) { Set-State $c 'sit' 99 }
                    $s.mode = 'snuggle'; $s.t = 0.0; $s.heartT = Rnd 2 5
                } elseif ($pick -lt 0.81) {
                    # aneinander schmiegen
                    $s.dur = Rnd 5 9
                    foreach ($c in @($a, $b)) { Set-State $c 'rub' 99 }
                    $s.mode = 'rub'; $s.t = 0.0; $s.heartT = 0.8
                } else {
                    # zusammen ein Nickerchen, Nase an Nase
                    $s.dur = Rnd 40 90
                    Set-State $a 'sleep' 999
                    Set-State $b 'curl' 999
                    $s.mode = 'nap'; $s.t = 0.0
                }
            }
        }
        'tag' {
            $run = $G.cats[$s.runner]
            $hunt = $G.cats[1 - $s.runner]
            if ([Math]::Abs($run.x - $hunt.x) -lt 52 * $hunt.pxs) {
                # erwischt: Rollen tauschen
                $s.runner = 1 - $s.runner
                $s.swaps += 1
                Add-Particle $hunt 'dust' ($CAT_CX + 20) ($GROUND - 10)
                Set-State $G.cats[$s.runner] 'flee' 99
                Set-State $G.cats[1 - $s.runner] 'tagchase' 99
            }
            if ($s.t -gt $s.dur -or $s.swaps -ge 5) {
                foreach ($c in @($a, $b)) { $c.locked = $false }
                Set-State $a 'sit' (Rnd 2 4)
                Set-State $b 'sit' (Rnd 2 4)
                $s.mode = 'none'; $s.t = 0.0; $s.cool = Rnd 100 220
            }
        }
        'rub' {
            $s.heartT -= $dt
            if ($s.heartT -le 0) {
                $s.heartT = Rnd 1.1 2.4
                $who = $a
                if ((Rnd 0 1) -lt 0.5) { $who = $b }
                Add-Particle $who 'heart' (Rnd 118 146) 86
            }
            if ($s.t -gt $s.dur) {
                if ((Rnd 0 1) -lt 0.5) {
                    $s.dur = Rnd 15 35
                    foreach ($c in @($a, $b)) { Set-State $c 'sit' 99 }
                    $s.mode = 'snuggle'; $s.t = 0.0; $s.heartT = Rnd 2 5
                } else { End-Social }
            }
        }
        'nap' {
            if ($s.t -gt $s.dur) {
                foreach ($c in @($a, $b)) { $c.locked = $false }
                Set-State $a 'shake' 1.1
                Set-State $b 'yawn' 1.6
                $s.mode = 'none'; $s.t = 0.0; $s.cool = Rnd 120 240
            }
        }
        'snuggle' {
            $s.heartT -= $dt
            if ($s.heartT -le 0) {
                $s.heartT = Rnd 3 7
                # eine putzt die andere
                $who = $a
                if ((Rnd 0 1) -lt 0.5) { $who = $b }
                if ($who.state -eq 'sit') { Set-State $who 'nuzzle' 99 }
                Add-Particle $who 'heart' (Rnd 118 146) 90
            }
            if ($s.t -gt ($s.dur * 0.55) -and $a.state -eq 'nuzzle') { Set-State $a 'sit' 99 }
            if ($s.t -gt ($s.dur * 0.75) -and $b.state -eq 'nuzzle') { Set-State $b 'sit' 99 }
            if ($s.t -gt $s.dur) { End-Social }
        }
    }
}

# ============================================================================
#  Pose anwenden
# ============================================================================
function Set-Tail($c, $ox, $oy, $a, $curl) {
    $ar = $a * [Math]::PI / 180.0
    $a2 = ($a + 55 * $curl) * [Math]::PI / 180.0
    $a3 = ($a + 112 * $curl) * [Math]::PI / 180.0
    $p0x = 54 + $ox; $p0y = 127 + $oy
    $p1x = $p0x - 20 * [Math]::Cos($ar);  $p1y = $p0y - 20 * [Math]::Sin($ar)
    $p2x = $p1x - 18 * [Math]::Cos($a2);  $p2y = $p1y - 18 * [Math]::Sin($a2)
    $p3x = $p2x - 15 * [Math]::Cos($a3);  $p3y = $p2y - 15 * [Math]::Sin($a3)
    for ($i = 0; $i -le 12; $i++) {
        $t = $i / 12.0; $u = 1 - $t
        $bx = $u*$u*$u*$p0x + 3*$u*$u*$t*$p1x + 3*$u*$t*$t*$p2x + $t*$t*$t*$p3x
        $by = $u*$u*$u*$p0y + 3*$u*$u*$t*$p1y + 3*$u*$t*$t*$p2y + $t*$t*$t*$p3y
        $pt = [System.Windows.Point]::new($bx, $by)
        $c.tailPts[$i] = $pt
        $c.tailPts2[$i] = $pt
    }
    [System.Windows.Controls.Canvas]::SetLeft($c.tailTip, $p3x - 9.1)
    [System.Windows.Controls.Canvas]::SetTop($c.tailTip, $p3y - 9.1)
}

function Get-AppliedPose($c, $dt) {
    $k = [Math]::Min(1.0, $dt * 9.0)      # weiche Ueberblendung zwischen Posen
    foreach ($key in $POSE_KEYS) {
        $c.pose[$key] = $c.pose[$key] + ($c.base[$key] - $c.pose[$key]) * $k
    }
    $a = $c.pose.Clone()
    $a.bflip = $c.base.bflip     # springt sofort, kein Zwischenwert
    $ph = $c.phase
    $t = $c.t
    $st = $c.state
    if ($POSE_ALIAS.ContainsKey($st)) { $st = $POSE_ALIAS[$st] }

    # Schrittzyklus: das Pfoetchen wandert waagerecht hin und her und hebt sich
    # dabei genau in der Vorwaertsphase. Vier Zeilen pro Gangart, keine Winkel.
    $step = {
        param($amp, $lift, $off)
        @(($amp * [Math]::Sin($ph + $off)), (-$lift * [Math]::Max(0, [Math]::Cos($ph + $off))))
    }

    switch ($st) {
        'walk' {
            $q = & $step 5.5 7.5 0.0;    $a.pFNx += $q[0]; $a.pFNy += $q[1]
            $q = & $step 5.0 6.5 2.7;    $a.pFFx += $q[0]; $a.pFFy += $q[1]
            $q = & $step 5.0 6.5 3.14;   $a.pBNx += $q[0]; $a.pBNy += $q[1]
            $q = & $step 4.5 5.5 0.5;    $a.pBFx += $q[0]; $a.pBFy += $q[1]
            $a.bdy += 1.3 * [Math]::Cos(2 * $ph);   $a.hdy += 0.9 * [Math]::Cos(2 * $ph + 0.6)
            $a.tailA += 11 * [Math]::Sin($ph * 0.72)
            $a.tailC += 0.10 * [Math]::Sin($ph * 0.45)
        }
        'run' {
            $q = & $step 10.0 15.0 0.0;  $a.pFNx += $q[0]; $a.pFNy += $q[1]
            $q = & $step 9.0 13.5 0.6;   $a.pFFx += $q[0]; $a.pFFy += $q[1]
            $q = & $step 9.5 14.0 3.4;   $a.pBNx += $q[0]; $a.pBNy += $q[1]
            $q = & $step 8.5 12.5 2.9;   $a.pBFx += $q[0]; $a.pBFy += $q[1]
            $a.bdy += 2.6 * [Math]::Cos(2 * $ph);   $a.brot += 2.2 * [Math]::Sin(2 * $ph)
            $a.tailA += 7 * [Math]::Sin($ph * 0.9)
        }
        'chase' {
            $sp = [Math]::Abs($c.vx) / (240 * $c.size)
            $am = 4 + 6 * $sp; $li = 5 + 9 * $sp
            $q = & $step $am $li 0.0;    $a.pFNx += $q[0]; $a.pFNy += $q[1]
            $q = & $step $am $li 1.0;    $a.pFFx += $q[0]; $a.pFFy += $q[1]
            $q = & $step $am $li 3.3;    $a.pBNx += $q[0]; $a.pBNy += $q[1]
            $q = & $step $am $li 2.6;    $a.pBFx += $q[0]; $a.pBFy += $q[1]
            $a.bdy += 1.8 * [Math]::Cos(2 * $ph)
            $a.tailA += 16 * [Math]::Sin($t * 7)
            if ($c.swipe -gt 0) {
                $a.pFNx += 13 * [Math]::Abs([Math]::Sin($t * 22))
                $a.pFNy += -12 * [Math]::Abs([Math]::Sin($t * 22))
                $a.hrot += 5 * [Math]::Sin($t * 22)
                $a.hdy  += -2
            }
        }
        'sniff' {
            $q = & $step 3.5 4.0 0.0;    $a.pFNx += $q[0]; $a.pFNy += $q[1]
            $q = & $step 3.2 3.6 2.7;    $a.pFFx += $q[0]; $a.pFFy += $q[1]
            $q = & $step 3.2 3.6 3.14;   $a.pBNx += $q[0]; $a.pBNy += $q[1]
            $q = & $step 3.0 3.2 0.5;    $a.pBFx += $q[0]; $a.pBFy += $q[1]
            $a.hdy += 1.7 * [Math]::Sin($t * 9)
            $a.hdx += 1.3 * [Math]::Sin($t * 4.5)
            $a.ear += 3 * [Math]::Sin($t * 6)
            $a.tailA += 7 * [Math]::Sin($t * 2)
        }
        'idle' {
            $a.tailA += 13 * [Math]::Sin($t * 2.1)
            $a.tailC += 0.13 * [Math]::Sin($t * 1.3)
            $a.hrot  += 3.5 * [Math]::Sin($t * 0.7) + $c.look * 0.5
            $a.hdx   += 1.5 * [Math]::Sin($t * 0.5)
            $a.hdy   += $c.lookY * 0.5
            $a.bdy   += 0.5 * [Math]::Sin($t * 1.9)
        }
        'sit' {
            $a.tailA += 15 * [Math]::Sin($t * 2.6)
            $a.tailC += 0.10 * [Math]::Sin($t * 1.7)
            $a.hrot  += 2.5 * [Math]::Sin($t * 0.9) + $c.look * 0.55
            $a.hdy   += $c.lookY * 0.55
            $a.bdy   += 0.4 * [Math]::Sin($t * 2.2)
        }
        'sleep' {
            $a.bsy  += 0.028 * [Math]::Sin($t * 1.9)
            $a.bdy  += 1.1 * [Math]::Sin($t * 1.9)
            $a.tailA += 4 * [Math]::Sin($t * 0.8)
        }
        'curl' {
            $a.bsy  += 0.022 * [Math]::Sin($t * 1.7)
            $a.bdy  += 0.9 * [Math]::Sin($t * 1.7)
            $a.tailC += 0.04 * [Math]::Sin($t * 0.9)
        }
        'groom' {
            # zweiphasig wie echte Katzen: erst das Pfoetchen ablecken,
            # dann damit ueber Ohr und Wange wischen
            if (($c.stateT / [Math]::Max(0.5, $c.stateDur)) -lt 0.5) {
                $a.hrot += 9 * [Math]::Sin($t * 9)
                $a.hdy  += 2.4 * [Math]::Sin($t * 9)
                $a.pFNy += 1.5 * [Math]::Sin($t * 9)
            } else {
                $a.pFNy += -12 + 3 * [Math]::Sin($t * 8)
                $a.pFNx += 4
                $a.hrot += -20 + 5 * [Math]::Sin($t * 8)
                $a.hdy  += -3
                $a.ear  += 5 * [Math]::Sin($t * 8)
            }
            $a.tailA += 8 * [Math]::Sin($t * 1.7)
        }
        'crouch' {
            $a.bdx  += 1.6 * [Math]::Sin($t * 17)
            $a.tailA += 22 * [Math]::Sin($t * 9)
            $a.ear  += 2 * [Math]::Sin($t * 13)
        }
        'pet' {
            $a.hrot += 3 * [Math]::Sin($t * 5)
            $a.hdy  += 1.2 * [Math]::Sin($t * 5)
            $a.tailA += 12 * [Math]::Sin($t * 5.5)
            $a.bdy  += 0.7 * [Math]::Sin($t * 5)
        }
        'drag' {
            $a.brot += 6 * [Math]::Sin($t * 3.1)
            $a.pFNx += 3 * [Math]::Sin($t * 3.6)
            $a.pBNx += 2.5 * [Math]::Sin($t * 3.3 + 1)
            $a.pFNy += 2 * [Math]::Sin($t * 3.6 + 1)
            $a.tailA += 14 * [Math]::Sin($t * 2.4)
        }
        'fall' {
            $a.brot += 8 * [Math]::Sin($t * 6)
            $a.pFNy += 2.5 * [Math]::Sin($t * 7)
            $a.pBNy += 2.5 * [Math]::Sin($t * 7 + 2)
            $a.tailA += 10 * [Math]::Sin($t * 8)
        }
        'leap' {
            $a.tailA += 8 * [Math]::Sin($t * 5)
        }
        'stretch' {
            $a.bsx += 0.05 * [Math]::Sin($c.stateT * 3)
            $a.tailA += 6 * [Math]::Sin($t * 3)
        }
        'yawn' {
            # oeffnet und schliesst das Maul einmal ueber die Zustandsdauer
            # ($ev statt $env - $env kollidiert in Funktionen mit dem env:-Provider)
            $yp = [Math]::Max(0.0, [Math]::Min(1.0, $c.stateT / $c.stateDur))
            $ev = [Math]::Sin([Math]::PI * $yp)
            $a.mouth = $ev
            $a.eye = 1 - 0.94 * $ev
            $a.hrot -= 15 * $ev
            $a.hdy  -= 2 * $ev
            $a.ear  -= 3 * $ev
        }
        'meow' {
            $a.mouth = 0.35 + 0.45 * [Math]::Abs([Math]::Sin($t * 3.4))
            $a.hrot  += 3 * [Math]::Sin($t * 3.4)
            $a.tailA += 10 * [Math]::Sin($t * 2.2)
        }
        'watch' {
            $a.hrot += $c.look
            $a.hdy  += $c.lookY
            $a.tailA += 14 * [Math]::Sin($t * 3.1)
            $a.tailC += 0.08 * [Math]::Sin($t * 2)
            $a.ear   += 2 * [Math]::Sin($t * 1.7)
        }
        'scratch' {
            $a.pBNy += 4 * [Math]::Sin($t * 26)
            $a.pBNx += 2 * [Math]::Sin($t * 26)
            $a.hrot += 3 * [Math]::Sin($t * 26)
            $a.ear  += 4 * [Math]::Sin($t * 26 + 1)
            $a.bdy  += 0.6 * [Math]::Sin($t * 13)
        }
        'roll' {
            $a.bdx  += 2.4 * [Math]::Sin($t * 5.5)
            $a.brot += 3.5 * [Math]::Sin($t * 5.5)
            $a.pFNy += 5 * [Math]::Sin($t * 6.5)
            $a.pFFy += 5 * [Math]::Sin($t * 6.5 + 1.2)
            $a.pBNy += 5 * [Math]::Sin($t * 6.5 + 2.4)
            $a.pBFy += 5 * [Math]::Sin($t * 6.5 + 3.6)
            $a.hrot += 5 * [Math]::Sin($t * 5.5)
            $a.tailA += 12 * [Math]::Sin($t * 4)
        }
        'edge' {
            $a.pFNy += 6 * [Math]::Sin($t * 9)
            $a.pFFy += 6 * [Math]::Sin($t * 9 + 2.2)
            $a.bdy  += 1.3 * [Math]::Sin($t * 9)
            $a.hrot += 3 * [Math]::Sin($t * 4.5)
            $a.tailA += 9 * [Math]::Sin($t * 3)
        }
        'bat' {
            $sw = [Math]::Pow([Math]::Abs([Math]::Sin($t * 5.2)), 2)
            $a.pFNx += 14 * $sw
            $a.pFNy += -10 * $sw
            $a.hrot += 7 * $sw
            $a.bdy  += 1.4 * $sw
            $a.tailA += 20 * [Math]::Sin($t * 4.4)
            $a.ear  -= 2 * $sw
        }
        'greet' {
            $a.hdx  += 1.6 * [Math]::Sin($t * 6.5)
            $a.hdy  += 1.1 * [Math]::Sin($t * 5.2)
            $a.hrot += 2.5 * [Math]::Sin($t * 4.1)
            $a.tailA += 9 * [Math]::Sin($t * 3.4)
            $a.ear  += 2.5 * [Math]::Sin($t * 7)
            $a.bdy  += 0.4 * [Math]::Sin($t * 2.6)
        }
        # --- neue Aktivitaeten ---
        'loaf' {
            # Katzenbrot: ruhiges Atmen (bdy gleicht bsy aus, der Bauch bleibt am
            # Boden), Kopf folgt traege dem Mauszeiger, Schwanzspitze zuckt
            $br2 = [Math]::Sin($t * 1.6)
            $a.bsy  += 0.02 * $br2
            $a.bdy  -= 0.42 * $br2
            $a.hrot += $c.look * 0.5 + 1.5 * [Math]::Sin($t * 0.6)
            $a.hdy  += $c.lookY * 0.5 + 0.4 * $br2
            $a.hdx  += 1.0 * [Math]::Sin($t * 0.45)
            $a.tailA += 3 * [Math]::Sin($t * 0.9)
            $a.tailC += 0.08 * [Math]::Sin($t * 1.3)
        }
        'hop' {
            # Freudenhopser auf der Stelle: kurz zusammenducken (Squish), dann
            # hoch - die Pfoetchen ziehen sich in der Luft ein, die Ohren fliegen
            # mit, der Kopf hinkt einen Tick hinterher. Ein-/Ausblenden ueber die
            # Zustandsdauer, damit der Wechsel nicht springt. ($ev2 statt $env!)
            $hp = 0.72
            $ev2 = [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Min($c.stateT / 0.3, ($c.stateDur - $c.stateT) / 0.4)))
            $u = ($c.stateT % $hp) / $hp
            if ($u -lt 0.22) {
                $sq = [Math]::Sin([Math]::PI * $u / 0.22) * $ev2
                $a.bsy -= 0.12 * $sq; $a.bsx += 0.08 * $sq
                $a.hdy += 3 * $sq;    $a.ear -= 3 * $sq
            } else {
                $v = ($u - 0.22) / 0.78
                $hh = [Math]::Sin([Math]::PI * $v) * $ev2
                $a.bdy -= 20 * $hh
                $a.bsy += 0.05 * $hh; $a.bsx -= 0.03 * $hh
                $a.pFNy -= 9 * $hh; $a.pFFy -= 8 * $hh; $a.pBNy -= 7 * $hh; $a.pBFy -= 6 * $hh
                $a.hdy += 2.5 * [Math]::Sin(2 * [Math]::PI * $v) * $ev2
                $a.ear += 5 * $hh
            }
            $a.tailA += 10 * [Math]::Sin($t * 6)
            $a.hrot  += 3 * [Math]::Sin($t * 4)
        }
        'tilt' {
            # Kopf schief legen: erst zur einen Seite, in der zweiten Haelfte
            # weich (smoothstep) zur anderen; Ohren gespitzt, Blick zum Zeiger
            $tp = [Math]::Max(0.0, [Math]::Min(1.0, $c.stateT / [Math]::Max(0.5, $c.stateDur)))
            $sw = [Math]::Max(0.0, [Math]::Min(1.0, ($tp - 0.5) / 0.14))
            $sw = $sw * $sw * (3 - 2 * $sw)
            $a.hrot += 31 * $sw + 1.5 * [Math]::Sin($t * 1.8) + $c.look * 0.4
            $a.hdx  += 5 * $sw
            $a.hdy  += $c.lookY * 0.4 + 0.5 * [Math]::Sin($t * 2.2)
            $a.ear  += 3 * [Math]::Sin($t * 2.7)
            $a.tailA += 10 * [Math]::Sin($t * 2.4)
            $a.tailC += 0.10 * [Math]::Sin($t * 1.5)
            $a.bdy  += 0.4 * [Math]::Sin($t * 2.2)
        }
        'bunt' {
            # Koepfchen geben: solange sie noch hintapst, ein sanfter Schritt-
            # zyklus; steht sie, schiebt sie Stirn und Koerper rhythmisch nach
            # vorn und die Augen gehen beim Druecken weiter zu. Weich ein-/ausgeblendet.
            $ev2 = [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Min($c.stateT / 0.6, ($c.stateDur - $c.stateT) / 0.7)))
            $sp = [Math]::Min(1.0, [Math]::Abs($c.vx) / (46 * [Math]::Max(0.2, $c.pxs)))
            if ($sp -gt 0.05) {
                $q = & $step (4.5 * $sp) (5.5 * $sp) 0.0;   $a.pFNx += $q[0]; $a.pFNy += $q[1]
                $q = & $step (4.0 * $sp) (5.0 * $sp) 2.7;   $a.pFFx += $q[0]; $a.pFFy += $q[1]
                $q = & $step (4.0 * $sp) (5.0 * $sp) 3.14;  $a.pBNx += $q[0]; $a.pBNy += $q[1]
                $q = & $step (3.5 * $sp) (4.5 * $sp) 0.5;   $a.pBFx += $q[0]; $a.pBFy += $q[1]
                $a.bdy += 1.0 * $sp * [Math]::Cos(2 * $ph)
            }
            $pu = [Math]::Pow([Math]::Max(0.0, [Math]::Sin($t * 2.6)), 2) * $ev2 * (1 - $sp)
            $a.hdx  += 4 * $pu
            $a.hdy  += -2.5 * $pu
            $a.hrot += -7 * $pu + 2.5 * [Math]::Sin($t * 1.3)
            $a.bdx  += 2.0 * $pu
            $a.brot += -1.2 * $pu
            $a.eye  += -0.10 * $pu + 0.4 * $sp
            $a.ear  += -3 * $pu
            $a.tailA += 8 * [Math]::Sin($t * 1.9)
            $a.tailC += 0.08 * [Math]::Sin($t * 1.4)
        }
        'blink' {
            # Katzenkuss: die Augen gehen ganz langsam zu, bleiben kurz zu und
            # oeffnen sich wieder (Periode ~3.7 s); dabei hebt sich das Kinn ein
            # wenig und die Oehrchen gehen nach vorn. Blick folgt dem Mauszeiger.
            $bl = [Math]::Pow([Math]::Max(0.0, [Math]::Sin($c.stateT * 1.7 + 0.4)), 3)
            $a.eye  = 1 - 0.88 * $bl
            $a.hrot += -5 * $bl + 2 * [Math]::Sin($t * 0.8) + $c.look * 0.45
            $a.hdy  += -3 * $bl + $c.lookY * 0.5
            $a.ear  += 2.5 * $bl
            $a.mouth += 0.05 * $bl
            $a.bdy  += 0.4 * [Math]::Sin($t * 2.4)
            $a.tailA += 9 * [Math]::Sin($t * 1.6)
            $a.tailC += 0.06 * [Math]::Sin($t * 1.1)
        }
        'purr' {
            # Schnurren: kleine schnelle Squishes durch den ganzen Koerper, dazu
            # Milchtritt - die Vorderpfoetchen kneten abwechselnd; die Augen
            # pendeln zwischen Schlitz und halb offen. Weich ein-/ausgeblendet.
            $ev2 = [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Min($c.stateT / 0.7, ($c.stateDur - $c.stateT) / 0.9)))
            $pr = [Math]::Sin($t * 14) * $ev2
            $a.bsy  += 0.016 * $pr
            $a.bsx  -= 0.010 * $pr
            $a.hdy  += 0.7 * [Math]::Sin($t * 14 + 0.6) * $ev2
            $a.hrot += 3 * [Math]::Sin($t * 1.1) + $c.look * 0.3
            $a.pFNy += -4 * [Math]::Max(0.0, [Math]::Sin($t * 3.2)) * $ev2
            $a.pFNx += 1.5 * [Math]::Sin($t * 3.2) * $ev2
            $a.pFFy += -4 * [Math]::Max(0.0, [Math]::Sin($t * 3.2 + 3.14)) * $ev2
            $a.pFFx += 1.5 * [Math]::Sin($t * 3.2 + 3.14) * $ev2
            $a.bdx  += 0.8 * [Math]::Sin($t * 3.2) * $ev2
            $a.tailA += 5 * [Math]::Sin($t * 1.4) + 1.5 * $pr
            $a.tailC += 0.05 * [Math]::Sin($t * 0.9)
            $a.ear  += 1.5 * $pr
            $a.eye  += 0.15 * [Math]::Sin($t * 0.9)
        }
        'wiggle' {
            # Popo-Wackeln vor dem Sprung: das Hinterteil schwingt immer kraeftiger
            # hin und her, die Hinterpfoetchen tippeln, der Kopf haelt dagegen
            $w = [Math]::Max(0.0, [Math]::Min(1.0, $c.stateT / [Math]::Max(0.3, $c.stateDur)))
            $amp = 0.45 + 0.55 * $w
            $s = [Math]::Sin($t * 10.5)
            $a.bdx  += 3.5 * $amp * $s
            $a.brot += 2.0 * $amp * $s
            $a.hdx  -= 2.8 * $amp * $s          # Kopf haelt dagegen (erbt bdx)
            $a.pBNx += 3.5 * $amp * $s; $a.pBNy -= 3 * $amp * [Math]::Max(0, $s)
            $a.pBFx -= 3.5 * $amp * $s; $a.pBFy -= 3 * $amp * [Math]::Max(0, -$s)
            $a.tailA += 28 * [Math]::Sin($t * 6.5)
            $a.tailC += 0.22 * [Math]::Sin($t * 6.5 - 1)
            $a.ear  += 2 * $s
        }
        'wave' {
            # winkt: das angehobene Pfoetchen pendelt hin und her
            $a.pFNx += 5 * [Math]::Sin($t * 7)
            $a.pFNy += -4 + 5 * [Math]::Sin($t * 7 + 1.2)
            $a.hrot += 3 * [Math]::Sin($t * 3.5)
            $a.tailA += 13 * [Math]::Sin($t * 2.8)
            $a.ear  += 2 * [Math]::Sin($t * 3.5)
        }
        'arch' {
            $a.bsy  += 0.03 * [Math]::Sin($t * 2)
            $a.tailA += 5 * [Math]::Sin($t * 2.5)
            $a.hrot += 2 * [Math]::Sin($t * 1.8)
        }
        'shake' {
            $a.brot += 8 * [Math]::Sin($t * 15)
            $a.bdx  += 2.2 * [Math]::Sin($t * 15)
            $a.hrot += 16 * [Math]::Sin($t * 17)
            $a.hdx  += 1.6 * [Math]::Sin($t * 17)
            $a.ear  += 9 * [Math]::Sin($t * 17 + 1)
            $a.tailA += 14 * [Math]::Sin($t * 13)
        }
        'dig' {
            # scharrt abwechselnd mit beiden Vorderpfoetchen nach hinten
            $a.pFNx += 7 * [Math]::Sin($t * 7)
            $a.pFNy += -9 * [Math]::Max(0, [Math]::Sin($t * 7))
            $a.pFFx += 6 * [Math]::Sin($t * 7 + 3.14)
            $a.pFFy += -8 * [Math]::Max(0, [Math]::Sin($t * 7 + 3.14))
            $a.bdy += 1.2 * [Math]::Sin($t * 14)
            $a.hdy += 1.0 * [Math]::Sin($t * 14)
            $a.tailA += 9 * [Math]::Sin($t * 3)
        }
        'beg' {
            $a.pFNy += 4 * [Math]::Sin($t * 4)
            $a.pFFy += 4 * [Math]::Sin($t * 4 + 1.2)
            $a.bdy += 0.9 * [Math]::Sin($t * 2.4)
            $a.hrot += 3 * [Math]::Sin($t * 2)
            $a.ear  += 2 * [Math]::Sin($t * 3)
        }
        'rub' {
            $a.bdx  += 3.2 * [Math]::Sin($t * 2.2)
            $a.brot += 2.5 * [Math]::Sin($t * 2.2)
            $a.hrot += 4 * [Math]::Sin($t * 2.2)
            $a.tailA += 11 * [Math]::Sin($t * 1.8)
        }
    }

    # Atmen: alle wachen Posen heben und senken sich ganz leicht (Schlafposen
    # haben ihr eigenes, tieferes Atmen)
    if (@('sleep','curl') -notcontains $st) { $a.bsy += 0.012 * [Math]::Sin($t * 1.6) }
    # gelegentliches Ohrenzucken (Zeitgeber in Update-Behaviour)
    if ($c.earFlick -gt 0) { $a.ear += 14 * [Math]::Sin($c.earFlick / 0.3 * [Math]::PI) }

    # Blinzeln geht weich zu und wieder auf; langsames Blinzeln = Zuneigung
    if ($c.blink -gt 0) {
        $bp = 1 - ($c.blink / [Math]::Max(0.05, $c.blinkDur))
        $close = [Math]::Sin([Math]::PI * [Math]::Max(0, [Math]::Min(1, $bp)))
        $a.eye = $a.eye * (1 - 0.95 * $close)
    }
    $a
}

function Apply-Pose($c, $a) {
    # Rumpf-Verband (Schwanz, ferne Beine) und Gesichts-Verband
    $c.bodyTr.X = $a.bdx; $c.bodyTr.Y = $a.bdy
    $c.bodyRot.Angle = $a.brot
    $c.bodyScl.ScaleX = $a.bsx; $c.bodyScl.ScaleY = $a.bsy
    $c.headTr.X = $a.bdx + $a.hdx; $c.headTr.Y = $a.bdy + $a.hdy
    $c.headRot.Angle = $a.hrot
    # angehobene Pfoetchen schrumpfen zur Bauchlinie hin (Faktor 1 = unten, 0 = eingezogen)
    $fF = [Math]::Max(0.0, [Math]::Min(1.0, 1 + $a.pFNy / 17.0))
    $fB = [Math]::Max(0.0, [Math]::Min(1.0, 1 + $a.pBNy / 17.0))
    $c.legFF.tr.X = $a.pFFx; $c.legFF.sc.ScaleY = [Math]::Max(0.0, [Math]::Min(1.0, 1 + $a.pFFy / 17.0))
    $c.legBF.tr.X = $a.pBFx; $c.legBF.sc.ScaleY = [Math]::Max(0.0, [Math]::Min(1.0, 1 + $a.pBFy / 17.0))

    # --- Silhouette: Anker transformieren + Catmull-Rom->Bezier (C#, s. CatSil)
    $c.silFig.StartPoint = [CatSil]::Compute($SIL_X, $SIL_Y, $SIL_G, $SIL_S, $SIL_E, $SIL_W, $SIL_N,
        $BCX, $GROUND, $SIL_BELLY, $SIL_EARBX, $SIL_EARBY,
        $a.bsx, $a.bsy, $a.brot, $a.bdx, $a.bdy, $a.hrot, $a.hdx, $a.hdy, $c.headK, $a.ear,
        $a.pFNx, $a.pFNy, $a.pBNx, $a.pBNy, $c.silPts)

    # --- Gesicht --------------------------------------------------------------
    $e2 = [Math]::Max(0.05, $a.eye)
    $c.eyeF.scl.ScaleY = $e2; $c.eyeN.scl.ScaleY = $e2
    $lidOp = [Math]::Max(0, 1 - $a.eye * 5)
    $c.lidF.Opacity = $lidOp; $c.lidN.Opacity = $lidOp
    $m = [Math]::Max(0, [Math]::Min(1, $a.mouth))
    $c.mouthScl.ScaleY = $m; $c.mouthScl.ScaleX = 0.65 + 0.35 * $m
    $c.lipF.Opacity = 1 - $m; $c.lipN.Opacity = 1 - $m

    # Schwanz liegt im Rumpf-Verband, bekommt die Verschiebung also schon dort
    Set-Tail $c 0 0 $a.tailA $a.tailC

    # Umdrehen als kurze Animation: die Spiegelung laeuft weich von +1 nach -1
    $c.fvis += ($c.facing - $c.fvis) * [Math]::Min(1.0, $G.dt * 12)
    if ([Math]::Abs($c.fvis - $c.facing) -lt 0.02) { $c.fvis = $c.facing }
    $c.flipScale.ScaleX = $c.fvis

    $h = [Math]::Max(0, $c.y / $c.size)
    $c.shadowScale.ScaleX = 1.0 / (1 + $h / 55)
    $c.shadowScale.ScaleY = 1.0 / (1 + $h / 90)
    $c.shadow.Opacity = 1.0 / (1 + $h / 35)
}

# ============================================================================
#  Klick-Durchlaessigkeit: nur die Katze selbst faengt Mausklicks
# ============================================================================
function Set-ClickThrough($c, [bool]$on) {
    if ($c.clickThrough -eq $on) { return }
    $c.clickThrough = $on
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($c.win)).Handle
    if ($hwnd -eq [IntPtr]::Zero) { return }
    $ex = [CatNative]::GetWindowLong($hwnd, $GWL_EXSTYLE)
    if ($on) { $ex = $ex -bor $WS_EX_TRANSPARENT } else { $ex = $ex -band (-bnot $WS_EX_TRANSPARENT) }
    [void][CatNative]::SetWindowLong($hwnd, $GWL_EXSTYLE, $ex)
}

function Update-HitArea($c) {
    if ($c.dragging) { Set-ClickThrough $c $false; return }
    $cur = [System.Windows.Forms.Cursor]::Position
    $lx = (($cur.X / $G.sx) - $c.win.Left) / $c.size - $PAD
    $ly = (($cur.Y / $G.sy) - $c.win.Top) / $c.size
    $over = $false
    if ($lx -ge 0 -and $lx -le $CW -and $ly -ge 0 -and $ly -le $CH) {
        # pixelgenau: nur echte Katzen-Pixel fangen Klicks ab
        $hit = [System.Windows.Media.VisualTreeHelper]::HitTest($c.root, [System.Windows.Point]::new($lx, $ly))
        $over = ($null -ne $hit -and $null -ne $hit.VisualHit)
    }
    Set-ClickThrough $c (-not $over)
}

# ============================================================================
#  Wartung: laeuft ca. jede Sekunde und haelt die Katzen mit der Wirklichkeit
#  im Einklang - Bildschirmskalierung, Monitorwechsel, Vollbild-Apps, Abwesenheit.
# ============================================================================
function Show-Cats([bool]$show) {
    if ($G.hidden -eq (-not $show)) { return }
    $G.hidden = (-not $show)
    foreach ($c in (@($G.cats) + @($G.kits))) {
        if ($show) { $c.win.Show() } else { if ($c.dragging) { $c.root.ReleaseMouseCapture() }; $c.win.Hide() }
    }
    foreach ($sp in @($G.toy, $G.fly)) {
        if ($sp) { if ($show) { $sp.sp.win.Show() } else { $sp.sp.win.Hide() } }
    }
}

function Update-Housekeeping($dt) {
    $G.hkT -= $dt
    if ($G.hkT -gt 0) { return }
    $G.hkT = 1.2
    if ($G.cats.Count -eq 0) { return }

    # 1) Bildschirmskalierung kann sich im Betrieb aendern (Monitor umgesteckt,
    #    Skalierung geaendert). Wird sie nur beim Start gelesen, sitzen die
    #    Katzen danach an der falschen Stelle.
    $src = [System.Windows.PresentationSource]::FromVisual($G.cats[0].win)
    if ($null -ne $src) {
        $m = $src.CompositionTarget.TransformToDevice
        if ($m.M11 -gt 0 -and [Math]::Abs($m.M11 - $G.sx) -gt 0.005) {
            $G.sx = $m.M11; $G.sy = $m.M22
            foreach ($c in (@($G.cats) + @($G.kits))) { $c.pxs = $c.size * $G.sx }
        }
    }

    # 2) Katze ausserhalb aller Monitore (Notebook abgedockt)? zurueckholen
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($c in (@($G.cats) + @($G.kits))) {
        $onScreen = $false
        foreach ($s in $screens) {
            if ($c.x -ge $s.Bounds.Left -and $c.x -le $s.Bounds.Right) { $onScreen = $true; break }
        }
        if (-not $onScreen) {
            Abort-Social
            Move-ToScreen $c ([System.Windows.Forms.Screen]::PrimaryScreen) 0
            Set-State $c 'walk' (Rnd 2 5)
        }
    }

    # 3) Vollbild-App auf einem Monitor, auf dem eine Katze sitzt? dann aus dem Weg.
    #    Laeuft das Vollbild auf einem anderen Monitor, bleiben sie sichtbar.
    $full = $false
    foreach ($c in $G.cats) {
        if ($null -eq $c.screen) { continue }
        $b = $c.screen.Bounds
        if ([CatNative]::ForegroundIsFullscreen($b.Left, $b.Top, $b.Right, $b.Bottom)) { $full = $true; break }
    }
    Show-Cats (-not $full)

    # 4) Niemand am Rechner? Dann doesen sie, statt Aufmerksamkeit zu wollen.
    $idle = [CatNative]::IdleSeconds()
    $wasAway = $G.away
    $G.away = ($idle -gt 240)
    if ($wasAway -and -not $G.away) {
        # du bist zurueck - sie wachen auf und recken sich
        if ($G.soc.mode -eq 'nap') { Abort-Social }
        foreach ($c in (@($G.cats) + @($G.kits))) {
            if (@('sleep','curl') -contains $c.state) { Set-State $c 'shake' 1.1 }
        }
    }
}

# ============================================================================
#  Menues und Aktionen
# ============================================================================
function Stop-All {
    $timer.Stop()
    Despawn-Yarn
    Despawn-Fly
    if ($notify) { $notify.Visible = $false; $notify.Dispose() }
    foreach ($c in (@($G.cats) + @($G.kits))) { $c.win.Close() }
    [System.Windows.Application]::Current.Shutdown()
}

function Set-Fur($c, [string]$name) {
    $c.fur = $name
    $new = Get-Palette $name
    foreach ($role in $c.fill.Keys)   { foreach ($el in $c.fill[$role])   { $el.Fill = $new[$role] } }
    foreach ($role in $c.stroke.Keys) { foreach ($el in $c.stroke[$role]) { $el.Stroke = $new[$role] } }
    $c.col = $new
}

function Set-CatSize($c, [double]$s) {
    $c.size = $s
    $c.pxs = $s * $G.sx
    $c.rootScale.ScaleX = $s; $c.rootScale.ScaleY = $s
    $c.win.Width = ($CW + 2 * $PAD) * $s; $c.win.Height = ($CH + $PAD) * $s; $c.rootPad.X = $PAD * $s
}

function Set-AllSizes([double]$s) {
    foreach ($c in $G.cats) { Set-CatSize $c ($s * $c.rel) }
    foreach ($k in $G.kits) { Set-CatSize $k ($s * $k.rel) }
    foreach ($sp in @($G.toy, $G.fly)) {
        if ($sp) {
            $sp.sp.size = $s
            $sp.sp.cv.RenderTransform = New-Object System.Windows.Media.ScaleTransform($s, $s)
            $sp.sp.win.Width = $sp.sp.w * $s; $sp.sp.win.Height = $sp.sp.h * $s
        }
    }
}

function Toggle-Chase($c) {
    $c.chase = -not $c.chase
    Abort-Social
    if ($c.chase) { Set-State $c 'chase' (Rnd 6 12) } else { Set-State $c 'sit' 2 }
}

function Add-Friend {
    if ($G.cats.Count -ge 2) { return }
    $first = $G.cats[0]
    $f = New-Cat 'schwarz' ($first.size * 0.94) 'Luna' 'Desktop-Katze-Luna' ''
    $f.rel = 0.94                          # Groessenverhaeltnis zu Minka (fuer Set-AllSizes)
    $wa = $first.screen.WorkingArea
    $f.screen = $first.screen
    $f.groundY = $first.groundY
    $f.x = $first.x + 300 * $first.pxs
    if ($f.x -gt $wa.Right - 60) { $f.x = $first.x - 300 * $first.pxs }
    if ($f.x -lt $wa.Left + 60)  { $f.x = $wa.Left + 60 }
    [void]$G.cats.Add($f)
    Build-CatMenu $f
    if (-not $G.hidden) { $f.win.Show() }     # bei Vollbild-Versteck erst spaeter zeigen
    Update-WindowPos $f
    Set-State $f 'walk' (Rnd 2 5)
    $G.soc.mode = 'none'
    $G.soc.cool = Rnd 6 14        # sie begruessen sich bald
}

function Remove-Friend {
    if ($G.cats.Count -lt 2) { return }
    $f = $G.cats[1]
    Abort-Social
    Clear-Particles $f
    $f.win.Close()
    $G.cats.RemoveAt(1)
}

function Toggle-Friend {
    if ($G.cats.Count -ge 2) { Remove-Friend } else { Add-Friend }
}

# --- Babykatzen: zwei winzige Kaetzchen mit extra grossen Koepfen, die den
# Grossen auf die Nerven gehen. Kommen und gehen auf Bedarf.
function Add-Kittens {
    if ($G.kits.Count -gt 0 -or $G.cats.Count -eq 0) { return }
    $ref = $G.cats[0]
    # Kruemel ist immer schwarz, Fussel bekommt zufaellig ein anderes Fell
    $furs = @('schwarz', (@('orange','grau','weiss','siam') | Get-Random))
    $names = @('Kruemel', 'Fussel')
    $wa = $ref.screen.WorkingArea
    for ($i = 0; $i -lt 2; $i++) {
        $k = New-Cat $furs[$i] ($ref.size * (0.55 - $i * 0.03)) $names[$i] ('Desktop-Katze-' + $names[$i]) '' 1.26
        $k.kit = $true
        $k.rel = 0.55 - $i * 0.03
        $k.screen = $ref.screen
        $k.groundY = $ref.groundY
        $k.x = $ref.x + ($i * 2 - 1) * (Rnd 130 240) * $ref.pxs
        if ($k.x -lt $wa.Left + 50)  { $k.x = $wa.Left + 50 }
        if ($k.x -gt $wa.Right - 50) { $k.x = $wa.Right - 50 }
        [void]$G.kits.Add($k)
        if (-not $G.hidden) { $k.win.Show() }
        Update-WindowPos $k
        Add-Particle $k 'dust' ($CAT_CX - 8) ($GROUND - 12)
        Add-Particle $k 'dust' ($CAT_CX + 8) ($GROUND - 10)
        Set-State $k 'run' (Rnd 1 2)    # sie kommen direkt mit Zoomies an
    }
}

function Remove-Kittens {
    foreach ($k in @($G.kits)) { Clear-Particles $k; $k.win.Close() }
    $G.kits.Clear()
}

function Toggle-Kittens {
    if ($G.kits.Count -gt 0) { Remove-Kittens } else { Add-Kittens }
}

# --- Rechtsklick-Menue direkt auf einer Katze ------------------------------
function Build-CatMenu($c) {
    $cm = New-Object System.Windows.Controls.ContextMenu
    $mk = {
        param($text, $act)
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $text
        $mi.Add_Click($act)
        [void]$cm.Items.Add($mi)
        $mi
    }
    $miChase = & $mk ('Maus jagen (' + $c.name + ')') { Toggle-Chase $c }.GetNewClosure()
    $miChase.IsCheckable = $true
    & $mk 'Wollknaeuel werfen' { Spawn-Yarn } | Out-Null
    & $mk 'Schmetterling schicken' { Spawn-Fly } | Out-Null
    & $mk 'Schlafen' { Set-State $c 'sleep' (Rnd 10 25) }.GetNewClosure() | Out-Null
    & $mk 'Zoomies!' { Set-Chute $c $false; $c.y = 0; $c.vy = 0; Set-State $c 'run' (Rnd 4 6) }.GetNewClosure() | Out-Null
    [void]$cm.Items.Add((New-Object System.Windows.Controls.Separator))
    $miFriend = & $mk 'Freundin holen' { Toggle-Friend }
    $miKits = & $mk 'Babykatzen holen' { Toggle-Kittens }
    $miFur = New-Object System.Windows.Controls.MenuItem
    $miFur.Header = 'Fell'
    foreach ($f in 'orange','grau','schwarz','weiss','siam') {
        $fn = $f
        $sub = New-Object System.Windows.Controls.MenuItem
        $sub.Header = $fn
        $sub.Add_Click({ Set-Fur $c $fn; Refresh-TrayIcon }.GetNewClosure())
        [void]$miFur.Items.Add($sub)
    }
    [void]$cm.Items.Add($miFur)
    [void]$cm.Items.Add((New-Object System.Windows.Controls.Separator))
    & $mk 'Katzen beenden' { Stop-All } | Out-Null
    $cm.Add_Opened({
        $miChase.IsChecked = $c.chase
        if ($G.cats.Count -ge 2) { $miFriend.Header = 'Freundin wegschicken' }
        else { $miFriend.Header = 'Freundin holen' }
        if ($G.kits.Count -gt 0) { $miKits.Header = 'Babykatzen wegschicken' }
        else { $miKits.Header = 'Babykatzen holen' }
    }.GetNewClosure())
    $c.root.ContextMenu = $cm
}

# --- Tray-Icon -------------------------------------------------------------
function New-CatIcon {
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $furName = 'orange'
    if ($G.cats.Count -gt 0) { $furName = $G.cats[0].fur }
    $p = $PALETTES[$furName]
    $fur = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($p.fur))
    $dk  = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($p.edge))
    $ey  = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($p.eye))
    $g.FillPolygon($fur, @([System.Drawing.Point]::new(5,13),  [System.Drawing.Point]::new(6,1),  [System.Drawing.Point]::new(15,8)))
    $g.FillPolygon($fur, @([System.Drawing.Point]::new(27,13), [System.Drawing.Point]::new(26,1), [System.Drawing.Point]::new(17,8)))
    $g.FillEllipse($fur, 2, 7, 28, 24)
    $g.FillEllipse($ey, 8, 15, 6, 8)
    $g.FillEllipse($ey, 18, 15, 6, 8)
    $g.FillEllipse($dk, 10, 16, 2, 6)
    $g.FillEllipse($dk, 20, 16, 2, 6)
    $g.FillEllipse($dk, 14, 24, 4, 3)
    $g.Dispose()
    $fur.Dispose(); $dk.Dispose(); $ey.Dispose()
    $h = $bmp.GetHicon()
    $ico = ([System.Drawing.Icon]::FromHandle($h)).Clone()   # eigene Kopie, dann natives Handle freigeben
    [void][CatNative]::DestroyIcon($h)
    $bmp.Dispose()
    $ico
}

function Refresh-TrayIcon {
    if ($notify) { $old = $notify.Icon; $notify.Icon = New-CatIcon; if ($old) { $old.Dispose() } }
}

# ============================================================================
#  Start
# ============================================================================
$sw = New-Object System.Diagnostics.Stopwatch

$cat1 = New-Cat $Fur $Size 'Minka' 'Desktop-Katze' 'bow'
[void]$G.cats.Add($cat1)

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = New-CatIcon
$notify.Text = 'Desktop-Katzen'
$notify.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip

function Add-TrayItem($parent, $text, $action) {
    $it = New-Object System.Windows.Forms.ToolStripMenuItem
    $it.Text = $text
    if ($action) { $it.Add_Click($action) }
    [void]$parent.Items.Add($it)
    $it
}

$tFriend = Add-TrayItem $menu 'Freundin holen' { Toggle-Friend }
$tKits = Add-TrayItem $menu 'Babykatzen holen' { Toggle-Kittens }
$tChase = Add-TrayItem $menu 'Maus jagen' {
    $on = -not $G.cats[0].chase
    Abort-Social
    foreach ($c in $G.cats) {
        $c.chase = $on
        if ($on) { Set-State $c 'chase' (Rnd 6 12) } else { Set-State $c 'sit' 2 }
    }
}
Add-TrayItem $menu 'Wollknaeuel werfen' { Spawn-Yarn } | Out-Null
Add-TrayItem $menu 'Schmetterling schicken' { Spawn-Fly } | Out-Null
Add-TrayItem $menu 'Jetzt begruessen' {
    Abort-Social
    $G.soc.cool = 0.2
} | Out-Null
$tPause = Add-TrayItem $menu 'Pause' {
    $G.paused = -not $G.paused
    if ($G.paused) { $timer.Stop() } else { $sw.Restart(); $G.last = 0; $timer.Start() }
}
Add-TrayItem $menu 'Auf diesen Monitor holen' {
    $cur = [System.Windows.Forms.Cursor]::Position
    $scr = Get-ScreenAt $cur.X $cur.Y
    Abort-Social
    $i = 0
    foreach ($c in (@($G.cats) + @($G.kits))) {
        Move-ToScreen $c $scr ($i * 220 * $c.pxs - 110 * $c.pxs)
        Set-State $c 'walk' (Rnd 3 6)
        $i++
    }
} | Out-Null
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$tSize = Add-TrayItem $menu 'Groesse' $null
foreach ($pair in @(@('klein',0.6), @('normal',0.8), @('gross',1.15), @('riesig',1.6))) {
    $sizeVal = [double]$pair[1]
    $it = New-Object System.Windows.Forms.ToolStripMenuItem
    $it.Text = $pair[0]
    $it.Add_Click({ Set-AllSizes $sizeVal }.GetNewClosure())
    [void]$tSize.DropDownItems.Add($it)
}
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
Add-TrayItem $menu 'Beenden' { Stop-All } | Out-Null
$notify.ContextMenuStrip = $menu
$menu.Add_Opening({
    $tChase.Checked = $G.cats[0].chase
    if ($G.paused) { $tPause.Text = 'Weiter' } else { $tPause.Text = 'Pause' }
    if ($G.cats.Count -ge 2) { $tFriend.Text = 'Freundin wegschicken' } else { $tFriend.Text = 'Freundin holen' }
    if ($G.kits.Count -gt 0) { $tKits.Text = 'Babykatzen wegschicken' } else { $tKits.Text = 'Babykatzen holen' }
})
$notify.Add_MouseDoubleClick({ Spawn-Yarn })

# --- Debug: alle Posen als PNG rendern und beenden -------------------------
if ($Sheet) {
    $notify.Visible = $false; $notify.Dispose()
    $c = $cat1
    $c.win.Content = $null
    $c.root.RenderTransform = $null        # in Design-Groesse rendern (ohne Size/PAD)
    $c.root.Measure([System.Windows.Size]::new($CW, $CH))
    $c.root.Arrange([System.Windows.Rect]::new(0, 0, $CW, $CH))
    $c.root.UpdateLayout()
    if (-not (Test-Path $Sheet)) { New-Item -ItemType Directory -Force -Path $Sheet | Out-Null }
    $shots = @(
        @{ n='walk0';  s='walk';   ph=0.0 }, @{ n='walk1'; s='walk'; ph=1.57 }
        @{ n='walk2';  s='walk';   ph=3.14 }, @{ n='walk3'; s='walk'; ph=4.71 }
        @{ n='run0';   s='run';    ph=0.8 }, @{ n='run1';  s='run';  ph=3.9 }
        @{ n='idle';   s='idle';   ph=0.0 }, @{ n='sit';    s='sit';    ph=0.0 }
        @{ n='sleep';  s='sleep';  ph=0.0 }, @{ n='curl';   s='curl';   ph=0.0 }
        @{ n='groom';  s='groom';  ph=0.0 }
        @{ n='stretch';s='stretch';ph=0.0 }, @{ n='crouch'; s='crouch'; ph=0.0 }
        @{ n='leap';   s='leap';   ph=0.0 }, @{ n='land';   s='land';   ph=0.0 }
        @{ n='fall';   s='fall';   ph=0.0 }, @{ n='drag';   s='drag';   ph=0.0 }
        @{ n='pet';    s='pet';    ph=0.0 }, @{ n='chase';  s='chase';  ph=1.2 }
        @{ n='yawn';   s='yawn';   ph=0.0 }, @{ n='meow';   s='meow';   ph=0.0 }
        @{ n='watch';  s='watch';  ph=0.0 }, @{ n='scratch';s='scratch';ph=0.0 }
        @{ n='roll';   s='roll';   ph=0.0 }, @{ n='edge';   s='edge';   ph=0.0 }
        @{ n='bat';    s='bat';    ph=0.0 }, @{ n='greet';  s='greet';  ph=0.0 }
        @{ n='wave';   s='wave';   ph=0.0 }, @{ n='sniff';  s='sniff';  ph=1.2 }
        @{ n='arch';   s='arch';   ph=0.0 }, @{ n='shake';  s='shake';  ph=0.0 }
        @{ n='dig';    s='dig';    ph=0.0 }, @{ n='beg';    s='beg';    ph=0.0 }
        @{ n='rub';    s='rub';    ph=0.0 }
        @{ n='loaf';   s='loaf';   ph=0.0 }, @{ n='hop';    s='hop';    ph=0.0 }
        @{ n='tilt';   s='tilt';   ph=0.0 }, @{ n='bunt';   s='bunt';   ph=0.0 }
        @{ n='blink';  s='blink';  ph=0.0 }, @{ n='purr';   s='purr';   ph=0.0 }
        @{ n='wiggle'; s='wiggle'; ph=0.0 }
    )
    $c.blink = 0; $c.swipe = 0; $c.t = 0.35; $c.y = 0; $c.facing = 1.0; $c.size = 1.0
    $c.stateT = 0.8; $c.stateDur = 1.6      # fuer 'yawn': Maul in der Mitte weit offen
    $c.look = -20; $c.lookY = -1.0
    foreach ($sh in $shots) {
        $c.state = $sh.s
        $c.phase = $sh.ph
        $c.base = $POSES[$sh.s]
        $c.pose = $POSES[$sh.s].Clone()
        Set-Chute $c ($sh.n -eq 'fall')    # Fall-Pose mit offenem Fallschirm zeigen
        Apply-Pose $c (Get-AppliedPose $c 999)
        $c.root.UpdateLayout()
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]($CW*3), [int]($CH*3), 288, 288, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($c.root)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create((Join-Path $Sheet ("pose_" + $sh.n + ".png")))
        $enc.Save($fs)
        $fs.Close()
    }
    Write-Host "Posen gerendert: $($shots.Count)"
    exit 0
}

# Start auf dem Monitor, an dem gerade gearbeitet wird
$startPos = [System.Windows.Forms.Cursor]::Position
$primary = Get-ScreenAt $startPos.X $startPos.Y
$cat1.x = $primary.WorkingArea.Left + $primary.WorkingArea.Width * 0.5
$cat1.groundY = [double]$primary.WorkingArea.Bottom
$cat1.screen = $primary
Set-State $cat1 'walk' 4

Build-CatMenu $cat1
$cat1.win.Show()
Update-WindowPos $cat1

if (-not $OhneFreundin) { Add-Friend }
if ($MitBabykatzen) { Add-Kittens }
# Debug: -Pose haelt alle Katzen in einer Pose fest
if ($Pose) {
    if ($POSES.ContainsKey($Pose) -or $POSE_ALIAS.ContainsKey($Pose)) {
        foreach ($c in (@($G.cats) + @($G.kits))) { Set-State $c $Pose 9999; $c.vx = 0 }
    } else { Write-Warning "Unbekannte Pose: $Pose" }
}
# -Fast staffelt die Ereignisse: erst begruessen, dann Knaeuel, dann Falter
if ($Fast) { $G.soc.cool = 4.0; $G.toyT = 28.0; $G.flyT = 48.0 }

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(28)     # ~36 fps (Kompromiss aus Fluessigkeit und CPU)
$timer.Add_Tick({
    # Alles in try/catch: ein Fehler hier wuerde sonst lautlos verschluckt und
    # die Katzen blieben einfach stehen, ohne Spur im Log.
    try {
        $now = $sw.Elapsed.TotalSeconds
        $dt = $now - $G.last
        $G.last = $now
        if ($dt -le 0) { return }
        if ($dt -gt 0.1) { $dt = 0.1 }
        $G.dt = $dt

        Update-Housekeeping $dt
        if ($G.hidden) { return }      # Vollbild-App: nichts rechnen, nichts zeichnen

        Update-Social $dt
        $all = @($G.cats) + @($G.kits)
        foreach ($c in $all) {
            $c.t += $dt
            Update-Behaviour $c $dt
            Update-Physics $c $dt
        }
        Update-Yarn $dt
        Update-Fly $dt

        # Spielzeug taucht von allein auf - aber nicht, wenn niemand zusieht
        if (-not $G.away) {
            if (-not $G.toy) { $G.toyT -= $dt; if ($G.toyT -le 0) { Spawn-Yarn } }
            if (-not $G.fly) { $G.flyT -= $dt; if ($G.flyT -le 0) { Spawn-Fly } }
        }

        foreach ($c in $all) {
            Apply-Pose $c (Get-AppliedPose $c $dt)
            Update-Particles $c $dt
            Update-WindowPos $c
            Update-HitArea $c
        }
    } catch {
        $G.errCount++
        if ($G.errCount -le 8) {
            $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $_.Exception.Message +
                    "`r`n" + $_.ScriptStackTrace + "`r`n"
            try { Add-Content -Path $G.errLog -Value $line -Encoding UTF8 } catch { }
        }
    }
})

$app = New-Object System.Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'
# Fehler in Maus-/Menue-Handlern (ausserhalb des Timer-Ticks) landen sonst
# unbehandelt im Dispatcher und beenden das Skript ohne Aufraeumen
$app.Add_DispatcherUnhandledException({
    param($s, $e)
    $G.errCount++
    if ($G.errCount -le 8) {
        $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] (Handler) ' + $e.Exception.Message + "`r`n"
        try { Add-Content -Path $G.errLog -Value $line -Encoding UTF8 } catch { }
    }
    $e.Handled = $true
})
$sw.Start()
$timer.Start()
try { [void]$app.Run() }
finally {
    $timer.Stop()
    if ($notify) { $notify.Visible = $false; $notify.Dispose() }
}
