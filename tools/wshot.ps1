param([string]$Title = 'SB', [string]$Out = 'C:\cap\igmp\out\shot.png')
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$cs = @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class WS {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Find(string title) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var s = new StringBuilder(256); GetWindowTextW(h, s, 256);
      if (s.ToString().Trim() == title.Trim()) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static string RectOf(IntPtr h) {
    RECT r; GetWindowRect(h, out r);
    return r.L + "," + r.T + "," + (r.R - r.L) + "," + (r.B - r.T);
  }
}
'@
Set-Content -Path 'C:\cap\igmp\ws.cs' -Value $cs -Encoding UTF8
Add-Type -Path 'C:\cap\igmp\ws.cs'
[WS]::SetProcessDPIAware() | Out-Null
$h = [WS]::Find($Title)
if ($h -eq [IntPtr]::Zero) { Write-Output "window not found: $Title"; exit 1 }
[WS]::ShowWindow($h, 5) | Out-Null
[WS]::BringWindowToTop($h) | Out-Null
[WS]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 700
$r = ([WS]::RectOf($h)) -split ','
$w = [int]$r[2]; $hgt = [int]$r[3]
$bmp = New-Object System.Drawing.Bitmap 2560, 1600
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$g.Dispose()
$crop = New-Object System.Drawing.Bitmap $w, $hgt
$g2 = [System.Drawing.Graphics]::FromImage($crop)
$g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $w, $hgt), (New-Object System.Drawing.Rectangle ([int]$r[0]), ([int]$r[1]), $w, $hgt), [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$crop.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $bmp.Dispose()
Write-Output ("saved " + $Out + " " + $w + "x" + $hgt)