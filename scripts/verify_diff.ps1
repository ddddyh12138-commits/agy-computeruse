param(
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [int]$XMin = 0,
    [int]$XMax = 99999,
    [int]$YMin = 0,
    [int]$YMax = 99999,
    [int]$Threshold = 15,
    [int]$Pad = 40,
    [string]$CropDiffPath = ""
)

Add-Type -AssemblyName System.Drawing

$code = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class FastImgDiff {
    public struct DiffResult {
        public long ChangedPixels;
        public long TotalPixels;
        public int MinX;
        public int MinY;
        public int MaxX;
        public int MaxY;
    }

    public static DiffResult Compare(Bitmap bmpA, Bitmap bmpB, int x0, int y0, int x1, int y1, int threshold) {
        int w = Math.Min(bmpA.Width, bmpB.Width);
        int h = Math.Min(bmpA.Height, bmpB.Height);
        x0 = Math.Max(0, x0);
        y0 = Math.Max(0, y0);
        x1 = Math.Min(w, x1);
        y1 = Math.Min(h, y1);

        var res = new DiffResult {
            ChangedPixels = 0,
            TotalPixels = Math.Max(1L, (long)(x1 - x0) * (long)(y1 - y0)),
            MinX = x1, MinY = y1, MaxX = -1, MaxY = -1
        };
        if (x1 <= x0 || y1 <= y0) return res;

        Rectangle rect = new Rectangle(0, 0, w, h);
        BitmapData dA = bmpA.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData dB = bmpB.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            int strideA = dA.Stride;
            int strideB = dB.Stride;
            byte[] rowA = new byte[w * 4];
            byte[] rowB = new byte[w * 4];

            for (int y = y0; y < y1; y++) {
                Marshal.Copy(IntPtr.Add(dA.Scan0, y * strideA), rowA, 0, w * 4);
                Marshal.Copy(IntPtr.Add(dB.Scan0, y * strideB), rowB, 0, w * 4);
                for (int x = x0; x < x1; x++) {
                    int i = x * 4;
                    int db = Math.Abs(rowA[i] - rowB[i]);
                    int dg = Math.Abs(rowA[i + 1] - rowB[i + 1]);
                    int dr = Math.Abs(rowA[i + 2] - rowB[i + 2]);
                    if (dr > threshold || dg > threshold || db > threshold) {
                        res.ChangedPixels++;
                        if (x < res.MinX) res.MinX = x;
                        if (x > res.MaxX) res.MaxX = x;
                        if (y < res.MinY) res.MinY = y;
                        if (y > res.MaxY) res.MaxY = y;
                    }
                }
            }
        } finally {
            bmpA.UnlockBits(dA);
            bmpB.UnlockBits(dB);
        }
        return res;
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$bmpA = [System.Drawing.Bitmap]::FromFile($Before)
$bmpB = [System.Drawing.Bitmap]::FromFile($After)

try {
    $res = [FastImgDiff]::Compare($bmpA, $bmpB, $XMin, $YMin, $XMax, $YMax, $Threshold)
    $pct = ($res.ChangedPixels * 100.0) / $res.TotalPixels
    $status = if ($res.ChangedPixels -lt 50 -and $pct -lt 0.005) { "NO_CHANGE" } elseif ($pct -gt 40.0) { "MAJOR_CHANGE" } else { "CHANGED" }

    if ($res.ChangedPixels -gt 0) {
        $bbox = "($($res.MinX),$($res.MinY),$($res.MaxX),$($res.MaxY))"
        if ($CropDiffPath -ne "") {
            $cx0 = [Math]::Max(0, $res.MinX - $Pad)
            $cy0 = [Math]::Max(0, $res.MinY - $Pad)
            $cx1 = [Math]::Min($bmpB.Width, $res.MaxX + $Pad + 1)
            $cy1 = [Math]::Min($bmpB.Height, $res.MaxY + $Pad + 1)
            $cw = $cx1 - $cx0
            $ch = $cy1 - $cy0
            if ($cw -gt 0 -and $ch -gt 0) {
                $crop = $bmpB.Clone((New-Object System.Drawing.Rectangle($cx0, $cy0, $cw, $ch)), $bmpB.PixelFormat)
                $crop.Save($CropDiffPath)
                $crop.Dispose()
            }
        }
    } else {
        $bbox = "(0,0,0,0)"
    }

    Write-Output ("CHANGED_PCT={0:F4} CHANGED_PIXELS={1} DIFF_BBOX={2} STATUS={3}" -f $pct, $res.ChangedPixels, $bbox, $status)
} finally {
    $bmpA.Dispose()
    $bmpB.Dispose()
}
