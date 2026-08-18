# 🧭 Flow Penggunaan Sistem (End-to-End)

Aktor: **Guru** (satu-satunya pengguna).

## A. Persiapan Awal (sekali / per ujian)

1. Login (web atau mobile) → buat kelas → tambah siswa (nama + nomor absen).
2. Buat ujian → tambah soal: nomor, tipe (MCQ/isian/esai), bobot, dan **answer_key**
   (MCQ: huruf A–D; isian/esai: teks jawaban ideal, alternatif dipisah `|`).
   Kunci hanya di database — tidak pernah muncul di lembar siswa.
3. Generate **PDF template A4** via `backend/scripts/generate_template.py` → cetak → bagikan.

## B. Pelaksanaan

1. Siswa menulis jawaban langsung di kotak bernomor (MCQ = menulis huruf A–D, bukan bubble).
2. Satu lembar A4 per siswa; dikumpulkan.

## C. Pemindaian & Koreksi (Mobile)

1. Buka ujian → **Scan Lembar** → pilih siswa → ambil foto.
2. App mendeteksi 4 fiducial marker → homografi → perspective warp → crop otomatis per kotak → compress JPEG q70.
3. Kirim `POST /submissions/upload-crops` (per-jawaban, base64) → backend mengevaluasi via Gemini (batch 4–8, Flash untuk esai / Flash-Lite untuk MCQ-isian).
4. App menampilkan hasil per soal: crop asli + teks terbaca AI + skor + alasan. Guru **memeriksa dan boleh override** per soal.
5. Tekan **Simpan + Finalize** → submission tersimpan, status `finalized`.

## D. Analitik & Laporan (Web)

1. Pilih ujian → tabel hasil per siswa (skor per soal + total).
2. Grafik distribusi nilai + kesulitan soal.
3. **Export CSV** → laporan nilai kelas.

## E. Catatan Operasional

- Jaringan hanya dibutuhkan saat scan (crop upload + polling hasil).
- Override soal = AI tidak dipanggil ulang (hemat quota).
- Quota Gemini habis → sistem tetap bisa menyimpan submission, evaluasi `failed`; retry otomatis/manual saat quota pulih.
