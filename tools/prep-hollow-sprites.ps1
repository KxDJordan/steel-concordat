# Builds src/img/hollow/{drone,spitter}_*.png from the Hollow creature sheets in src/img (art faces right).
# Sheet layout: row 1 = head | mandibles (one C shape, split here into upper/lower jaw),
#               row 2 = abdomen | six legs (top three = left side, bottom three = right side),
#               row 3 = thorax ("tail" file; spans the row). Body order front to back: head, thorax, abdomen.
#               The thorax is used as drawn: its tip tucks under the head, its hollow end takes the abdomen.
# Prints each part's tight bounding box in sheet pixels; the in-game layout (HOLLOW_KINDS) uses those numbers.
# Usage (from repo root): powershell -ExecutionPolicy Bypass -File tools/prep-hollow-sprites.ps1 [-Scale 0.3]
param([string]$Src = "src/img/hollow_parts_true_transparent.png", [string]$Out = "src/img/hollow", [double]$Scale = 0.3)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Runtime.InteropServices;
public static class Hollow {
  static byte[] px; static int st, W, H;
  public static void Load(string src) {
    var b = new Bitmap(src); W = b.Width; H = b.Height;
    var d = b.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    st = d.Stride; px = new byte[st*H]; Marshal.Copy(d.Scan0, px, 0, px.Length); b.UnlockBits(d); b.Dispose();
  }
  // tight box of opaque pixels inside a search region
  public static Rectangle Box(int x0, int y0, int x1, int y1) {
    int a=int.MaxValue, b=int.MaxValue, c=-1, e=-1;
    for (int y=Math.Max(0,y0); y<Math.Min(H,y1); y++) for (int x=Math.Max(0,x0); x<Math.Min(W,x1); x++)
      if (px[y*st+x*4+3] > 20) { if(x<a)a=x; if(x>c)c=x; if(y<b)b=y; if(y>e)e=y; }
    return new Rectangle(a, b, c-a+1, e-b+1);
  }
  // largest 8-connected opaque shape inside a region, grown by 2px to keep its soft edge
  static bool[] Keep(int x0, int y0, int x1, int y1) {
    var lab = new int[W*H]; int best = 0, bestN = 0, cur = 0; var q = new System.Collections.Generic.Stack<int>();
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) {
      int p = y*W+x; if (lab[p] != 0 || px[y*st+x*4+3] <= 20) continue;
      cur++; int n = 0; lab[p] = cur; q.Push(p);
      while (q.Count > 0) { int c = q.Pop(); n++; int cx = c % W, cy = c / W;
        for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) { int nx = cx+dx, ny = cy+dy;
          if (nx<x0||nx>=x1||ny<y0||ny>=y1) continue; int np = ny*W+nx; if (lab[np] != 0 || px[ny*st+nx*4+3] <= 20) continue; lab[np] = cur; q.Push(np); } }
      if (n > bestN) { bestN = n; best = cur; }
    }
    var keep = new bool[W*H];
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) if (lab[y*W+x] == best)
      for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) { int nx=x+dx, ny=y+dy; if (nx>=x0&&nx<x1&&ny>=y0&&ny<y1) keep[ny*W+nx] = true; }
    return keep;
  }
  // crop the main shape of a region, pad, scale, optionally mirror, save
  public static string Save(int x0, int y0, int x1, int y1, double scale, bool flip, string outPath) {
    var keep = Keep(x0, y0, x1, y1);
    int a=int.MaxValue, b=int.MaxValue, c=-1, e=-1;
    for (int y=y0;y<y1;y++) for (int x=x0;x<x1;x++) if (keep[y*W+x] && px[y*st+x*4+3] > 0) { if(x<a)a=x; if(x>c)c=x; if(y<b)b=y; if(y>e)e=y; }
    var r = new Rectangle(a, b, c-a+1, e-b+1); int pad = 3;
    int w = r.Width + pad*2, h = r.Height + pad*2; var buf = new byte[w*h*4];
    for (int y=0;y<r.Height;y++) for (int x=0;x<r.Width;x++) {
      int sx = r.X + x, sy = r.Y + y; if (!keep[sy*W+sx]) continue;
      int i = sy*st + sx*4, tx = flip ? (w - 1 - (x+pad)) : (x+pad), o = ((y+pad)*w + tx)*4;
      buf[o]=px[i]; buf[o+1]=px[i+1]; buf[o+2]=px[i+2]; buf[o+3]=px[i+3];
    }
    var full = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    var d = full.LockBits(new Rectangle(0,0,w,h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb); Marshal.Copy(buf, 0, d.Scan0, buf.Length); full.UnlockBits(d);
    int sw = Math.Max(1,(int)Math.Round(w*scale)), sh = Math.Max(1,(int)Math.Round(h*scale));
    var small = new Bitmap(sw, sh, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(small)) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.CompositingMode = CompositingMode.SourceCopy;
      var ia = new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY);
      g.DrawImage(full, new Rectangle(0,0,sw,sh), 0, 0, w, h, GraphicsUnit.Pixel, ia);
    }
    small.Save(outPath, ImageFormat.Png); small.Dispose(); full.Dispose();
    return "box " + (r.X - pad) + "," + (r.Y - pad) + " " + w + "x" + h + " -> " + sw + "x" + sh;
  }
}
'@
New-Item -ItemType Directory -Force $Out | Out-Null
$o = (Resolve-Path $Out).Path
# one creature sheet: head/abdomen/tail regions, the jaw region (split in half), and the leg grid
function Cut-Creature($sheet, $prefix, $parts, $jaw, $cols, $rows) {
  [Hollow]::Load((Resolve-Path $sheet).Path)
  foreach ($k in $parts.Keys) { $p = $parts[$k]; "$prefix$k " + [Hollow]::Save($p[0], $p[1], $p[2], $p[3], $Scale, $p[4], (Join-Path $o "$prefix$k.png")) }
  # mandibles: split at the vertical middle into upper and lower jaw
  $m = [Hollow]::Box($jaw[0], $jaw[1], $jaw[2], $jaw[3]); $mid = $m.Y + [int]($m.Height / 2)
  "${prefix}jaw_top " + [Hollow]::Save($jaw[0], $jaw[1], $jaw[2], $mid, $Scale, $false, (Join-Path $o "${prefix}jaw_top.png"))
  "${prefix}jaw_bot " + [Hollow]::Save($jaw[0], $mid, $jaw[2], $jaw[3], $Scale, $false, (Join-Path $o "${prefix}jaw_bot.png"))
  # legs: three columns x two rows (row 1 = left side, claws up; row 2 = right side, claws down).
  # Each cell keeps only its largest connected shape, so a neighbour's claw poking in is dropped.
  for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 3; $c++) {
    "${prefix}leg$r$c " + [Hollow]::Save($cols[$c][0], $rows[$r][0], $cols[$c][1], $rows[$r][1], $Scale, $false, (Join-Path $o "${prefix}leg$r$c.png"))
  } }
}
Cut-Creature $Src 'drone_' ([ordered]@{ head = @(60, 50, 500, 440, $false); abdomen = @(20, 500, 515, 980, $false); tail = @(100, 1050, 960, 1530, $false) }) @(560, 50, 1000, 440) @(@(520, 662), @(662, 796), @(796, 1024)) @(@(460, 726), @(726, 1030))
Cut-Creature 'src/img/Alien Spitter Creature Parts Sprite Sheet.png' 'spitter_' ([ordered]@{ head = @(60, 20, 520, 460, $false); abdomen = @(15, 490, 515, 960, $false); tail = @(110, 1020, 930, 1520, $false) }) @(580, 50, 1000, 440) @(@(520, 660), @(660, 790), @(790, 1024)) @(@(460, 718), @(718, 1010))
