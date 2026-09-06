# 📄 05 — Desain & Geometri Lembar Jawaban (A4 PDF)

Dokumen ini mendokumentasikan spesifikasi tata letak (*layout*), sistem koordinat, *fiducial markers*, dan algoritma pemotongan citra lembar jawaban ujian **Vidyanetra**.

---

## 📐 1. Standar Geometri Lembar Jawaban

Lembar jawaban di-generate oleh engine ReportLab backend (`app/services/template_service.py`):
* **Format Kertas:** A4 Portrait ($210 \times 297\text{ mm}$).
* **Resolusi Rendering Standar:** $300\text{ DPI} \rightarrow 2480 \times 3508\text{ px}$.
* **Warna:** Monokrom / Hitam-Putih murni (kontras tinggi).
* **Dukungan Multi-Halaman:** Halaman ke-2 dan seterusnya dibuat otomatis jika jumlah soal melebihi batas batas bawah ($y \le 268\text{ mm}$). Setiap halaman memiliki 4 *fiducial marker* tersendiri.

---

## 🎯 2. Empat Fiducial Markers (Referensi Transformasi Homografi)

Di setiap 4 sudut halaman dicetak kotak hitam solid berukuran $12 \times 12\text{ mm}$:

```
(0,0) mm ────────────────────────────────────────────── (210,0) mm
  │  ■ TL: (12,12)mm                       ■ TR: (198,12)mm   │
  │  Pusat: (18,18)mm / (213,213)px         Pusat: (2267,213)px│
  │                                                           │
  │                 [KOP SEKOLAH & IDENTITAS]                 │
  │                                                           │
  │                 [GRID KOTAK JAWABAN SISWA]                │
  │                                                           │
  │  ■ BL: (12,285)mm                      ■ BR: (198,285)mm  │
  │  Pusat: (213,3295)px                    Pusat: (2267,3295)px
(0,297) mm ────────────────────────────────────────── (210,297) mm
```

### Algoritma Deteksi Marker Proyektif:
1. **Binarisasi & Filter Fill-Ratio ($\ge 0.7$):** Membedakan kotak hitam pejal marker dari kotak jawaban berongga.
2. **Pusat Proyektif (*Projective-Invariant Center*):** Pusat marker dihitung dari **perpotongan diagonal 4 titik ekstrem kontur**, bukan titik berat momen (*centroid*) yang rentan bias ketika difoto miring.
3. **Transformasi Homografi DLT ($8 \times 8$ Gauss-Jordan):** Memetakan koordinat kamera ke ruang piksel datar $2480 \times 3508\text{ px}$.

---

## 📦 3. Sistem Grid Kotak Jawaban

```
MCQ Option Box (a/b/c/d):
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│    a    │   │    b    │   │    c    │   │    d    │  (14 x 16 mm, gap 6 mm)
└─────────┘   └─────────┘   └─────────┘   └─────────┘
◄────────────────────── 76 mm ──────────────────────►

Isian Singkat Box:
┌───────────────────────────────────────────────────┐
│                                                   │  (100 x 18 mm)
└───────────────────────────────────────────────────┘

Esai / Uraian Box:
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                                                                         │  (170 x 45 mm)
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

* **Tata Letak Halaman 1:**
  - Kop Sekolah & Ujian: $y = 29\text{--}65\text{ mm}$.
  - Identitas Siswa: $y = 70\text{--}92\text{ mm}$ (Nama, Kelas, No. Absen, Tanggal).
  - Grid Jawaban: dimulai dari $y = 97\text{ mm}$.
* **Tata Letak Halaman 2+:**
  - Grid Jawaban dimulai langsung dari $y = 32\text{ mm}$ (memaksimalkan kapasitas halaman).

---

## 📋 4. Kontrak JSON Koordinat (`layout.json`)

```json
{
  "page_size_px": [2480, 3508],
  "pages": [
    {
      "markers_px": {
        "tl": [213, 213],
        "tr": [2267, 213],
        "bl": [213, 3295],
        "br": [2267, 3295]
      },
      "cells": [
        {
          "question_number": 1,
          "type": "mcq",
          "x": 354,
          "y": 1098,
          "w": 898,
          "h": 189
        },
        {
          "question_number": 2,
          "type": "short",
          "x": 354,
          "y": 1335,
          "w": 1181,
          "h": 213
        },
        {
          "question_number": 3,
          "type": "essay",
          "x": 354,
          "y": 1596,
          "w": 2008,
          "h": 531
        }
      ]
    }
  ]
}
```
*Aplikasi mobile menggunakan koordinat ini untuk memotong kotak jawaban secara instan melalui sampling bilinear.*
