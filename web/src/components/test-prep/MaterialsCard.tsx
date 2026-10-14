'use client';

import { useState } from 'react';
import { ChevronDown, FileText, FolderOpen, Image as ImageIcon, Loader2, Plus, Upload, X } from 'lucide-react';

import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { filterMaterials, materialFilters, materialKind } from '@/lib/test-prep-view.mjs';
import type { MaterialFilterKey } from '@/lib/test-prep-view.mjs';
import type { PrepMaterial, PrepSnapshot } from '@/lib/test-prep-api';

const ACCEPT = 'image/png,image/jpeg,image/webp,application/pdf,text/plain';

/**
 * Study materials, open.
 *
 * This was a collapsed `<details>` whose entire contents were an unstyled
 * list of filenames and a bare `<input type="file">`. On a desktop there is
 * room to show the library itself: a filter rail, the files with their kind
 * and size, and a dropzone that says what it is for.
 *
 * The empty state is the point of the card, not an afterthought — a learner
 * with no materials is the one who most needs to be told that uploading their
 * notes is what makes the plan theirs.
 */

const KIND_STYLES = {
  pdf: { icon: FileText, wrap: 'bg-rose-500/[0.18]', tint: 'text-rose-300', label: 'PDF' },
  image: { icon: ImageIcon, wrap: 'bg-blue-500/20', tint: 'text-blue-300', label: 'Image' },
  note: { icon: FileText, wrap: 'bg-emerald-500/[0.18]', tint: 'text-emerald-300', label: 'Text' },
} as const;

export interface MaterialsCardProps {
  snapshot: PrepSnapshot;
  onSaved: () => Promise<void>;
}

export function MaterialsCard({ snapshot, onSaved }: MaterialsCardProps) {
  const [open, setOpen] = useState(true);
  const [active, setActive] = useState<MaterialFilterKey>('all');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const profile = snapshot.profile;
  const materials = profile?.materials ?? [];
  const filters = materialFilters(materials);
  const shown = filterMaterials(materials, active);

  // Writes go through `editProfile` with the snapshot's revision, exactly as
  // before: this card changed how materials look, not who owns them.
  const save = async (next: PrepMaterial[], failure: string) => {
    if (!profile || busy) return;
    setBusy(true);
    setError(null);
    try {
      await api.testPrep.editProfile(profile.id, {
        expected_revision: snapshot.revision,
        materials: next,
      });
      await onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : failure);
    } finally {
      setBusy(false);
    }
  };

  const upload = async (file: File) => {
    if (!profile || busy) return;
    setBusy(true);
    setError(null);
    try {
      const uploaded = await api.media.upload(file, 'test-prep');
      await api.testPrep.editProfile(profile.id, {
        expected_revision: snapshot.revision,
        materials: [
          ...materials,
          {
            name: file.name,
            uri: uploaded.url,
            mime_type: file.type,
            modality: file.type.startsWith('image/') ? 'IMAGE' : 'DOCUMENT',
          },
        ],
      });
      await onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed.');
    } finally {
      setBusy(false);
    }
  };

  if (!profile) return null;

  return (
    <section className="rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] p-5 shadow-[0_6px_12px_rgba(0,0,0,0.18)] sm:p-[22px]">
      <div className="flex flex-wrap items-center gap-2.5">
        <button
          type="button"
          onClick={() => setOpen(!open)}
          aria-expanded={open}
          aria-label={open ? 'Collapse study materials' : 'Expand study materials'}
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/[0.07] hover:text-white"
        >
          <ChevronDown className={cn('h-4 w-4 transition-transform', open ? '' : '-rotate-90')} aria-hidden />
        </button>
        <FolderOpen className="h-4 w-4 shrink-0 text-amber-400" aria-hidden />
        <h3 className="min-w-0 font-rounded text-lg font-bold text-white">
          Study Materials &middot; {materials.length}
        </h3>
        <span className="flex-1" />
        {materials.length > 0 && (
          <label
            className={cn(
              'inline-flex min-h-[40px] shrink-0 cursor-pointer items-center gap-2 rounded-[13px] px-4 py-2.5',
              'bg-gradient-to-r from-lyo-600 to-lyo-400 text-[13px] font-semibold text-white',
              'shadow-lg shadow-lyo-600/25 transition hover:shadow-lyo-500/40',
              busy && 'pointer-events-none opacity-60',
            )}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : <Plus className="h-4 w-4" aria-hidden />}
            Upload / Add
            <input
              type="file"
              accept={ACCEPT}
              disabled={busy}
              className="sr-only"
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.target.value = '';
                if (file) void upload(file);
              }}
            />
          </label>
        )}
      </div>

      {error && (
        <p role="alert" className="mt-3 text-sm text-amber-200">
          {error}
        </p>
      )}

      {open && (
        <div className="mt-4 flex flex-wrap gap-4">
          {/* ── Filter rail: a column on desktop, chips on a phone ── */}
          {materials.length > 0 && (
            <nav
              aria-label="Filter materials"
              className="no-scrollbar flex w-full shrink-0 gap-1.5 overflow-x-auto pb-1 lg:w-32 lg:flex-col lg:overflow-visible lg:pb-0"
            >
              {filters.map((filter) => (
                <button
                  key={filter.key}
                  type="button"
                  onClick={() => setActive(filter.key)}
                  aria-pressed={active === filter.key}
                  className={cn(
                    'shrink-0 rounded-xl px-3 py-2 text-left text-[13px] transition',
                    active === filter.key
                      ? 'bg-lyo-400/20 font-semibold text-white'
                      : 'text-white/60 hover:bg-white/[0.05] hover:text-white/85',
                  )}
                >
                  {filter.label} &middot; {filter.count}
                </button>
              ))}
            </nav>
          )}

          <div className="min-w-0 flex-1 basis-[300px]">
            {materials.length === 0 ? (
              <EmptyState busy={busy} onPick={(file) => void upload(file)} />
            ) : shown.length === 0 ? (
              <p className="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-8 text-center text-sm text-white/55">
                Nothing of that kind yet.
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                {shown.map((material, index) => {
                  const kind = materialKind(material);
                  const { icon: Icon, wrap, tint, label } = KIND_STYLES[kind];
                  return (
                    <li
                      key={`${material.uri}-${index}`}
                      className="flex items-center gap-3 rounded-2xl bg-white/[0.05] px-3.5 py-3"
                    >
                      <span className={cn('flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px]', wrap)}>
                        <Icon className={cn('h-4 w-4', tint)} aria-hidden />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-medium text-white">{material.name}</span>
                        <span className="mt-0.5 block text-[11px] text-white/55">{label} &middot; read by Lyo</span>
                      </span>
                      <button
                        type="button"
                        disabled={busy}
                        aria-label={`Remove ${material.name}`}
                        onClick={() =>
                          void save(
                            materials.filter((candidate) => candidate !== material),
                            'Could not remove that file.',
                          )
                        }
                        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px] text-white/45 transition hover:bg-white/[0.08] hover:text-white disabled:opacity-40"
                      >
                        <X className="h-4 w-4" aria-hidden />
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}

            {materials.length > 0 && (
              <label
                className={cn(
                  'mt-3 flex min-h-[56px] cursor-pointer items-center justify-center gap-2.5 rounded-2xl',
                  'border-[1.5px] border-dashed border-lyo-300/40 bg-lyo-400/[0.07] p-3.5',
                  'text-sm font-semibold text-lyo-100 transition hover:bg-lyo-400/[0.12]',
                  busy && 'pointer-events-none opacity-60',
                )}
              >
                <Upload className="h-4 w-4" aria-hidden />
                Drop a photo, PDF or notes
                <input
                  type="file"
                  accept={ACCEPT}
                  disabled={busy}
                  className="sr-only"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    event.target.value = '';
                    if (file) void upload(file);
                  }}
                />
              </label>
            )}
          </div>
        </div>
      )}
    </section>
  );
}

function EmptyState({ busy, onPick }: { busy: boolean; onPick: (file: File) => void }) {
  return (
    <label
      className={cn(
        'flex cursor-pointer flex-col items-center gap-1 rounded-[18px] border-[1.5px] border-dashed',
        'border-lyo-300/[0.38] bg-lyo-400/[0.055] px-5 py-7 text-center transition hover:bg-lyo-400/[0.1]',
        busy && 'pointer-events-none opacity-60',
      )}
    >
      <svg width="112" height="74" viewBox="0 0 112 74" fill="none" role="img" aria-label="No materials added yet">
        <rect
          x="16" y="16" width="50" height="48" rx="7"
          fill="rgba(255,255,255,0.05)" stroke="rgba(255,255,255,0.16)" strokeWidth="1.6"
          transform="rotate(-8 41 40)"
        />
        <rect
          x="34" y="9" width="50" height="48" rx="7"
          fill="rgba(139,92,246,0.14)" stroke="rgba(167,139,250,0.45)" strokeWidth="1.6"
          transform="rotate(7 59 33)"
        />
        <path d="M50 24h14l6 6v16H50Z" fill="none" stroke="rgba(221,214,254,0.8)" strokeWidth="1.8" strokeLinejoin="round" />
        <path d="M64 24v6h6" fill="none" stroke="rgba(221,214,254,0.8)" strokeWidth="1.8" strokeLinejoin="round" />
        <circle cx="92" cy="52" r="13" fill="#8b5cf6" />
        <path d="M92 46v12M86 52h12" stroke="#ffffff" strokeWidth="2.4" strokeLinecap="round" />
      </svg>
      <span className="mt-2 font-rounded text-[17px] font-bold text-white">Nothing added yet</span>
      <span className="max-w-[46ch] text-[13px] leading-[1.55] text-white/60">
        Drop in a photo of your notes, a PDF or a syllabus and Lyo will study it with you.
      </span>
      <span className="mt-3.5 inline-flex min-h-[44px] items-center gap-2 rounded-2xl border border-white/[0.18] bg-white/[0.07] px-5 py-3 text-sm font-semibold text-white">
        {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : <Upload className="h-4 w-4" aria-hidden />}
        {busy ? 'Uploading…' : 'Browse your files'}
      </span>
      <input
        type="file"
        accept={ACCEPT}
        disabled={busy}
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) onPick(file);
        }}
      />
    </label>
  );
}
