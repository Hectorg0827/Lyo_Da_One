'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Flag, Loader2, X } from 'lucide-react';
import { api, ApiError } from '@/lib/api';
import { REPORT_NOTE_LIMIT, REPORT_REASONS, reportOutcome, type ReportOutcome } from '@/lib/discover-report.mjs';

/**
 * Report one Discover video.
 *
 * The learner picks a reason and may add a note. What the server answers
 * decides whether the video leaves this learner's feed (reportOutcome); a
 * failure keeps the sheet open, with the choices intact, so they can retry.
 */
export default function ReportClipSheet({
  clipId,
  clipTitle,
  onClose,
  onDone,
}: {
  clipId: string;
  clipTitle: string;
  onClose: () => void;
  onDone: (outcome: ReportOutcome) => void;
}) {
  const [reason, setReason] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !sending) onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose, sending]);

  const submit = async () => {
    if (!reason || sending) return;
    setSending(true);
    setError(null);
    let status = 0;
    try {
      await api.clips.report(clipId, reason, note.trim());
      status = 200;
    } catch (err) {
      status = err instanceof ApiError ? err.status : 0;
    }
    const outcome = reportOutcome(status);
    setSending(false);
    if (outcome.leaveFeed) onDone(outcome);
    else setError(outcome.message);
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[70] flex items-end justify-center bg-black/60 sm:items-center"
      onClick={(event) => {
        event.stopPropagation();
        if (!sending) onClose();
      }}
    >
      <motion.div
        role="dialog"
        aria-modal="true"
        aria-labelledby="report-clip-heading"
        initial={{ y: 40 }}
        animate={{ y: 0 }}
        exit={{ y: 40 }}
        transition={{ type: 'tween', duration: 0.2 }}
        className="max-h-[100dvh] w-full max-w-md overflow-y-auto rounded-t-2xl border border-white/10 bg-[#050810] p-5 pb-[calc(1.25rem+env(safe-area-inset-bottom))] text-white sm:rounded-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 id="report-clip-heading" className="flex items-center gap-2 text-base font-semibold">
              <Flag className="h-4 w-4 text-red-400" aria-hidden="true" />
              Report video
            </h2>
            <p className="mt-1 truncate text-sm text-white/50">{clipTitle}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={sending}
            aria-label="Close report"
            className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </header>

        <form
          className="mt-4"
          onSubmit={(event) => {
            event.preventDefault();
            submit();
          }}
        >
          <fieldset disabled={sending}>
            <legend className="mb-2 text-sm text-white/70">What&apos;s wrong with this video?</legend>
            <div className="space-y-1.5">
              {REPORT_REASONS.map((option) => (
                <label
                  key={option.value}
                  className={`flex cursor-pointer items-center gap-3 rounded-xl border px-3 py-2.5 text-sm transition-colors ${
                    reason === option.value ? 'border-red-400/70 bg-red-500/10' : 'border-white/10 hover:bg-white/5'
                  }`}
                >
                  <input
                    type="radio"
                    name="report-reason"
                    value={option.value}
                    checked={reason === option.value}
                    onChange={() => setReason(option.value)}
                    className="accent-red-500"
                  />
                  {option.label}
                </label>
              ))}
            </div>

            <label className="mt-3 block text-sm text-white/70">
              Anything else we should know? (optional)
              <textarea
                value={note}
                onChange={(event) => setNote(event.target.value)}
                maxLength={REPORT_NOTE_LIMIT}
                rows={2}
                className="mt-1 w-full resize-none rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none focus:border-red-400/60"
              />
            </label>
          </fieldset>

          {error && (
            <p role="alert" className="mt-3 text-sm text-red-400">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={!reason || sending}
            className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-red-500 py-2.5 text-sm font-semibold text-white disabled:opacity-40"
          >
            {sending && <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />}
            Send report
          </button>
        </form>
      </motion.div>
    </motion.div>
  );
}
