'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';

import type { SubmissionWithDetails } from '@/lib/types';

const TYPE_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  mcq: { label: 'Pilihan Ganda', color: 'text-sky-700', bg: 'bg-sky-50 border-sky-200' },
  short: { label: 'Isian Singkat', color: 'text-teal-700', bg: 'bg-teal-50 border-teal-200' },
  essay: { label: 'Esai / Uraian', color: 'text-purple-700', bg: 'bg-purple-50 border-purple-200' },
};

function getSemanticLevel(score: number) {
  if (score >= 85) {
    return {
      label: 'Sangat Sesuai (>85%)',
      badgeBg: 'bg-emerald-50 text-emerald-800 border-emerald-300',
      meterBg: 'bg-emerald-500',
      ringColor: 'ring-emerald-400',
      icon: '✓',
    };
  }
  if (score >= 50) {
    return {
      label: 'Perlu Verifikasi Guru (50–84%)',
      badgeBg: 'bg-amber-50 text-amber-800 border-amber-300',
      meterBg: 'bg-amber-500',
      ringColor: 'ring-amber-400',
      icon: '⏳',
    };
  }
  return {
    label: 'Kurang Sesuai (<50%)',
    badgeBg: 'bg-rose-50 text-rose-800 border-rose-300',
    meterBg: 'bg-rose-500',
    ringColor: 'ring-rose-400',
    icon: '✕',
  };
}

export default function StudentDetailPage() {
  const { id, sid } = useParams<{ id: string; sid: string }>();
  const [data, setData] = useState<SubmissionWithDetails | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [overrides, setOverrides] = useState<Record<number, number>>({});
  const [saving, setSaving] = useState(false);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  useEffect(() => {
    fetch(`/api/submissions/${sid}/details`)
      .then(async (r) => {
        if (!r.ok) throw new Error('Gagal memuat detail koreksi siswa');
        return r.json();
      })
      .then(setData)
      .catch((e) => setError(String(e)));
  }, [sid]);

  async function save() {
    setSaving(true);
    setError(null);
    try {
      const items = Object.entries(overrides).map(([qid, score]) => ({
        question_id: Number(qid),
        overridden_score: score,
      }));
      if (items.length > 0) {
        const resp = await fetch(`/api/submissions/${sid}/review`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items }),
        });
        if (!resp.ok) throw new Error('Gagal menyimpan koreksi manual');
      }
      const fin = await fetch(`/api/submissions/${sid}/finalize`, { method: 'POST' });
      if (!fin.ok) throw new Error('Gagal memfinalisasi hasil evaluasi');
      const updated = await fin.json();
      setData(updated);
      setOverrides({});
      alert('Hasil evaluasi siswa berhasil difinalisasi dan disimpan!');
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving(false);
    }
  }

  const status = data?.status;
  const finalized = status === 'finalized';

  return (
    <main className="min-h-screen bg-[#F8FAFC] text-[#0F172A] pb-16">
      {/* Top Header Bar */}
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/95 backdrop-blur-md shadow-sm">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <Link
              href={`/dashboard/exams/${id}`}
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-slate-50/80 px-3 py-1.5 text-xs font-bold text-slate-700 hover:border-[#0F766E] hover:text-[#0F766E] hover:bg-[#E6F4F1] transition shadow-sm"
            >
              <span>←</span>
              <span>Rekap Ujian</span>
            </Link>

            <div className="h-5 w-[1px] bg-slate-200" />

            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base font-extrabold tracking-tight text-[#0F172A]">
                  {data?.student_name ?? 'Memuat Data Siswa...'}
                </h1>
                {data?.student_number && (
                  <span className="rounded-lg bg-slate-100 px-2 py-0.5 text-[11px] font-mono font-bold text-slate-600 border border-slate-200">
                    No. {data.student_number}
                  </span>
                )}
                <span
                  className={`rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider ${
                    finalized
                      ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                      : 'bg-amber-100 text-amber-800 border border-amber-200'
                  }`}
                >
                  {finalized ? '✓ Final Terkunci' : '⏳ Menunggu Finalisasi'}
                </span>
              </div>
              <p className="text-[11px] text-slate-500 font-medium">
                Panel Evaluasi Semantik Tiga Kolom (Split View)
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {data?.total_score != null && (
              <div className="flex items-center gap-2 rounded-2xl bg-[#E6F4F1] border border-[#CCFBF1] px-3.5 py-1.5 shadow-sm">
                <span className="text-xs font-semibold text-[#0F766E]">Total Skor:</span>
                <span className="text-lg font-extrabold text-[#0F766E]">
                  {data.total_score}
                </span>
              </div>
            )}

            {!finalized && (
              <button
                onClick={save}
                disabled={saving}
                className="inline-flex items-center gap-2 rounded-xl bg-[#0F766E] hover:bg-[#115E59] px-4 py-2 text-xs font-bold text-white shadow-md shadow-teal-900/20 active:scale-[0.99] disabled:opacity-50 transition"
              >
                {saving ? (
                  <>
                    <div className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                    <span>Menyimpan...</span>
                  </>
                ) : (
                  <>
                    <span>✓</span>
                    <span>Simpan & Finalisasi</span>
                  </>
                )}
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="mx-auto max-w-7xl space-y-6 px-6 py-6">
        {error && (
          <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-xs font-medium text-rose-700 flex items-center gap-2">
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}

        {finalized && (
          <div className="rounded-2xl border border-[#CCFBF1] bg-[#E6F4F1] p-3.5 text-xs text-[#0F766E] font-medium flex items-center gap-2 shadow-sm">
            <span className="text-base">🔒</span>
            <span>
              Hasil evaluasi lembar jawaban siswa ini telah difinalisasi. Skor terkunci di database rapor.
            </span>
          </div>
        )}

        {!data && !error && (
          <div className="rounded-3xl border border-slate-200 bg-white p-12 text-center text-slate-400">
            <div className="inline-block h-7 w-7 animate-spin rounded-full border-2 border-[#0F766E] border-t-transparent mb-2" />
            <p className="text-xs font-medium">Memuat detail lembar jawaban siswa...</p>
          </div>
        )}

        {/* 3-Column Split View Evaluation Feed */}
        <div className="space-y-6">
          {data?.details.map((d) => {
            const effectiveScore =
              overrides[d.question_id] ?? d.overridden_score ?? d.similarity_score ?? 0;
            const isManuallyOverridden =
              overrides[d.question_id] !== undefined || d.manual_override;
            const typeConf = TYPE_CONFIG[d.type] ?? {
              label: d.type,
              color: 'text-slate-700',
              bg: 'bg-slate-100 border-slate-200',
            };
            const semanticLevel = getSemanticLevel(effectiveScore);

            return (
              <div
                key={d.id}
                className="overflow-hidden rounded-3xl border border-slate-200/90 bg-white shadow-sm transition hover:shadow-md"
              >
                {/* Header Sub-bar */}
                <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 bg-[#F8FAFC] px-6 py-3.5">
                  <div className="flex items-center gap-3">
                    <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-[#0F766E] font-mono text-xs font-bold text-white shadow-sm">
                      #{d.question_number}
                    </span>
                    <span
                      className={`rounded-lg border px-2.5 py-0.5 text-xs font-bold ${typeConf.color} ${typeConf.bg}`}
                    >
                      {typeConf.label}
                    </span>
                    <span className="text-xs font-semibold text-slate-500">
                      Bobot Maks: <strong className="text-slate-800">{d.weight ?? 10}</strong> pt
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-xs">
                    {d.model_used && (
                      <span className="rounded-md bg-slate-200/60 px-2 py-0.5 text-[10px] font-mono font-medium text-slate-600">
                        ⚡ {d.model_used}
                      </span>
                    )}
                    <span
                      className={`rounded-full border px-2.5 py-0.5 text-[10px] font-bold ${semanticLevel.badgeBg}`}
                    >
                      {semanticLevel.icon} {semanticLevel.label}
                    </span>
                  </div>
                </div>

                {/* 3-Column Split Grid */}
                <div className="grid grid-cols-1 divide-y lg:grid-cols-12 lg:divide-y-0 lg:divide-x divide-slate-100 p-6 gap-6 lg:gap-0">
                  {/* Kolom 1: Potongan Gambar Tulisan Tangan Siswa (Width: 4/12) */}
                  <div className="lg:col-span-4 lg:pr-6 flex flex-col justify-between">
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                          1. Tulisan Tangan Asli
                        </span>
                        <span className="text-[10px] font-mono font-medium text-slate-400">
                          Crop 300 DPI
                        </span>
                      </div>

                      <div className="relative group overflow-hidden rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50 p-2 text-center transition hover:border-[#10B981]">
                        {d.image_url ? (
                          <>
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img
                              src={`/api${d.image_url}`}
                              alt={`Potongan Soal ${d.question_number}`}
                              className="mx-auto max-h-48 w-full object-contain rounded-xl bg-white shadow-inner cursor-zoom-in"
                              onClick={() => setPreviewImage(`/api${d.image_url}`)}
                            />
                            <button
                              type="button"
                              onClick={() => setPreviewImage(`/api${d.image_url}`)}
                              className="mt-2 inline-flex items-center gap-1 rounded-lg bg-white px-2.5 py-1 text-[11px] font-semibold text-slate-600 shadow-sm border border-slate-200 hover:text-[#0F766E] transition"
                            >
                              <span>🔍</span>
                              <span>Perbesar Citra</span>
                            </button>
                          </>
                        ) : (
                          <div className="py-8 text-slate-400">
                            <span className="text-2xl">📷</span>
                            <p className="mt-1 text-xs">Citra crop tidak tersedia</p>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Kolom 2: Ekstraksi OCR vs Kunci Jawaban Guru (Width: 5/12) */}
                  <div className="lg:col-span-5 lg:px-6 space-y-4">
                    <div>
                      <div className="flex items-center justify-between mb-1.5">
                        <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                          2. Ekstraksi AI & Kunci Jawaban
                        </span>
                        <span className="text-[10px] font-mono text-[#0F766E] font-semibold bg-[#E6F4F1] px-2 py-0.5 rounded">
                          Token Ekstraksi
                        </span>
                      </div>

                      {/* Extracted Text Box */}
                      <div className="rounded-2xl border border-[#CCFBF1] bg-[#E6F4F1]/60 p-3.5">
                        <p className="text-[11px] font-bold text-[#0F766E] uppercase mb-1">
                          📝 Teks Terbaca Siswa:
                        </p>
                        <p className="font-mono text-sm font-semibold text-[#0F172A] bg-white p-2.5 rounded-xl border border-[#CCFBF1]/80 shadow-sm break-words">
                          {d.student_answer_text || (
                            <span className="italic text-slate-400">
                              (Jawaban kosong / tidak terdeteksi)
                            </span>
                          )}
                        </p>
                      </div>
                    </div>

                    {/* Teacher's Key & AI Reasoning */}
                    <div className="rounded-2xl border border-slate-200 bg-slate-50/70 p-3.5 space-y-2">
                      <div>
                        <p className="text-[11px] font-bold text-slate-600 uppercase">
                          🔑 Kunci Jawaban Guru:
                        </p>
                        <p className="text-xs font-medium text-slate-800 mt-0.5">
                          {d.answer_key || '-'}
                        </p>
                      </div>

                      {d.ai_reasoning && (
                        <div className="pt-2 border-t border-slate-200/80">
                          <p className="text-[10px] font-bold text-slate-500 uppercase">
                            💡 Rasional / Alasan Penilaian AI:
                          </p>
                          <p className="text-xs text-slate-600 italic mt-0.5 leading-relaxed">
                            &ldquo;{d.ai_reasoning}&rdquo;
                          </p>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Kolom 3: Skor Semantik & Manual Override (Width: 3/12) */}
                  <div className="lg:col-span-3 lg:pl-6 flex flex-col justify-between">
                    <div>
                      <span className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2">
                        3. Skor & Verifikasi
                      </span>

                      {/* Score Dial Meter */}
                      <div className="rounded-2xl border border-slate-200 bg-slate-50/50 p-4 text-center">
                        <div className="flex items-center justify-center">
                          <div
                            className={`flex h-16 w-16 items-center justify-center rounded-2xl font-extrabold text-2xl shadow-inner border-2 ${
                              effectiveScore >= 85
                                ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                                : effectiveScore >= 50
                                  ? 'bg-amber-50 text-amber-800 border-amber-300'
                                  : 'bg-rose-50 text-rose-800 border-rose-300'
                            }`}
                          >
                            {effectiveScore}
                          </div>
                        </div>
                        <p className="mt-2 text-xs font-extrabold text-slate-800">
                          Kemiripan Semantik: {effectiveScore}%
                        </p>
                        <p className="text-[10px] text-slate-500">
                          Nilai Butir: {((effectiveScore / 100) * (d.weight ?? 10)).toFixed(1)} / {d.weight ?? 10} pt
                        </p>
                        {isManuallyOverridden && (
                          <span className="mt-2 inline-block rounded-md bg-amber-100 px-2 py-0.5 text-[9px] font-bold text-amber-900 border border-amber-200">
                            ✏️ Telah Diubah Guru
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Interactive Override Controls */}
                    {!finalized && (
                      <div className="mt-4 pt-3 border-t border-slate-100">
                        <div className="flex items-center justify-between text-xs font-bold mb-1.5">
                          <span className="text-slate-600">Koreksi Manual:</span>
                          <span className="text-[#0F766E] font-mono">{effectiveScore}%</span>
                        </div>
                        <input
                          type="range"
                          min={0}
                          max={100}
                          step={5}
                          value={effectiveScore}
                          onChange={(e) =>
                            setOverrides((prev) => ({
                              ...prev,
                              [d.question_id]: Number(e.target.value),
                            }))
                          }
                          className="w-full accent-[#0F766E] cursor-pointer"
                        />
                        <div className="flex justify-between gap-1 mt-2">
                          {[0, 50, 80, 100].map((preset) => (
                            <button
                              key={preset}
                              type="button"
                              onClick={() =>
                                setOverrides((prev) => ({
                                  ...prev,
                                  [d.question_id]: preset,
                                }))
                              }
                              className="rounded-lg border border-slate-200 bg-white px-2 py-1 text-[10px] font-bold text-slate-600 hover:border-[#0F766E] hover:text-[#0F766E] hover:bg-[#E6F4F1] transition"
                            >
                              {preset}%
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Image Modal Lightbox */}
      {previewImage && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm"
          onClick={() => setPreviewImage(null)}
        >
          <div
            className="relative max-h-[90vh] max-w-4xl overflow-hidden rounded-2xl bg-white p-2 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={previewImage}
              alt="Pratinjau Citra Resolusi Tinggi"
              className="max-h-[85vh] w-auto rounded-xl object-contain"
            />
            <button
              type="button"
              onClick={() => setPreviewImage(null)}
              className="absolute top-4 right-4 rounded-full bg-slate-900/80 px-3 py-1.5 text-xs font-bold text-white hover:bg-slate-900 transition"
            >
              ✕ Tutup
            </button>
          </div>
        </div>
      )}
    </main>
  );
}
