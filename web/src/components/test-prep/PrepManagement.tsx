'use client';

import { useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { sessionDate, type PrepSnapshot } from '@/lib/test-prep-api';
import { sessionEntryHref } from '@/lib/test-prep.mjs';

export function PrepManagement({ snapshot, onSaved }: { snapshot: PrepSnapshot; onSaved: () => Promise<void> }) {
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const profile = snapshot.profile;
  if (!profile) return null;
  const inputClass = 'mt-1 w-full rounded-xl border border-white/20 bg-slate-950 px-3 py-2 text-white';
  return <section className="mt-5 space-y-4">
    <button className="rounded-xl border border-white/20 px-4 py-2 text-sm text-white"
      onClick={() => setEditing(!editing)}>{editing ? 'Close details' : 'Edit test details'}</button>
    {error && <p role="alert" className="text-sm text-amber-200">{error}</p>}
    {editing && <form key={snapshot.revision} className="grid gap-4 rounded-2xl border border-white/10 p-5 text-sm text-white/80"
      onSubmit={async e => {
        e.preventDefault(); if (busy) return;
        const data = new FormData(e.currentTarget);
        setBusy(true); setError(null);
        try {
          const result = await api.testPrep.editProfile(profile.id, {
            expected_revision: snapshot.revision, subject: String(data.get('subject')),
            test_date: String(data.get('date')), daily_minutes_available: Number(data.get('minutes')),
            study_days_per_week: Number(data.get('days')), timezone: String(data.get('timezone')),
            topics: String(data.get('topics')).split('\n').map(name => name.trim()).filter(Boolean)
              .map(name => profile.topics.find(t => t.name === name) ?? { name, weight: 1, confidence: 5 }),
          });
          if (result.needs_plan) await api.testPrep.generatePlan(profile.id);
          setEditing(false); await onSaved();
        } catch (err) {
          setError(err instanceof Error ? err.message : 'Could not save your changes.');
          await onSaved();
        } finally { setBusy(false); }
      }}>
      <p>Updating details rebuilds upcoming sessions. Your completed work stays in your record.</p>
      <label>Subject<input name="subject" required maxLength={100} defaultValue={profile.subject} className={inputClass} /></label>
      <label>Test date<input type="date" name="date" required defaultValue={profile.test_date} className={inputClass} /></label>
      <label>Topics — one per line<textarea name="topics" required defaultValue={profile.topics.map(t => t.name).join('\n')} className={inputClass} /></label>
      <div className="grid grid-cols-2 gap-3">
        <label>Minutes per day<input type="number" name="minutes" min={5} max={480} required defaultValue={profile.daily_minutes_available} className={inputClass} /></label>
        <label>Days per week<input type="number" name="days" min={1} max={7} required defaultValue={profile.study_days_per_week} className={inputClass} /></label>
      </div>
      <label>Study timezone<input name="timezone" required defaultValue={snapshot.timezone} className={inputClass} /></label>
      <button disabled={busy} className="rounded-xl bg-violet-600 px-4 py-3 text-white disabled:opacity-50">{busy ? 'Saving your plan…' : 'Save and update schedule'}</button>
    </form>}
    <details className="rounded-2xl border border-white/10 bg-white/[0.03] p-5 text-white">
      <summary className="cursor-pointer font-medium">Full study schedule · {snapshot.timezone}</summary>
      <div className="mt-4 space-y-3">
        {snapshot.plan?.weekly_milestones?.map(m => <p key={m.week} className="text-sm text-violet-200">Week {m.week}: {m.focus}</p>)}
        {snapshot.sessions.map(session => {
          const href = sessionEntryHref(session);
          return <article key={session.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white/5 p-3">
            <div><p>{session.topic}</p><p className="text-xs text-white/60">{sessionDate(session.scheduled_at).toLocaleString(undefined, { timeZone: snapshot.timezone })} · {session.duration_minutes} min · {session.session_type.replace('_', ' ')}</p></div>
            {session.status === 'scheduled' && href ? <Link href={href} className="rounded-lg bg-violet-500/20 px-3 py-2 text-sm text-violet-100">Start session</Link> : <span className="text-sm text-white/60">{session.status}</span>}
          </article>;
        })}
      </div>
    </details>
    <details className="rounded-2xl border border-white/10 p-5 text-white">
      <summary className="cursor-pointer font-medium">Study materials · {profile.materials.length}</summary>
      <ul className="my-3 text-sm text-white/70">{profile.materials.map((m, i) => <li key={i}>{m.name}</li>)}</ul>
      <label className="text-sm">Add a photo, PDF or notes
        <input type="file" accept="image/png,image/jpeg,image/webp,application/pdf,text/plain" disabled={busy} className="mt-2 block w-full"
          onChange={async event => {
            const file = event.target.files?.[0]; if (!file) return;
            setBusy(true); setError(null);
            try {
              const uploaded = await api.media.upload(file, 'test-prep');
              await api.testPrep.editProfile(profile.id, { expected_revision: snapshot.revision,
                materials: [...profile.materials, { name: file.name, uri: uploaded.url, mime_type: file.type,
                  modality: file.type.startsWith('image/') ? 'IMAGE' : 'DOCUMENT' }] });
              await onSaved();
            } catch (err) { setError(err instanceof Error ? err.message : 'Upload failed.'); }
            finally { setBusy(false); event.target.value = ''; }
          }} />
      </label>
    </details>
  </section>;
}
