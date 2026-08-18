# Web Dashboard — Next.js (AutoGrading)

Dashboard analitik untuk guru: tabel hasil ujian, chart distribusi nilai & kesulitan soal (Chart.js), manual override, export CSV.

Spesifikasi lengkap: [`docs/08-web-spec.md`](../docs/08-web-spec.md)

## Setup

```bash
npm install        # sudah dijalankan (pre-install sebelum pindah koneksi)
npm run dev        # development server
npm run build      # production build (terverifikasi OK)
```

## Tech

- Next.js (App Router, TypeScript, Tailwind, Turbopack)
- `chart.js` + `react-chartjs-2`

> Catatan: `node_modules/next/dist/docs/` berisi panduan versi Next.js ini — baca sebelum menulis kode (lihat `AGENTS.md`).
