Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$list = New-Object System.Collections.ArrayList
$cb = [Win+EnumWindowsProc]{
  param($h, $l)
  if ([Win]::IsWindowVisible($h)) {
    $len = [Win]::GetWindowTextLength($h)
    $sb = New-Object System.Text.StringBuilder ($len + 2)
    [void][Win]::GetWindowText($h, $sb, $sb.Capacity)
    $t = $sb.ToString()
    $procId = 0
    [void][Win]::GetWindowThreadProcessId($h, [ref]$procId)
    $r = New-Object Win+RECT
    [void][Win]::GetWindowRect($h, [ref]$r)
    if ($t.Length -gt 0 -or ($r.Right - $r.Left) -gt 300) {
      [void]$list.Add([pscustomobject]@{H=[int64]$h; Title=$t; PID=$procId; X=$r.Left; Y=$r.Top; W=($r.Right-$r.Left); H2=($r.Bottom-$r.Top)})
    }
  }
  return $true
}
[void][Win]::EnumWindows($cb, [IntPtr]::Zero)
$list | Sort-Object PID | Format-Table -AutoSize Title,PID,X,Y,W,H2 -Wrap
