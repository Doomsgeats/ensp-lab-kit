param(
  [string]$Title = 'SB',
  [string]$Out = 'C:\cap\igmp\out\shot.png',
  [string]$Cmds = '',
  [int]$Width = 0,
  [int]$Height = 0
)
$ErrorActionPreference = 'Continue'
$wsP = 'C:\cap\igmp\ws.cs'
$cs = @'
using System;
using System.Text;
using System.Runtime.InteropServices;
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
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
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
Set-Content -Path $wsP -Value $cs -Encoding UTF8
Add-Type -Path $wsP
[WS]::SetProcessDPIAware() | Out-Null

$h = [WS]::Find($Title)
if ($h -eq [IntPtr]::Zero) { Write-Output "window not found: $Title"; exit 1 }
[WS]::ShowWindow($h, 9) | Out-Null
[WS]::BringWindowToTop($h) | Out-Null
[WS]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 500
if ($Width -gt 0 -and $Height -gt 0) {
  [WS]::MoveWindow($h, 60, 60, $Width, $Height, $true) | Out-Null
  Start-Sleep -Milliseconds 900
}
$r = ([WS]::RectOf($h)) -split ','
$L = [int]$r[0]; $T = [int]$r[1]; $W = [int]$r[2]; $H = [int]$r[3]
$cx = $L + [int]($W / 2); $cy = $T + $H - 120
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\cap\igmp\ui.ps1' -Action click -Arg1 $cx -Arg2 $cy 2>$null | Out-Null
Start-Sleep -Milliseconds 600

if ($Cmds -ne '') {
  foreach ($line in ($Cmds -split '\|\|')) {
    $cl = $line.Trim()
    if ($cl -eq '') { continue }
    if ($cl -eq 'CLS') {
      $pad = ('{ENTER}' * 60)
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\cap\igmp\ui.ps1' -Action type -Arg1 $pad 2>$null | Out-Null
      Start-Sleep -Milliseconds 1800
      continue
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\cap\igmp\ui.ps1' -Action type -Arg1 ($cl + '{ENTER}') 2>$null | Out-Null
    Start-Sleep -Milliseconds 2600
  }
}
Start-Sleep -Milliseconds 3800

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 2560, 1600
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$g.Dispose()
if ($L -lt 0) { $W = $W + $L; $L = 0 }
if ($T -lt 0) { $H = $H + $T; $T = 0 }
if (($L + $W) -gt 2560) { $W = 2560 - $L }
if (($T + $H) -gt 1600) { $H = 1600 - $T }
Write-Output ("crop " + $L + "," + $T + " " + $W + "x" + $H)
$rect = [System.Drawing.Rectangle]::new($L, $T, $W, $H)
$crop = $bmp.Clone($rect, $bmp.PixelFormat)
$crop.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose(); $bmp.Dispose()
Write-Output ("saved " + $Out + " " + $W + "x" + $H)