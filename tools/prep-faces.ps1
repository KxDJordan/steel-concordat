# Builds src/img/faces/faceN.png (+ faceN_suit.png) from the pilot face sheets in src/img/face.
# Sheet layout: 8 rows of pilots x 5 columns of expressions (Neutral, Happy, Shaken, Broken, Fierce).
# Output per pilot: a strip of 5 square cells (bust bottom-aligned), and a matching suit mask strip that holds the
# armour's grayscale shading (alpha = how much is suit) so the game can tint the suit in the guild colour.
# Clean-up: each cell keeps only real shapes (specks / bits of the neighbouring cell are dropped) and the red matting
# fringe some sheets have around the hair is removed.
# Usage (from repo root): powershell -ExecutionPolicy Bypass -File tools/prep-faces.ps1 [-Size 160]
param([string]$Src = "src/img/face", [string]$Out = "src/img/faces", [int]$Size = 160)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Runtime.InteropServices;
public static class Faces {
  static double C(double v){ return v<0?0:v>1?1:v; }
  public static int Sheet(string src, string outDir, int start, int size) {
    var bmp = new Bitmap(src); int W = bmp.Width, H = bmp.Height;
    var d = bmp.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    int st = d.Stride; var p = new byte[st*H]; Marshal.Copy(d.Scan0, p, 0, p.Length); bmp.UnlockBits(d); bmp.Dispose();
    double cw = W / 5.0, ch = H / 8.0; int side = (int)Math.Ceiling(Math.Max(cw, ch) * 1.08);
    // cut lines go through the emptiest gap near each expected boundary (the faces are not on a perfect grid)
    Func<int[], int, double, int> gap = (prof, at, win) => { int best = at, bv = int.MaxValue; for (int k = Math.Max(1, at - (int)win); k <= Math.Min(prof.Length - 2, at + (int)win); k++) { int v = prof[k] * 4 + Math.Abs(k - at); if (v < bv) { bv = v; best = k; } } return best; };
    var rowProf = new int[H]; for (int y=0;y<H;y++) for (int x=0;x<W;x++) if (p[y*st+x*4+3] > 30) rowProf[y]++;
    var rows = new int[9]; rows[0] = 0; rows[8] = H; for (int k=1;k<8;k++) rows[k] = gap(rowProf, (int)(k*ch), ch*0.22);
    for (int row = 0; row < 8; row++) {
      var colProf = new int[W]; for (int y=rows[row];y<rows[row+1];y++) for (int x=0;x<W;x++) if (p[y*st+x*4+3] > 30) colProf[x]++;
      var cols = new int[6]; cols[0] = 0; cols[5] = W; for (int k=1;k<5;k++) cols[k] = gap(colProf, (int)(k*cw), cw*0.25);
      var stripB = new Bitmap(size*5, size, PixelFormat.Format32bppArgb); var stripM = new Bitmap(size*5, size, PixelFormat.Format32bppArgb);
      using (var gb = Graphics.FromImage(stripB)) using (var gm = Graphics.FromImage(stripM)) {
        gb.InterpolationMode = gm.InterpolationMode = InterpolationMode.HighQualityBicubic; gb.PixelOffsetMode = gm.PixelOffsetMode = PixelOffsetMode.HighQuality;
        for (int col = 0; col < 5; col++) {
          int x0 = cols[col], y0 = rows[row], x1 = cols[col+1], y1 = rows[row+1], w = x1-x0, h = y1-y0;
          // components: keep shapes >= 2% of the biggest one
          var lab = new int[w*h]; var sizes = new System.Collections.Generic.List<int>(); sizes.Add(0); var q = new System.Collections.Generic.Stack<int>();
          Func<int,int,byte> A = (x,y) => p[(y0+y)*st+(x0+x)*4+3];
          for (int y=0;y<h;y++) for (int x=0;x<w;x++) { if (lab[y*w+x]!=0 || A(x,y)<=20) continue; int id = sizes.Count, n = 0; lab[y*w+x]=id; q.Push(y*w+x);
            while (q.Count>0) { int c=q.Pop(); n++; int cx=c%w, cy=c/w; for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) { int nx=cx+dx, ny=cy+dy; if (nx<0||ny<0||nx>=w||ny>=h) continue; if (lab[ny*w+nx]!=0||A(nx,ny)<=20) continue; lab[ny*w+nx]=id; q.Push(ny*w+nx);} }
            sizes.Add(n); }
          int big = 0; foreach (var n in sizes) if (n > big) big = n;
          var cb = new byte[side*side*4]; var cm = new byte[side*side*4];
          int ox = (side - w)/2, oy = side - h; // bottom-aligned, centred
          var sm = new double[w*h]; var lu = new double[w*h];
          int top = h; for (int y=0;y<h && top==h;y++) for (int x=0;x<w;x++) { int l=lab[y*w+x]; if (l!=0 && sizes[l]*50>=big) { top=y; break; } }
          int band = top + (int)((h - top) * 0.62); // suit lives in the lower part of the bust
          // silver/white/gray-haired pilots: hair looks like armour, so only darker, flatter grays count as suit
          int hn = 0, hs = 0; for (int y=top; y<top+(h-top)/5; y++) for (int x=0;x<w;x++) { if (A(x,y) < 200) continue; int ii=(y0+y)*st+(x0+x)*4; double mx2=Math.Max(p[ii+2],Math.Max(p[ii+1],p[ii])), mn2=Math.Min(p[ii+2],Math.Min(p[ii+1],p[ii])); hn++; if (mx2 > 120 && (mx2-mn2)/mx2 < 0.16) hs++; }
          bool silver = hn > 0 && hs * 2 > hn; double lumHi = silver ? 168 : 205;
          for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
            int l = lab[y*w+x]; bool keep = l!=0 && sizes[l]*50>=big;
            // grow kept shapes by 1px for soft edges
            if (!keep) for (int dy=-1;dy<=1&&!keep;dy++) for (int dx=-1;dx<=1&&!keep;dx++) { int nx=x+dx, ny=y+dy; if (nx>=0&&ny>=0&&nx<w&&ny<h){ int l2=lab[ny*w+nx]; if (l2!=0&&sizes[l2]*50>=big) keep=true; } }
            if (!keep) continue;
            int i = (y0+y)*st+(x0+x)*4; double B = p[i], G = p[i+1], R = p[i+2], a = p[i+3];
            // red matting fringe next to transparency
            if (R > 140 && G < 90 && B < 90) { bool edge = false; for (int dy=-3;dy<=3&&!edge;dy++) for (int dx=-3;dx<=3&&!edge;dx++) { int nx=x+dx, ny=y+dy; if (nx<0||ny<0||nx>=w||ny>=h||A(nx,ny)<40) edge=true; } if (edge) continue; }
            int o = ((oy+y)*side + ox+x)*4; cb[o]=(byte)B; cb[o+1]=(byte)G; cb[o+2]=(byte)R; cb[o+3]=(byte)a;
            if (y < band) continue;
            double mx = Math.Max(R,Math.Max(G,B)), mn = Math.Min(R,Math.Min(G,B)), sat = mx>0?(mx-mn)/mx:0, lum = 0.299*R+0.587*G+0.114*B;
            double s = C((0.26 - sat)/0.08) * C((lum - 30)/22.0) * C((lumHi - lum)/22.0) * C((y - band)/6.0);
            if (s <= 0.02) continue;
            sm[y*w+x] = s * a / 255.0;
          }
          for (int y=0;y<h;y++) for (int x=0;x<w;x++) { int i=(y0+y)*st+(x0+x)*4; lu[y*w+x] = 0.299*p[i+2]+0.587*p[i+1]+0.114*p[i]; }
          // armour is broad and smooth; hair/beard is fine texture: damp the mask where local contrast is high
          var s2 = new double[w*h];
          for (int y=0;y<h;y++) for (int x=0;x<w;x++) { if (sm[y*w+x] <= 0) continue; double m1=0, m2=0; int c=0;
            for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) { int nx=x+dx, ny=y+dy; if (nx<0||ny<0||nx>=w||ny>=h) continue; double v=lu[ny*w+nx]; m1+=v; m2+=v*v; c++; }
            double sd = Math.Sqrt(Math.Max(0, m2/c - (m1/c)*(m1/c))); s2[y*w+x] = sm[y*w+x] * C((34 - sd)/16.0); }
          // opening (erode then dilate, radius 2) drops thin strands; a final 3x3 blur keeps the tint edge soft
          Func<double[], bool, double[]> morph = (inp, ero) => { var r = new double[w*h]; for (int y=0;y<h;y++) for (int x=0;x<w;x++) { double v = ero ? 1e9 : 0; for (int dy=-2;dy<=2;dy++) for (int dx=-2;dx<=2;dx++) { int nx=x+dx, ny=y+dy; double q2 = (nx<0||ny<0||nx>=w||ny>=h) ? 0 : inp[ny*w+nx]; v = ero ? Math.Min(v,q2) : Math.Max(v,q2); } r[y*w+x] = v; } return r; };
          var op = morph(morph(s2, true), false);
          for (int y=0;y<h;y++) for (int x=0;x<w;x++) { double v = Math.Min(op[y*w+x], s2[y*w+x] * 1.15 + 0.1);
            double bl = 0; int c=0; for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) { int nx=x+dx, ny=y+dy; if (nx<0||ny<0||nx>=w||ny>=h) continue; bl += Math.Min(op[ny*w+nx], s2[ny*w+nx]*1.15+0.1); c++; } v = Math.Min(1, bl/c);
            if (v <= 0.02) continue; int o = ((oy+y)*side + ox+x)*4; byte L = (byte)Math.Round(lu[y*w+x]); cm[o]=L; cm[o+1]=L; cm[o+2]=L; cm[o+3]=(byte)(255*v); }
          Action<Graphics, byte[]> put = (g, buf) => { var t = new Bitmap(side, side, PixelFormat.Format32bppArgb); var td = t.LockBits(new Rectangle(0,0,side,side), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb); Marshal.Copy(buf, 0, td.Scan0, buf.Length); t.UnlockBits(td);
            var ia = new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY); g.DrawImage(t, new Rectangle(col*size,0,size,size), 0,0,side,side, GraphicsUnit.Pixel, ia); t.Dispose(); };
          put(gb, cb); put(gm, cm);
        }
      }
      stripB.Save(System.IO.Path.Combine(outDir, "face" + (start+row) + ".png"), ImageFormat.Png); stripM.Save(System.IO.Path.Combine(outDir, "face" + (start+row) + "_suit.png"), ImageFormat.Png);
      stripB.Dispose(); stripM.Dispose();
    }
    return 8;
  }
}
'@
New-Item -ItemType Directory -Force $Out | Out-Null
$o = (Resolve-Path $Out).Path; $n = 0
foreach ($f in (Get-ChildItem $Src -Filter 'Pilot*.png' | Sort-Object { [int]($_.BaseName -replace '\D', '') })) { $n += [Faces]::Sheet($f.FullName, $o, $n, $Size); "$($f.Name) -> faces $($n-8)..$($n-1)" }
"total faces: $n"
