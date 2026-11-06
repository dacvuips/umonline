Add-Type -AssemblyName System.Drawing

$code = @"
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class WorldConverter {
    // 1. Convert OZJ / OZT to standard PNG
    public static void ConvertTexture(string srcPath, string outPath) {
        if (!File.Exists(srcPath)) return;
        string ext = Path.GetExtension(srcPath).ToUpperInvariant();
        byte[] bytes = File.ReadAllBytes(srcPath);
        if (bytes.Length < 24) return;

        if (ext == ".OZJ") {
            // Strip Webzen 24-byte header -> Standard JPEG
            byte[] jpeg = new byte[bytes.Length - 24];
            Buffer.BlockCopy(bytes, 24, jpeg, 0, jpeg.Length);
            using (var ms = new MemoryStream(jpeg))
            using (var bmp = new Bitmap(ms)) {
                bmp.Save(outPath, ImageFormat.Png);
            }
        } else if (ext == ".OZT") {
            // Strip Webzen 4-byte header -> Standard TGA
            byte[] tga = new byte[bytes.Length - 4];
            Buffer.BlockCopy(bytes, 4, tga, 0, tga.Length);
            using (var ms = new MemoryStream(tga))
            using (var br = new BinaryReader(ms)) {
                byte idLen = br.ReadByte();
                byte colormapType = br.ReadByte();
                byte imgType = br.ReadByte();
                ms.Seek(9, SeekOrigin.Current);
                short w = br.ReadInt16();
                short h = br.ReadInt16();
                byte bpp = br.ReadByte();
                byte descriptor = br.ReadByte();
                ms.Seek(idLen, SeekOrigin.Current);

                if (w > 0 && h > 0 && w < 4096 && h < 4096) {
                    PixelFormat pf = (bpp == 32) ? PixelFormat.Format32bppArgb : PixelFormat.Format24bppRgb;
                    using (var bmp = new Bitmap(w, h, pf)) {
                        var bmpData = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, pf);
                        int bytesPerPixel = bpp / 8;
                        int rowBytes = w * bytesPerPixel;
                        int totalBytes = w * h * bytesPerPixel;
                        byte[] pixelData = br.ReadBytes(totalBytes);
                        
                        bool topDown = (descriptor & 0x20) != 0;
                        for (int y = 0; y < h; y++) {
                            int srcY = topDown ? y : (h - 1 - y);
                            IntPtr dstRow = new IntPtr(bmpData.Scan0.ToInt64() + y * bmpData.Stride);
                            int srcOffset = srcY * rowBytes;
                            if (srcOffset + rowBytes <= pixelData.Length) {
                                Marshal.Copy(pixelData, srcOffset, dstRow, rowBytes);
                            }
                        }
                        bmp.UnlockBits(bmpData);
                        bmp.Save(outPath, ImageFormat.Png);
                    }
                }
            }
        }
    }

    // 2. Convert BMD model to OBJ + MTL
    public static bool ConvertBmd(string bmdPath, string outDir) {
        Directory.CreateDirectory(outDir);
        string modelName = Path.GetFileNameWithoutExtension(bmdPath);
        string objPath = Path.Combine(outDir, modelName + ".obj");
        string mtlPath = Path.Combine(outDir, modelName + ".mtl");

        try {
            using (var fs = File.OpenRead(bmdPath))
            using (var br = new BinaryReader(fs)) {
                byte[] magic = br.ReadBytes(3);
                byte ver = br.ReadByte();
                if (magic[0] != 'B' || magic[1] != 'M' || magic[2] != 'D' || ver != 0x0A) {
                    return false;
                }

                byte[] nameBytes = br.ReadBytes(32);
                short numMeshs = br.ReadInt16();
                short numBones = br.ReadInt16();
                short numActions = br.ReadInt16();

                var sbObj = new StringBuilder();
                var sbMtl = new StringBuilder();
                sbObj.AppendLine("# MU Online BMD Exporter");
                sbObj.AppendLine("mtllib " + modelName + ".mtl");

                int vOffset = 1;
                int nOffset = 1;
                int tOffset = 1;

                for (int m = 0; m < numMeshs; m++) {
                    short numV = br.ReadInt16();
                    short numN = br.ReadInt16();
                    short numT = br.ReadInt16();
                    short numTri = br.ReadInt16();
                    short texIdx = br.ReadInt16();

                    sbObj.AppendLine(string.Format("o Mesh_{0}", m));
                    sbObj.AppendLine(string.Format("usemtl Material_{0}", m));

                    // Read Vertices (16 bytes: short Node, short pad, float X, Y, Z)
                    for (int i = 0; i < numV; i++) {
                        short node = br.ReadInt16();
                        short pad = br.ReadInt16();
                        float x = br.ReadSingle();
                        float y = br.ReadSingle();
                        float z = br.ReadSingle();
                        // Scale 0.01 to match Godot meter units (MU uses centimeters)
                        // Convert Z-up to Y-up: Godot X = x, Godot Y = z, Godot Z = -y
                        sbObj.AppendLine(string.Format(System.Globalization.CultureInfo.InvariantCulture, "v {0:F4} {1:F4} {2:F4}", x * 0.01f, z * 0.01f, -y * 0.01f));
                    }

                    // Read Normals (20 bytes: short Node, short pad, float NX, NY, NZ, short BindV, short pad)
                    for (int i = 0; i < numN; i++) {
                        short node = br.ReadInt16();
                        short pad = br.ReadInt16();
                        float nx = br.ReadSingle();
                        float ny = br.ReadSingle();
                        float nz = br.ReadSingle();
                        short bindV = br.ReadInt16();
                        short pad2 = br.ReadInt16();
                        sbObj.AppendLine(string.Format(System.Globalization.CultureInfo.InvariantCulture, "vn {0:F4} {1:F4} {2:F4}", nx, nz, -ny));
                    }

                    // Read TexCoords (8 bytes: float U, V)
                    for (int i = 0; i < numT; i++) {
                        float u = br.ReadSingle();
                        float v = br.ReadSingle();
                        sbObj.AppendLine(string.Format(System.Globalization.CultureInfo.InvariantCulture, "vt {0:F4} {1:F4}", u, 1.0f - v));
                    }

                    // Read Triangles (64 bytes each: poly(1) + pad(1) + vIdx(8) + nIdx(8) + tIdx(8) + 38 bytes lightmap/pad = 64)
                    for (int i = 0; i < numTri; i++) {
                        byte poly = br.ReadByte();
                        byte pad = br.ReadByte();
                        short[] vIdx = new short[] { br.ReadInt16(), br.ReadInt16(), br.ReadInt16(), br.ReadInt16() };
                        short[] nIdx = new short[] { br.ReadInt16(), br.ReadInt16(), br.ReadInt16(), br.ReadInt16() };
                        short[] tIdx = new short[] { br.ReadInt16(), br.ReadInt16(), br.ReadInt16(), br.ReadInt16() };
                        br.BaseStream.Seek(38, SeekOrigin.Current); // LightMapCoord (32) + LightMapIndexes (2) + pad (4) = 38

                        if (poly == 3) {
                            int v1 = vOffset + vIdx[0];
                            int v2 = vOffset + vIdx[1];
                            int v3 = vOffset + vIdx[2];
                            int t1 = tOffset + tIdx[0];
                            int t2 = tOffset + tIdx[1];
                            int t3 = tOffset + tIdx[2];
                            int n1 = nOffset + nIdx[0];
                            int n2 = nOffset + nIdx[1];
                            int n3 = nOffset + nIdx[2];
                            sbObj.AppendLine(string.Format("f {0}/{1}/{2} {3}/{4}/{5} {6}/{7}/{8}", v1, t1, n1, v2, t2, n2, v3, t3, n3));
                        } else if (poly == 4) {
                            int v1 = vOffset + vIdx[0];
                            int v2 = vOffset + vIdx[1];
                            int v3 = vOffset + vIdx[2];
                            int v4 = vOffset + vIdx[3];
                            int t1 = tOffset + tIdx[0];
                            int t2 = tOffset + tIdx[1];
                            int t3 = tOffset + tIdx[2];
                            int t4 = tOffset + tIdx[3];
                            int n1 = nOffset + nIdx[0];
                            int n2 = nOffset + nIdx[1];
                            int n3 = nOffset + nIdx[2];
                            int n4 = nOffset + nIdx[3];
                            sbObj.AppendLine(string.Format("f {0}/{1}/{2} {3}/{4}/{5} {6}/{7}/{8} {9}/{10}/{11}", v1, t1, n1, v2, t2, n2, v3, t3, n3, v4, t4, n4));
                        }
                    }

                    // Texture Name (32 bytes)
                    byte[] texBytes = br.ReadBytes(32);
                    string texRaw = Encoding.ASCII.GetString(texBytes);
                    int zIdx = texRaw.IndexOf('\0');
                    if (zIdx >= 0) texRaw = texRaw.Substring(0, zIdx);
                    texRaw = texRaw.Trim();

                    // Strip illegal path chars
                    foreach (char c in Path.GetInvalidFileNameChars()) {
                        texRaw = texRaw.Replace(c, '_');
                    }
                    string texStem = "";
                    try {
                        texStem = Path.GetFileNameWithoutExtension(texRaw);
                    } catch {
                        texStem = "tex_" + m;
                    }
                    if (string.IsNullOrEmpty(texStem)) texStem = "tex_" + m;
                    string texPng = texStem + ".png";

                    sbMtl.AppendLine(string.Format("newmtl Material_{0}", m));
                    sbMtl.AppendLine("Ka 1.000 1.000 1.000");
                    sbMtl.AppendLine("Kd 1.000 1.000 1.000");
                    sbMtl.AppendLine("d 1.0");
                    sbMtl.AppendLine("map_Kd " + texPng);
                    sbMtl.AppendLine();

                    vOffset += numV;
                    nOffset += numN;
                    tOffset += numT;
                }

                File.WriteAllText(objPath, sbObj.ToString());
                File.WriteAllText(mtlPath, sbMtl.ToString());
                return true;
            }
        } catch (Exception ex) {
            Console.WriteLine("Error converting " + modelName + ": " + ex.Message);
            return false;
        }
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

# 1. Convert Object1 Textures
$srcTex = "E:\MuMain\Client\Data\Object1"
$dstModel = "E:\MuMain\MuGodot\assets\models\world1"
New-Item -ItemType Directory -Path $dstModel -Force | Out-Null

$texCount = 0
Get-ChildItem -Path $srcTex | Where-Object { $_.Extension -match "oz" } | ForEach-Object {
    $outPng = Join-Path $dstModel ($_.BaseName + ".png")
    try {
        [WorldConverter]::ConvertTexture($_.FullName, $outPng)
        $texCount++
    } catch {}
}
Write-Output "Converted $texCount Object1 textures to $dstModel"

# 2. Convert Object1 BMD Models to OBJ
$modelCount = 0
Get-ChildItem -Path $srcTex -Filter "*.bmd" | ForEach-Object {
    if ([WorldConverter]::ConvertBmd($_.FullName, $dstModel)) {
        $modelCount++
    }
}
Write-Output "Converted $modelCount Object1 BMD models to $dstModel"

# 3. Convert World1 Terrain Textures
$srcWorld = "E:\MuMain\Client\Data\World1"
$dstWorld = "E:\MuMain\MuGodot\assets\textures\world1"
New-Item -ItemType Directory -Path $dstWorld -Force | Out-Null
Get-ChildItem -Path $srcWorld | Where-Object { $_.Extension -match "oz" } | ForEach-Object {
    $outPng = Join-Path $dstWorld ($_.BaseName + ".png")
    try {
        [WorldConverter]::ConvertTexture($_.FullName, $outPng)
    } catch {}
}
Write-Output "Converted World1 terrain textures!"
