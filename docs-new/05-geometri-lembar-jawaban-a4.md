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

## 📦 3. Sistem Grid Kotak Jawaban (Format Kompak 8 mm)

```
MCQ Option Box (A/B/C/D):
┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐
│   A   │   │   B   │   │   C   │   │   D   │  (8 x 8 mm, gap 4 mm)
└───────┘   └───────┘   └───────┘   └───────┘
◄────────────────────── 44 mm ──────────────────────►

Isian Singkat Box:
┌──────────────────────────────────────────────────────────────┐
│                                                              │  (120 x 8 mm / 1 baris)
└──────────────────────────────────────────────────────────────┘

Esai / Uraian Box:
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                                                                         │  (170 x 40 mm / 5 baris)
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

* **Penyelarasan Nomor Urut:** Rata kanan di $x = 23.0\text{ mm}$ (sejajar 2 mm sebelum kotak jawaban pada $x = 25.0\text{ mm}$).
* **Jarak Antar Soal (`ROW_GAP`):** $4.0\text{ mm}$.
* **Tata Letak Halaman 1:**
  - Kop Sekolah & Ujian: $y = 29\text{--}65\text{ mm}$.
  - Identitas Siswa: $y = 70\text{--}92\text{ mm}$ (Nama, Kelas, No. Absen, Tanggal).
  - Grid Jawaban: dimulai dari $y = 97\text{ mm}$ (muat hingga 14 soal MCQ).
* **Tata Letak Halaman 2+:**
  - Grid Jawaban dimulai langsung dari $y = 32\text{ mm}$ (muat hingga 20 soal MCQ).

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
          "x": 295,
          "y": 1146,
          "w": 520,
          "h": 94
        },
        {
          "question_number": 2,
          "type": "short",
          "x": 295,
          "y": 1287,
          "w": 1417,
          "h": 94
        },
        {
          "question_number": 3,
          "type": "essay",
          "x": 295,
          "y": 1429,
          "w": 2008,
          "h": 472
        }
      ]
    }
  ]
}
```
*Aplikasi mobile menggunakan koordinat ini untuk memotong kotak jawaban secara instan melalui sampling bilinear.*
