# 📱 06 — Spesifikasi Aplikasi Mobile Scanner (Flutter Android)

Dokumen ini mendokumentasikan arsitektur aplikasi mobile Android **Vidyanetra Scanner**, pipeline pemrosesan citra *Edge Pure Dart*, dan alur kerja pengguna (*UI Workflow*).

---

## 🏗️ 1. Arsitektur & Struktur Direktori

Aplikasi dibangun menggunakan **Flutter 3 (Android API 24+, compileSdk 37)**:

```
mobile/
├── lib/
│   ├── main.dart                    # Entry point, routing, auth guard
│   ├── core/
│   │   ├── api_client.dart          # HTTP client (Dio), JWT auth, interceptor
│   │   ├── config.dart              # Konfigurasi runtime (API_BASE)
│   │   ├── template_constants.dart  # Geometri LJK & koordinat marker A4
│   │   └── opencv_pipeline.dart     # Pipeline Edge CV murni Dart (Pure Dart)
│   └── features/
│       ├── auth/login_page.dart     # Form login guru & konfigurasi server
│       ├── classes/classes_page.dart # Daftar kelas yang diampu guru
│       ├── exams/exams_page.dart    # Daftar ujian aktif & progres koreksi
│       ├── exams/exam_editor_page.dart # Exam & Question builder berbobot otomatis
│       ├── scanning/scan_page.dart  # Kamera scanner, multi-page, crop upload
│       └── review/review_page.dart  # In-app review, manual override, finalize
```

---

## ⚡ 2. Pipeline Pemrosesan Citra Edge (Pure Dart)

Untuk menjaga kompatibilitas jangka panjang tanpa ketergantungan library C++ native yang rentan rusak, seluruh algoritma Computer Vision ditulis dalam **Dart murni (`package:image`)**:

```mermaid
flowchart TD
    Photo["📸 Foto Kamera HP (JPEG)"] --> Gray["1. Grayscale (0.299R + 0.587G + 0.114B)"]
    Gray --> Otsu["2. Otsu Auto-Thresholding (Binarize)"]
    Otsu --> CCL["3. Connected-Component Labeling (Scanline)"]
    CCL --> Filter["4. Filter Marker (Size 40-426px, Fill-Ratio ≥ 0.7)"]
    Filter --> Order["5. Urutkan 4 Sudut: TL, TR, BL, BR"]
    Order --> Center["6. Hitung Titik Pusat via Interseksi Diagonal"]
    Center --> DLT["7. Matriks Transformasi Homografi DLT (8x8 Gauss-Jordan)"]
    DLT --> Sampling["8. Bilinear Sampling Crop per Kotak Jawaban (≤768px)"]
    Sampling --> MCQ_X["9. Deteksi Densitas Silang X pada Kotak MCQ (a/b/c/d)"]
    MCQ_X --> Compress["10. Kompresi JPEG q70 + Base64 (~50-100 KB/crop)"]
    Compress --> Upload["🚀 POST /submissions/upload-crops"]
```

### Deteksi Opsi Silang Lokal (`McqMark`):
```dart
class McqMark {
  final String answer;     // Opsi terdeteksi: "a", "b", "c", atau "d"
  final double confidence; // Densitas piksel tinta pada kotak terpilih
  final bool ambiguous;    // True jika densitas < 0.03 atau kontras < 1.5x
}
```
* **Kompensasi Perspektif:** Algoritma membaca fraksi koordinat kotak tetap (`MCQ_BOX_FRACTIONS`) langsung dari citra cell yang telah di-warp.
* **Handover Cerdas:** Nilai `answer` dan `ambiguous` dikirim dalam payload `UploadCropsRequest` sehingga backend langsung menetapkan nilai jika hasil deteksi silang HP sudah pasti.

---

## ✍️ 3. Fitur Exam & Question Builder

* **Default Bobot Standar:**
  - 🔘 **Pilihan Ganda (MCQ):** Default = **`5` pt**
  - ✏️ **Isian Singkat (Short Answer):** Default = **`10` pt**
  - 📄 **Esai / Uraian (Essay):** Default = **`20` pt**
* **Akumulasi Real-time:** Banner aplikasi menampilkan total skor secara otomatis (`Total Skor: X pt`).
* **Download PDF Instan:** Tombol langsung mengunduh lembar jawaban A4 dari backend.

---

## 📦 4. Kompilasi & Build APK Android (Release Mode)

| Mode Build | Perintah Kompilasi | Ukuran File | Kegunaan |
|---|---|:---:|---|
| **Release Split-ABI (Direkomendasikan ⭐)** | `flutter build apk --release --split-per-abi --dart-define=API_BASE=https://...` | **~18 MB** | Distribusi produksi HP Android modern (`arm64-v8a`). |
| **Release Universal** | `flutter build apk --release --dart-define=API_BASE=https://...` | **~45 MB** | 1 File APK universal untuk semua tipe arsitektur CPU. |

### Perintah Kompilasi Produksi:
```powershell
cd mobile
flutter build apk --release --split-per-abi --dart-define=API_BASE=https://autograding-api.onrender.com
```
*File output:* `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (**~18 MB**).
