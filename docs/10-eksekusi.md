# ✅ Laporan Eksekusi — AutoGrading System (Fase 0–6)

Dokumen status akhir eksekusi. Referensi rencana awal: `01-rencana-master.md`.

## Ringkasan Status

| Fase | Status | Catatan |
|---|---|---|
| 0 — Inisialisasi | ✅ | struktur repo, docs, boilerplate backend |
| 1 — Backend API | ✅ | 41 test hijau; submission/analitik/export/override/finalize |
| 2 — Integrasi Gemini | ✅ | benchmark 7 model; routing final per tugas; fallback; audit `model_used`; retry-failed |
| 2A — Benchmark model | ✅ | pemenang: `gemini-3.5-flash-lite` (MCQ/isian) + `gemini-3.5-flash` (esai) |
| 3 — Template PDF | ✅ | + redesain 3-R (kop, MCQ a–d, esai 170mm, footer); `--verify` PASS |
| 4 — Mobile Flutter | ✅ | pipeline pure Dart; APK build; **E2E perangkat itel S666LN sukses** (89.58) |
| 4.5 — MCQ tanpa AI | ✅ | 3-tier: mobile CV → backend CV → Gemini fallback |
| 5 — Web Dashboard | ✅ | Next.js 16; proxy.ts guard; BFF proxy; chart + export; E2E data nyata |
| 6 — Integrasi & docs | ✅ | alur penuh 2 siswa; dokumen ini; commit |

## Keputusan Teknis Kunci (histori)

1. **Stack**: Flutter (Android) + FastAPI + SQLite(dev)/PostgreSQL(prod) + Next.js.
2. **Model Gemini** (akun 18 Agu 2026): `gemini-3.5-flash-lite` MCQ/isian (200 RPD), `gemini-3.5-flash` esai (20 RPD), fallback otomatis lite saat 429. `3.7-flash` 503, `3.5-preview`/2.5-family 404.
3. **Batching**: interleaved prompt-level, batch 10 (maks 15), paralel antar tipe (tidak menambah request).
4. **MCQ 3-tier**: deteksi X (CV) di mobile → backend → Gemini. Ambigu = densitas < 0.03 atau < 1.5× kotak kedua.
5. **Pure Dart pipeline** (flutter_opencv dibatalkan): Otsu → CCL → fill-ratio → interseksi diagonal → DLT homografi → sampling bilinear per sel.
6. **Prompt**: rumus matematika setara nama konsep (`a²+b²=c²` ≡ "teorema Pythagoras") — terverifikasi di E2E nyata (skor 100).
7. **Keamanan**: JWT httpOnly cookie di web + BFF proxy; API key hanya di `.env` backend; mobile tanpa secret (token di secure storage).

## Angka Terverifikasi

- **Test backend: 41 hijau** · **Test Flutter: 10 hijau**
- E2E HP nyata: submission finalized total **89.58** (MCQ fallback chain, override guru, esai flash 95)
- Validasi foto tulisan tangan: lite ≡ flash (f1 87.8)
- Dashboard: distribusi 5 submission, kesulitan soal 5 avg 80, CSV export OK

## Catatan Operasional

- **adb reverse** mati tiap kabel putus → keep-alive script: `C:\Users\hilah\AppData\Local\Temp\opencode\adb_keepalive.ps1`
- Pindah WiFi → IP berubah → rebuild APK `--dart-define=API_BASE=...`
- DB dev SQLite; migrasi ke PostgreSQL via SQLAlchemy (ganti `DATABASE_URL`)
- Kuota Gemini: flash 20 RPD → fallback lite otomatis (tercatat `model_used`)
