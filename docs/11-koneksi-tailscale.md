# 🌐 Panduan Koneksi Nirkabel HP-ke-PC via Tailscale

Dokumen ini adalah panduan operasional untuk menghubungkan aplikasi Android (**AutoGrading Scanner**) ke server lokal di PC melalui jaringan privat virtual **Tailscale** tanpa memerlukan kabel USB / `adb reverse`.

---

## 1. Topologi Jaringan

```
[HP Android Fisik] ──(WireGuard / Tailscale 100.x.y.z)──▶ [PC Windows :8000] ──▶ [Gemini AI]
```

- **IP Tailscale PC:** `100.78.211.26`
- **Port Backend:** `8000`
- **Base URL:** `http://100.78.211.26:8000`

---

## 2. Persiapan di PC Windows

### A. Pastikan Port 8000 Diizinkan di Firewall
Jalankan PowerShell as Administrator (sekali saja jika belum pernah):
```powershell
New-NetFirewallRule -DisplayName "AutoGrading FastAPI (8000)" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### B. Jalankan Backend Server
Pastikan server mendengarkan pada interface `0.0.0.0` (semua adapter termasuk Tailscale):
```powershell
cd backend
.venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 3. Persiapan di HP Android

1. Buka aplikasi **Tailscale** di HP dan pastikan statusnya **Connected** (hijau) pada akun yang sama dengan PC.
2. **Uji Koneksi Awal via Browser HP:**
   - Buka Google Chrome di HP.
   - Ketik URL: `http://100.78.211.26:8000/health`
   - Pastikan muncul respons JSON: `{"status":"ok", "time":"..."}`.
   - *Jika gagal/timeout:* Periksa apakah Windows Firewall memblokir port 8000 atau status Tailscale di HP/PC terputus.

---

## 4. Instalasi & Penggunaan Aplikasi Mobile

### A. Lokasi File APK
File APK debug yang telah di-build berada di:
`mobile/build/app/outputs/flutter-apk/app-debug.apk`

Kirimkan file `app-debug.apk` ini ke HP Anda (misal via WhatsApp, Telegram, Google Drive, atau transfer file).

### B. Pasang & Buka Aplikasi
1. Buka file `.apk` di HP dan izinkan penginstalan dari sumber tidak dikenal (*Install unknown apps*).
2. Buka aplikasi **AutoGrading**.
3. Di layar login, Anda akan melihat alamat server aktif: `Server: http://100.78.211.26:8000`.
4. Jika ingin mengubah alamat server, tekan tombol **Ubah Alamat Server** atau ikon gerigi di pojok kanan atas.
5. Masuk dengan akun guru:
   - **Email:** `guru@sekolah.id`
   - **Password:** `rahasia123`
6. Pilih kelas $\rightarrow$ ujian $\rightarrow$ mulai pemindaian (*Scan*) lembar jawaban secara nirkabel!

---

## 5. Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| "Tidak dapat terhubung ke server" | Tailscale di HP/PC mati atau IP salah | Cek status Tailscale di kedua perangkat; pastikan IP PC adalah `100.78.211.26`. |
| Browser HP timeout saat buka `:8000/health` | Windows Firewall memblokir koneksi | Jalankan perintah `New-NetFirewallRule` di atas atau izinkan Python di Windows Defender. |
| Backend error 429 saat evaluasi | Kuota Gemini habis / throttling | Sistem otomatis fallback ke `gemini-3.5-flash-lite` atau gunakan `GEMINI_MOCK_MODE=true` di backend `.env`. |
