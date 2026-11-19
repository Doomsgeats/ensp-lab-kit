param(
  [string]$Action = 'shot',
  [string]$Arg1 = '',
  [string]$Arg2 = ''
)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
$cs = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Ui {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  public struct RECT { public int L, T, R, B; }
  public static void Click(int x, int y) {
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    mouse_event(0x02, 0, 0, 0, IntPtr.Zero); mouse_event(0x04, 0, 0, 0, IntPtr.Zero);
  }
  public static void RClick(int x, int y) {
    SetCursorPos(x, y); System.Threading.Thread.Sleep(120);
    mouse_event(0x08, 0, 0, 0, IntPtr.Zero); mouse_event(0x10, 0, 0, 0, IntPtr.Zero);
  }
  public static void DClick(int x, int y) {
    SetCursorPos(x, y); System.Threading.Thread.Sleep(150);
    mouse_event(0x02, 0, 0, 0, IntPtr.Zero); mouse_event(0x04, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    mouse_event(0x02, 0, 0, 0, IntPtr.Zero); mouse_event(0x04, 0, 0, 0, IntPtr.Zero);
  }
  public static List<string> Windows() {
    var list = new List<string>();
    EnumWindows((h, p) => {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512);
      GetWindowText(h, sb, 512);
      string t = sb.ToString();
      if (t.Length == 0) return true;
      uint pid; GetWindowThreadProcessId(h, out pid);
      RECT r; GetWindowRect(h, out r);
      list.Add(h.ToInt64() + "|" + pid + "|" + (r.R - r.L) + "x" + (r.B - r.T) + "|" + t);
      return true;
    }, IntPtr.Zero);
    return list;
  }
}
'@
Add-Type -TypeDefinition $cs -ErrorAction SilentlyContinue
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Dpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@ -ErrorAction SilentlyContinue
[Dpi]::SetProcessDPIAware() | Out-Null

function Shot([string]$path) {
  $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  "shot $path"
}

switch ($Action) {
  'windows' { [Ui]::Windows() | ForEach-Object { $_ } }
  'shot'    { Shot $Arg1 }
  'click'   { [Ui]::Click([int]$Arg1, [int]$Arg2); "click $Arg1,$Arg2" }
  'dclick'  { [Ui]::DClick([int]$Arg1, [int]$Arg2); "dclick $Arg1,$Arg2" }
  'rclick'  { [Ui]::RClick([int]$Arg1, [int]$Arg2); "rclick $Arg1,$Arg2" }
  'minall'  {
    foreach ($w in [Ui]::Windows()) {
      $parts = $w.Split('|')
      if ($parts[3] -match 'eNSP') { continue }
      [Ui]::ShowWindow([IntPtr][int64]$parts[0], 6) | Out-Null
    }
    'minimized others'
  }
  'maxensp' {
    foreach ($w in [Ui]::Windows()) {
      $parts = $w.Split('|')
      if ($parts[3] -match 'eNSP') {
        [Ui]::ShowWindow([IntPtr][int64]$parts[0], 3) | Out-Null
        [Ui]::SetForegroundWindow([IntPtr][int64]$parts[0]) | Out-Null
        "maximized: $($parts[3])"
      }
    }
  }
  'focus' {
    foreach ($w in [Ui]::Windows()) {
      $parts = $w.Split('|')
      if ($parts[3] -match $Arg1) {
        [Ui]::ShowWindow([IntPtr][int64]$parts[0], 3) | Out-Null
        [Ui]::SetForegroundWindow([IntPtr][int64]$parts[0]) | Out-Null
        "focused: $($parts[3])"
      }
    }
  }
  'keys'  { [System.Windows.Forms.SendKeys]::SendWait($Arg1); "keys $Arg1" }
  'type'  { [System.Windows.Forms.SendKeys]::SendWait($Arg1); "type $Arg1" }
  default { 'unknown action' }
}