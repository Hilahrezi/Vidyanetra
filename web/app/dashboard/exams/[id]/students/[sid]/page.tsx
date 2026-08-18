'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';

import type { SubmissionWithDetails } from '@/lib/types';

const TYPE_LABEL: Record<string, string> = { mcq: 'PG', short: 'Isian', essay: 'Esai' };

export default function StudentDetailPage() {
  const { id, sid } = useParams<{ id: string; sid: string }>();
  const [data, setData] = useState<SubmissionWithDetails | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [overrides, setOverrides] = useState<Record<number, number>>({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetch(`/api/submissions/${sid}/details`)
      .then(async (r) => {
        if (!r.ok) throw new Error('Gagal memuat detail');
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
        if (!resp.ok) throw new Error('Gagal menyimpan override');
      }
      const fin = await fetch(`/api/submissions/${sid}/finalize`, { method: 'POST' });
      if (!fin.ok) throw new Error('Gagal finalisasi');
      setData(await fin.json());
      setOverrides({});
      alert('Submission difinalisasi');
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving(false);
    }
  }

  const status = data?.status;
  const finalized = status === 'finalized';

  return (
    <main className="min-h-screen bg-slate-100">
      <header className="flex items-center justify-between bg-white px-6 py-4 shadow">
        <div className="flex items-center gap-3">
          <Link href={`/dashboard/exams/${id}`} className="text-slate-500 hover:text-slate-700">
            ← Kembali
          </Link>
          <h1 className="text-xl font-bold text-slate-800">
            {data?.student_name ?? 'Siswa'} {data && `— ${status}`}
            {data?.total_score != null && <span className="ml-2 text-indigo-600">({data.total_score})</span>}
          </h1>
        </div>
        {!finalized && (
          <button
            onClick={save}
            disabled={saving}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {saving ? 'Menyimpan...' : 'Simpan & Finalisasi'}
          </button>
        )}
      </header>

      <section className="mx-auto max-w-4xl space-y-4 p-6">
        {error && <p className="text-sm text-red-600">{error}</p>}
        {!data && !error && <p className="text-slate-500">Memuat...</p>}
        {finalized && (
          <p className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-700">
            Submission sudah difinalisasi — hasil terkunci.
          </p>
        )}

        {data?.details.map((d) => {
          const effective =
            d.overridden_score ?? overrides[d.question_id] ?? d.similarity_score ?? 0;
          return (
            <div key={d.id} className="rounded-xl bg-white p-5 shadow">
              <div className="mb-2 flex items-center gap-2">
                <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                  {TYPE_LABEL[d.type] ?? d.type}
                </span>
                <h3 className="font-semibold text-slate-800">Soal {d.question_number}</h3>
                <span className="ml-auto text-xs text-slate-400">
                  {d.status}
                  {d.model_used ? ` · ${d.model_used}` : ''}
                </span>
              </div>

              {d.image_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={`/api${d.image_url}`}
                  alt={`Soal ${d.question_number}`}
                  className="mb-3 max-h-40 rounded-lg border"
                />
              )}

              <p className="text-sm">
                <span className="text-slate-500">Jawaban terbaca:</span>{' '}
                <span className="font-medium">{d.student_answer_text || '-'}</span>
              </p>
              <p className="text-sm">
                <span className="text-slate-500">Skor AI:</span>{' '}
                <span className="font-medium">{d.similarity_score ?? '-'}</span>
                {d.is_correct == null ? '' : d.is_correct ? ' (benar)' : ' (salah)'}
                {d.manual_override && <span className="ml-1 text-amber-600"> [diubah guru]</span>}
              </p>
              {d.ai_reasoning && (
                <p className="mt-1 text-xs text-slate-500">Alasan: {d.ai_reasoning}</p>
              )}

              {!finalized && (
                <div className="mt-3 flex items-center gap-3">
                  <span className="text-sm text-slate-600">Override:</span>
                  <input
                    type="range"
                    min={0}
                    max={100}
                    step={5}
                    value={effective}
                    onChange={(e) =>
                      setOverrides((prev) => ({
                        ...prev,
                        [d.question_id]: Number(e.target.value),
                      }))
                    }
                    className="flex-1"
                  />
                  <span className="w-10 text-right font-semibold">{effective}</span>
                </div>
              )}
            </div>
          );
        })}
      </section>
    </main>
  );
}
