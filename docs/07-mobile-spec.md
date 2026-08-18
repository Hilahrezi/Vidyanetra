# 📱 Mobile App Spec — Flutter (Android) — ✅ IMPLEMENTASI (fase 4 selesai)

## 1. Lingkup MVP

- Platform: Android (API 24+), portrait, Bahasa Indonesia (UI).
- Peran: **Edge Scanner + API client**. Tanpa AI lokal, tanpa DB langsung, tanpa secret.

## 2. Scaffold

```
mobile/
├── lib/
│   ├── main.dart                    # routes + auth guard
│   ├── core/
│   │   ├── api_client.dart          # dio + JWT (flutter_secure_storage) + error mapping
│   │   ├── config.dart              # API_BASE via --dart-define
│   │   ├── template_constants.dart  # geometri template (mirror backend)
│   │   └── opencv_pipeline.dart     # pipeline pemindaian PURE DART
│   └── features/
│       ├── auth/login_page.dart
│       ├── classes/classes_page.dart
│       ├── exams/exams_page.dart
│       ├── scanning/scan_page.dart  # kamera + multi-halaman + upload
│       └── review/review_page.dart  # hasil AI + override + finalize
├── test/
│   ├── opencv_pipeline_test.dart    # 4 test pipeline (fixture PNG dari backend)
│   └── widget_test.dart             # layout/paginasi
└── android/ ...                     # CAMERA+INTERNET, cleartext (dev), compileSdk 37
```

## 3. Screens & Flow

1. **Login** → POST `/auth/login` → JWT di `flutter_secure_storage`.
2. **Home** → list kelas → pilih kelas → list ujian.
3. **Scan**: pilih siswa → `CameraPreview` → tombol "Ambil Foto":
   - Proses foto di isolate (`img.decodeImage` → `detectMarkers` → `cropCells`).
   - Multi-halaman: foto 1 = halaman 1, dst (indikator "Halaman x/y").
   - Gagal deteksi marker → pesan + ambil ulang.
   - Semua crop → `POST /submissions/upload-crops` → pindah ke Review.
4. **Review**: polling `GET /submissions/{id}/details` tiap 3s → per soal: crop image + extracted_text + skor + alasan AI + **slider override** → `PUT /review` + `POST /finalize`.

## 4. Pipeline Pemindaian — PURE DART (keputusan teknis)

**`flutter_opencv` dibatalkan** (tidak null-safe, mati, tidak kompatibel Dart 3). Pipeline ditulis murni Dart (`package:image`) — port 1:1 dari `marker_detection.py` backend:

1. Grayscale (0.299R+0.587G+0.114B) → **Otsu** threshold.
2. **Connected-component labeling** (scanline flood) pada resolusi kerja ≤1200px.
3. Filter komponen: ukuran 40–426px (skala), aspect ≤ 1.3, **fill-ratio ≥ 0.7** (marker solid vs kotak hampa).
4. Pusat marker = **interseksi diagonal titik ekstrem** (projective-invariant).
5. Urut TL/TR/BL/BR → **homografi DLT** (Gauss-Jordan 8×8) → **sampling bilinear per sel** (tanpa warp halaman penuh — jauh lebih cepat).
6. JPEG q70, resize ≤768px → base64 → upload.

**Verifikasi:** 4 test dengan fixture PNG yang di-generate backend (render flat + simulasi foto miring): deteksi marker, crop valid, roundtrip perspektif (diff < 10), tanpa-marker → exception. **Semua lulus.**

## 5. Payload Optimization (mandatory)

- Crop per soal: JPEG q70, ≤768px → ~50–150 KB/base64.
- Satu request per submission (multi-halaman di-append sebelum upload).
- Timeout 120s + retry manual bila gagal.

## 6. Keamanan

- JWT di `flutter_secure_storage` (keystore).
- Tidak ada base URL hardcoded untuk prod di repo; dari `--dart-define=API_BASE=...`.
- Tanpa log isi gambar ke console.
