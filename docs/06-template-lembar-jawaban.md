# 📄 Template Lembar Jawaban (A4, custom) — ✅ IMPLEMENTASI SELESAI

## 1. Tujuan

Satu PDF A4 per siswa berisi: identitas + grid kotak jawaban bernomor. Guru mencetak, siswa menulis langsung di kotak. Geometri **fixed** → mobile hanya perlu 1 kali perspective transform per halaman, lalu crop sel dengan math matriks (tanpa deteksi ulang per kotak).

**Kontrak mobile:** generator mengekspor `layout.json` (koordinat PIXEL di ruang warp 2480×3508) — satu-satunya sumber kebenaran geometri untuk crop. Implementasi: `app/services/template_service.py` (render) + `app/services/marker_detection.py` (deteksi, logika identik untuk mobile Fase 4).

## 2. Spesifikasi Halaman (Fase 3-R — REDESAIN)

- Ukuran: A4 portrait (210 × 297 mm), render 300 DPI → 2480 × 3508 px.
- Warna: hitam-putih murni.
- **Multi-page:** layout melebihi 1 halaman → halaman baru otomatis; tiap halaman punya 4 marker sendiri.
- **Halaman 1** = kop + identitas + grid; **halaman 2+** = grid saja (tanpa kop/identitas).

### Kop (halaman 1, di bawah marker TL — PENTING: tidak boleh menabrak marker)
- Logo kotak 20×20mm di (15,29)mm + teks "LOGO"; nama sekolah + alamat di kanannya.
- Garis kop horizontal; baris "UJIAN: <title>" + "Kelas: <nama>".
- **Koreksi bug:** posisi awal kop awalnya (y=13mm) menabrak marker TL (y=12–24mm) sehingga deteksi marker gagal (3/4). Seluruh blok kop digeser ke y ≥ 29mm.

### Identitas ramping (halaman 1, tinggi field 9mm)
- Baris 1: NAMA (120mm). Baris 2 (sejajar): KELAS (30mm), NO. ABSEN (30mm), TANGGAL (26mm).
- Grid dimulai di y=97mm (halaman 1) / y=32mm (halaman 2+).

### Grid Jawaban
- **MCQ (baru):** 4 kotak opsi a/b/c/d (14×16mm, gap 6mm) dalam satu baris; siswa **menyilang (X)** salah satu kotak. Crop per soal = area baris (76×16mm).
- Isian: 100×18mm. **Esai: 170×50mm** — koreksi bug: sebelumnya 180mm menabrak tepi kanan halaman (terpotong saat cetak).
- Jarak antar baris 8mm; nomor soal rata kanan di label x=15mm.
- **Footer** "Halaman X dari Y" di kiri bawah (y=290mm) — koreksi bug: sebelumnya di kanan-atas menabrak marker TR (x 186–198mm).

## 3. Fiducial Marker (4 sudut) — TIDAK BERUBAH

- Bentuk: persegi solid hitam **12 × 12 mm** dengan jarak aman 2 mm ke konten lain.
- Posisi kiri-atas (mm): TL(12,12), TR(198,12), BL(12,285), BR(198,285) → **pusat marker = (18,18)mm = (213,213)px** (bukan 20mm).
- Deteksi (OpenCV, `detect_markers`):
  1. Grayscale → GaussianBlur 5×5 → Otsu invert.
  2. `findContours` RETR_EXTERNAL → filter: ukuran 40–426px, aspect ≤ 1.3, **fill-ratio ≥ 0.7** (marker solid vs kotak jawaban hampa — penting: kotak MCQ aspect 1.27 lolos filter bentuk).
  3. Pusat marker = **interseksi diagonal segiempat kontur** (projective-invariant; centroid momen TIDAK valid di bawah perspektif), fallback centroid bila contour ≠ 4 titik.
  4. Urut TL,TR,BL,BR → `getPerspectiveTransform` → warp ke 2480×3508 dengan target = `markers_px` dari layout.json.

## 4. Header Identitas — digantikan desain kop + identitas ramping (lihat bagian 2)

## 5. Grid Jawaban

- 1 kolom; MCQ = baris 4 kotak opsi a/b/c/d (76×16mm), isian 100×18mm, esai 170×50mm; jarak antar baris 8mm.
- Halaman 1 grid mulai y=97mm; halaman 2+ y=32mm. Kapasitas halaman 1: 3–5 soal campuran (dengan 2 esai → esai di halaman 2).

## 6. Output Generator

```
usage: python scripts/generate_template.py --title "UTS MTK" --class-name "Kelas 8A" \
       --questions "mcq:5 short:3 essay:2" --out lembar_jawaban.pdf [--verify]
```

- `--verify`: render PDF → PNG 300dpi → deteksi 4 marker per halaman (error posisi < 2px) → warp → crop tiap sel (harus terang) → PASS/FAIL.
- Output kedua: `<out>.layout.json`:
```json
{
  "page_size_px": [2480, 3508],
  "pages": [
    {
      "markers_px": {"tl": [213,213], "tr": [2267,213], "bl": [213,3295], "br": [2267,3295]},
      "cells": [ {"question_number": 1, "type": "mcq", "x": 354, "y": 1098, "w": 177, "h": 236}, ... ]
    }
  ]
}
```

## 7. Validasi Otomatis (pytest)

- `test_build_pdf_and_layout_contract`: kontrak layout.json (ukuran, marker, urutan sel, multi-page).
- `test_detect_and_warp_on_render`: deteksi + warp pada render PDF, error marker < 2px.
- `test_perspective_roundtrip_simulated_photo`: simulasi foto miring (homografi acak + canvas margin) → deteksi → warp balik → selisih < 8px mean vs asli.
- `test_detect_fails_on_random_image`: gambar tanpa marker → error terdeteksi.
