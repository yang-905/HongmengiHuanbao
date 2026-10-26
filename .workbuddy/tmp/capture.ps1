Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win2 {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint procId);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetDesktopWindow();
  [DllImport("user32.dll")] public static extern IntPtr GetWindowDC(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
  [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int w, int h, IntPtr hdcSrc, int xSrc, int ySrc, uint rop);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$outDir = 'D:\11\carbon-master\.workbuddy\tmp'
$procIdMap = @{}
$found = New-Object System.Collections.ArrayList
$cb = [Win2+EnumWindowsProc]{
  param($h, $l)
  if ([Win2]::IsWindowVisible($h)) {
    $len = [Win2]::GetWindowTextLength($h)
    $sb = New-Object System.Text.StringBuilder ($len + 2)
    [void][Win2]::GetWindowText($h, $sb, $sb.Capacity)
    $t = $sb.ToString()
    $prc = 0
    [void][Win2]::GetWindowThreadProcessId($h, [ref]$prc)
    $r = New-Object Win2+RECT
    [void][Win2]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
    if ($w -gt 300 -and $hh -gt 300 -and $r.Left -gt -30000) {
      [void]$found.Add([pscustomobject]@{H=[int64]$h; Title=$t; PID=$prc; X=$r.Left; Y=$r.Top; W=$w; HH=$hh})
    }
  }
  return $true
}
[void][Win2]::EnumWindows($cb, [IntPtr]::Zero)
$found | Format-Table -AutoSize Title,PID,X,Y,W,HH -Wrap

# capture each big window with PrintWindow (PW_RENDERFULLCONTENT = 2)
foreach ($w in $found) {
  if ($w.PID -ne 64340) { continue }
  $bmp = New-Object System.Drawing.Bitmap $w.W, $w.HH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  $ok = [Win2]::PrintWindow([IntPtr]$w.H, $hdc, 2)
  $g.ReleaseHdc($hdc)
  $g.Dispose()
  $name = Join-Path $outDir ('win_' + $w.PID + '_' + ([string]$w.H) + '.png')
  $bmp.Save($name, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "saved $name PrintWindow=$ok"
}
