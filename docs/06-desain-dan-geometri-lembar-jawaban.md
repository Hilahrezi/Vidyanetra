# 📄 06 — Desain & Geometri Lembar Jawaban (A4 PDF)

Dokumen ini mendokumentasikan spesifikasi tata letak (*layout*), sistem koordinat, *fiducial markers*, dan pemotongan citra lembar jawaban ujian **AutoGrading**.

---

## 📐 1. Standar Geometri Lembar Jawaban

Lembar jawaban dicetak menggunakan generator ReportLab pada backend (`app/services/template_service.py`) dengan spesifikasi:

* **Format Kertas:** A4 Portrait ($210 \times 297\text{ mm}$).
* **Resolusi Rendering Standar:** $300\text{ DPI} \rightarrow 2480 \times 3508\text{ px}$.
* **Warna:** Monokrom / Hitam-Putih murni.
* **Dukungan Multi-Halaman:** Jika jumlah soal melebihi kapasitas 1 halaman, sistem secara otomatis membuat halaman ke-2 dan seterusnya. Setiap halaman memiliki 4 *fiducial marker* tersendiri.

---

## 🎯 2. Empat Fiducial Markers (Pusat Referensi Homografi)

Di setiap 4 sudut halaman dicetak kotak hitam solid berukuran $12 \times 12\text{ mm}$ dengan jarak batas $2\text{ mm}$ dari konten:

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

### Algoritma Deteksi Marker Proyektif (`marker_detection.py`):
1. **Binarisasi:** Grayscale $\rightarrow$ GaussianBlur $5 \times 5 \rightarrow$ Otsu Invert.
2. **Kontur & Filter Fill-Ratio:** Mencari kontur dengan rentang ukuran $40\text{--}426\text{ px}$, rasio aspek $\le 1.3$, dan **rasio keterisian (*fill-ratio*) $\ge 0.7$** (membedakan kotak marker solid dari kotak jawaban berongga).
3. **Pusat Proyektif (*Projective-Invariant Center*):** Pusat marker dihitung dari **perpotongan diagonal 4 titik ekstrem kontur**, bukan titik berat momen (*centroid*) yang rentan bias ketika difoto miring.
4. **Transformasi Homografi:** Menyusun matriks transformasi DLT (*Direct Linear Transformation*) $8 \times 8$ untuk memetakan koordinat kamera ke ruang piksel datar $2480 \times 3508\text{ px}$.

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
│                                                                         │  (170 x 50 mm)
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

* **Tata Letak Halaman 1:**
  - Kop Sekolah & Ujian: $y = 29\text{--}65\text{ mm}$ (aman di bawah marker TL).
  - Identitas Siswa: $y = 66\text{--}92\text{ mm}$ (Nama, Kelas, No. Absen, Tanggal).
  - Grid Jawaban: dimulai dari $y = 97\text{ mm}$.
* **Tata Letak Halaman 2+:**
  - Grid Jawaban dimulai langsung dari $y = 32\text{ mm}$ (memaksimalkan kapasitas halaman).

---

## 📋 4. Kontrak JSON Koordinat (`layout.json`)

Setiap kali PDF di-generate, sistem memproduksi kontrak koordinat geometris:

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
          "h": 591
        }
      ]
    }
  ]
}
```
*Aplikasi mobile menggunakan koordinat ini untuk memotong kotak jawaban secara instan melalui sampling bilinear.*
