# Builds src/img/mech/mechN_{booster,torso}.png from the source sheets in src/img.
# Sheet layout: column 1 = grayscale art, column 2 = color mask (red = primary, green = secondary, blue = glow);
# mech sheets: row 1 = booster, row 2 = torso; funnel sheet: one drone per row (4 rows). Art faces right. Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File tools/prep-mech-sprites.ps1 [-Scale 0.3]
param([string]$Src = "src/img", [string]$Out = "src/img/mech", [double]$Scale = 0.3)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Runtime.InteropServices;
public static class Prep {
  static byte[] Read(Bitmap b, out int stride) {
    var d = b.LockBits(new Rectangle(0,0,b.Width,b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    stride = d.Stride; var a = new byte[stride*b.Height]; Marshal.Copy(d.Scan0, a, 0, a.Length); b.UnlockBits(d); return a;
  }
  static Bitmap Make(int w, int h, byte[] px) {
    var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    var d = b.LockBits(new Rectangle(0,0,w,h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    Marshal.Copy(px, 0, d.Scan0, px.Length); b.UnlockBits(d); return b;
  }
  static Rectangle BBox(byte[] p, int st, int x0, int y0, int x1, int y1) {
    int mnx=int.MaxValue, mny=int.MaxValue, mxx=-1, mxy=-1;
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) if (p[y*st+x*4+3] > 24) { if(x<mnx)mnx=x; if(x>mxx)mxx=x; if(y<mny)mny=y; if(y>mxy)mxy=y; }
    return new Rectangle(mnx, mny, mxx-mnx+1, mxy-mny+1);
  }
  static double C(double v){ return v<0?0:v>1?1:v; }
  // Clean-up mask for one cell: keep only real shapes (8-connected opaque regions at least 2% of the biggest one),
  // grown by 2px so their soft edges survive. Specks and slivers of neighbouring parts are dropped.
  static bool[] Keep(byte[] p, int st, int W, int H, int x0, int y0, int x1, int y1, out Rectangle box) {
    var lab = new int[W*H]; var sizes = new System.Collections.Generic.List<int>(); sizes.Add(0); var q = new System.Collections.Generic.Stack<int>();
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) {
      int s0 = y*W+x; if (lab[s0] != 0 || p[y*st+x*4+3] <= 20) continue;
      int id = sizes.Count, n = 0; lab[s0] = id; q.Push(s0);
      while (q.Count > 0) { int c = q.Pop(); n++; int cx = c % W, cy = c / W;
        for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) { int nx = cx+dx, ny = cy+dy; if (nx<x0||nx>=x1||ny<y0||ny>=y1) continue; int np = ny*W+nx; if (lab[np] != 0 || p[ny*st+nx*4+3] <= 20) continue; lab[np] = id; q.Push(np); } }
      sizes.Add(n);
    }
    int big = 0; foreach (var n in sizes) if (n > big) big = n; int min = Math.Max(120, big / 50);
    var keep = new bool[W*H]; int mnx=int.MaxValue, mny=int.MaxValue, mxx=-1, mxy=-1;
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) { int l = lab[y*W+x]; if (l == 0 || sizes[l] < min) continue;
      if(x<mnx)mnx=x; if(x>mxx)mxx=x; if(y<mny)mny=y; if(y>mxy)mxy=y;
      for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) { int nx=x+dx, ny=y+dy; if (nx>=x0&&nx<x1&&ny>=y0&&ny<y1) keep[ny*W+nx] = true; } }
    box = new Rectangle(mnx, mny, mxx-mnx+1, mxy-mny+1); return keep;
  }
  // returns "w,h" of the scaled frame; writes strip PNG: [base | primary mask | secondary mask | glow]
  // stacked = grayscale on the top half and the color mask on the bottom half (instead of left/right columns)
  public static string Part(string src, int row, int rows, double scale, string outPath) { return Part(src, row, rows, scale, outPath, false); }
  public static string Part(string src, int row, int rows, double scale, string outPath, bool stacked) { return Part(src, row, rows, scale, outPath, stacked, 0, 0); }
  // fixW/fixH > 0: frame is at least that big and the art is anchored to its left edge (so animation frames of one
  // weapon, e.g. a pile bunker with its spike in and out, share one scale and grip point)
  public static string Part(string src, int row, int rows, double scale, string outPath, bool stacked, int fixW, int fixH) {
    var bmp = new Bitmap(src); int st; var p = Read(bmp, out st); int W = bmp.Width, H = bmp.Height; bmp.Dispose();
    int hw = W/2, ry0 = row*H/rows, ry1 = (row+1)*H/rows;
    Rectangle g, c;
    bool[] kg = stacked ? Keep(p, st, W, H, 0, 0, W, H/2, out g) : Keep(p, st, W, H, 0, ry0, hw, ry1, out g);
    bool[] kc = stacked ? Keep(p, st, W, H, 0, H/2, W, H, out c) : Keep(p, st, W, H, hw, ry0, W, ry1, out c);
    int w = Math.Max(Math.Max(g.Width, c.Width), fixW), h = Math.Max(Math.Max(g.Height, c.Height), fixH);
    // align by bbox centers, then nudge the color layer to where the two silhouettes overlap best
    // (a glow halo on one side of the color art would otherwise drag its centre off the grayscale art)
    int gx = fixW > 0 ? g.X : g.X + g.Width/2 - w/2, gy = g.Y + g.Height/2 - h/2, cx = fixW > 0 ? c.X : c.X + c.Width/2 - w/2, cy = c.Y + c.Height/2 - h/2;
    {
      int bdx = 0, bdy = 0; double best = -1;
      for (int dy=-10; dy<=10; dy+=1) for (int dx=-30; dx<=30; dx+=1) {
        int both = 0, either = 0;
        for (int y=0; y<h; y+=3) for (int x=0; x<w; x+=3) {
          int sx = gx+x, sy = gy+y, tx = cx+x+dx, ty = cy+y+dy;
          bool a = sx>=0&&sx<W&&sy>=0&&sy<H&&kg[sy*W+sx]&&p[sy*st+sx*4+3]>100;
          bool b = tx>=0&&tx<W&&ty>=0&&ty<H&&kc[ty*W+tx]&&p[ty*st+tx*4+3]>100;
          if (a&&b) both++; if (a||b) either++;
        }
        double iou = either > 0 ? (double)both/either : 0;
        if (iou > best + 1e-9 || (Math.Abs(iou-best) < 1e-9 && Math.Abs(dx)+Math.Abs(dy) < Math.Abs(bdx)+Math.Abs(bdy))) { best = iou; bdx = dx; bdy = dy; }
      }
      cx += bdx; cy += bdy;
    }
    int pad = 4; int fw = w + pad*2, fh = h + pad*2;
    var outp = new byte[fw*4*4*fh];
    int ost = fw*4*4;
    for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
      int sx = gx+x, sy = gy+y, tx = cx+x, ty = cy+y;
      byte gb=0,gg=0,gr=0,ga=0; if (sx>=0&&sx<W&&sy>=0&&sy<H&&kg[sy*W+sx]){int i=sy*st+sx*4; gb=p[i];gg=p[i+1];gr=p[i+2];ga=p[i+3];}
      double cb=0,cg=0,cr=0,ca=0; if (tx>=0&&tx<W&&ty>=0&&ty<H&&kc[ty*W+tx]){int i=ty*st+tx*4; cb=p[i];cg=p[i+1];cr=p[i+2];ca=p[i+3];}
      int o = (y+pad)*ost + (x+pad)*4;
      byte lum = (byte)Math.Round(0.299*gr + 0.587*gg + 0.114*gb); // desaturate: base must be pure gray
      outp[o]=lum; outp[o+1]=lum; outp[o+2]=lum; outp[o+3]=ga;
      double aa = (ca/255.0) * (ga/255.0);
      // classify the mask color by hue (lime trim carries a lot of red, cyan lights a lot of green, so channel margins
      // under-count them); saturation and brightness decide how strongly, so shading and highlights stay fully masked
      double mx = Math.Max(cr, Math.Max(cg, cb)), mn = Math.Min(cr, Math.Min(cg, cb)), sat = mx > 0 ? (mx - mn) / mx : 0, hue = 0;
      if (mx > mn) { if (mx == cr) hue = 60 * (((cg - cb) / (mx - mn)) % 6); else if (mx == cg) hue = 60 * ((cb - cr) / (mx - mn) + 2); else hue = 60 * ((cr - cg) / (mx - mn) + 4); if (hue < 0) hue += 360; }
      double str = C((sat - 0.22) / 0.2) * C((mx - 35) / 40.0);
      double prim = (hue < 25 || hue > 330 ? str : 0) * aa;
      double sec  = (hue >= 50 && hue <= 170 ? str : 0) * aa;
      double glo  = (hue >= 175 && hue <= 260 ? str : 0) * (ca/255.0) * (ga > 8 ? 1 : 0); // lights only on the art
      int o1 = o + fw*4, o2 = o + fw*8, o3 = o + fw*12;
      outp[o1]=255;outp[o1+1]=255;outp[o1+2]=255;outp[o1+3]=(byte)(prim*255);
      outp[o2]=255;outp[o2+1]=255;outp[o2+2]=255;outp[o2+3]=(byte)(sec*255);
      outp[o3]=(byte)cb;outp[o3+1]=(byte)cg;outp[o3+2]=(byte)cr;outp[o3+3]=(byte)(glo*255);
    }
    var full = Make(fw*4, fh, outp);
    int sw = (int)Math.Round(fw*scale), sh = (int)Math.Round(fh*scale);
    var small = new Bitmap(sw*4, sh, PixelFormat.Format32bppArgb);
    using (var gfx = Graphics.FromImage(small)) {
      gfx.InterpolationMode = InterpolationMode.HighQualityBicubic; gfx.PixelOffsetMode = PixelOffsetMode.HighQuality; gfx.CompositingMode = CompositingMode.SourceCopy;
      var ia = new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY);
      for (int k=0;k<4;k++) gfx.DrawImage(full, new Rectangle(k*sw,0,sw,sh), k*fw, 0, fw, fh, GraphicsUnit.Pixel, ia);
    }
    small.Save(outPath, ImageFormat.Png); small.Dispose(); full.Dispose();
    return sw + "," + sh + " (gray " + g.Width + "x" + g.Height + " color " + c.Width + "x" + c.Height + ")";
  }
}
'@
# Sheets that are no longer in src/img are skipped (their sprites in the output folder are kept), so the numbering stays stable.
$mechs = @('Four Mecha Component Sprites','Top-Down Mech Booster and Torso Color Study','Top-Down Mecha Blueprint Spritesheet','Top-Down Mecha Booster and Torso Color Study','Top-Down Mecha Components Sprite Sheet','Oni Mech Components_ Grayscale and RGB Masks','Red-Lime Mech Chassis Blueprint','Sci-Fi Mech Booster and Cockpit Asset Sheet','Vibrant Mecha Booster and Torso Set','Futuristic Spaceship Icon Grid','Neon Sci‑Fi Ship Component Sprite Sheet','Sci-Fi Mech Sprite Sheet Variants')
New-Item -ItemType Directory -Force $Out | Out-Null
$o = (Resolve-Path $Out).Path
function Sheet($name) { $f = Join-Path $Src ($name + '.png'); if (Test-Path -LiteralPath $f) { return (Resolve-Path -LiteralPath $f).Path }; "skip (not in src/img): $name" | Write-Host; return $null }
for ($i=0; $i -lt $mechs.Count; $i++) {
  $f = Sheet $mechs[$i]; if (-not $f) { continue }
  $b = [Prep]::Part($f, 0, 2, $Scale, (Join-Path $o "mech$i`_booster.png"))
  $t = [Prep]::Part($f, 1, 2, $Scale, (Join-Path $o "mech$i`_torso.png"))
  "mech$i booster $b | torso $t"
}
# funnel drones: 4 designs, one per row (0 assault, 1 medic, 2 guard, 3 fang)
$fs = Sheet 'Sci-Fi Fin Drone Module Sprite Sheet'
if ($fs) { for ($r=0; $r -lt 4; $r++) { $d = [Prep]::Part($fs, $r, 4, $Scale * 0.5, (Join-Path $o "funnel$r.png")); "funnel$r $d" } }
# hand weapons (barrel/blade pointing right): grayscale left + color mask right, except the railgun sheet (stacked)
$weapons = [ordered]@{ autocannon = 'autocannon_mk1_transparent'; beam = 'Twin Sci-Fi Beam Rifles'; chainsword = 'Dual Chainsword Sprite Sheet'; flamer = 'Flamer Mk I Sprite Sheet'; missilepod = 'Missile Pod Mk I Sprite Pair'; railgun = 'Twin Railgun Sprites_ Grayscale and Color Mask'; gauss = 'Twin Sci-Fi Gauss Weapons'; sword = 'Dual-Variant Sci-Fi Energy Swords'; esword = 'Dual Energy Swords_ Grayscale and Neon' }
foreach ($k in $weapons.Keys) { $f = Sheet $weapons[$k]; if (-not $f) { continue }; $d = [Prep]::Part($f, 0, 1, $Scale * 0.55, (Join-Path $o "wpn_$k.png"), ($k -eq 'railgun')); "wpn_$k $d" }
# multi-row weapon sheets: each row is a frame -> wpn_<name><row>.png
#   gatling: barrel-spin animation | pulse: 1/2/3 coil rings lit (charge display) | scatter: Mk tier variants
$framed = [ordered]@{ gatling = @('Gatling Cannon Mk I Sprite Sheet', 4); pulse = @('Pulse_rifle', 3); scatter = @('Scattergun', 4); ion = @('Ion Cannon', 1); plasma = @('Plasma Cannon', 1); hammer = @('Dual Sci‑Fi Thunder Hammers', 1) }
foreach ($k in $framed.Keys) { $f = Sheet $framed[$k][0]; if (-not $f) { continue }; $rows = $framed[$k][1]
  for ($r = 0; $r -lt $rows; $r++) { $name = if ($rows -gt 1) { "$k$r" } else { $k }; $d = [Prep]::Part($f, $r, $rows, $Scale * 0.55, (Join-Path $o "wpn_$name.png")); "wpn_$name $d" } }
# pile bunker: row 1 = spike retracted, row 2 = spike fired. The retracted art is drawn bigger on the sheet, so it is
# scaled down until its body is as thick as the fired one, then padded (anchored at the grip) to the fired frame's size,
# so both frames share one scale and grip point in game.
$pb = Sheet 'Armored Mecha Pile-Bunker Sprite Sheet'
if ($pb) {
  $d1 = [Prep]::Part($pb, 1, 2, $Scale * 0.55, (Join-Path $o 'wpn_pile1.png')); "wpn_pile1 $d1"
  $probe = [Prep]::Part($pb, 0, 2, 1, (Join-Path $env:TEMP 'pile0_probe.png')); Remove-Item (Join-Path $env:TEMP 'pile0_probe.png') -ErrorAction SilentlyContinue
  if ($d1 -match 'gray (\d+)x(\d+)') { $w1 = [int]$matches[1]; $h1 = [int]$matches[2]
    if ($probe -match 'gray (\d+)x(\d+)') { $k = $h1 / [double]$matches[2]
      $d0 = [Prep]::Part($pb, 0, 2, $Scale * 0.55 * $k, (Join-Path $o 'wpn_pile0.png'), $false, [int][Math]::Round($w1 / $k), [int]$matches[2]); "wpn_pile0 $d0 (x$([Math]::Round($k,3)))" } }
}

