'use client';

import { useEffect, useRef, useState } from 'react';
import { Camera, Upload, Loader2, X } from 'lucide-react';
import { api } from '@/lib/api';
import CameraRecorder from './CameraRecorder';

/**
 * Publish a clip.
 *
 * Lifted out of the old `/clips` page so Discover can use it. Posting used to
 * live only on that second reel page, which the mobile nav never linked — so
 * on a phone, the surface built for watching clips had no way to make one.
 *
 * `enableCourseGeneration` is sent true because a clip that can become a
 * course is the thing this feed has that a general video app does not.
 */
export default function CreateClipModal({
  onClose,
  onCreated,
  initialTitle = '',
  initialSubject = '',
  initialSource = null,
}: {
  onClose: () => void;
  onCreated: () => void;
  /** Lets a caller arrive with the subject already known, e.g. from a finished course. */
  initialTitle?: string;
  initialSubject?: string;
  /** Create can open directly on Camera or Upload. Discover can show both. */
  initialSource?: 'camera' | 'upload' | null;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState(initialTitle);
  const [subject, setSubject] = useState(initialSubject);
  const [description, setDescription] = useState('');
  const [progress, setProgress] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [source, setSource] = useState<'camera' | 'upload' | null>(initialSource);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const cameraRef = useRef<HTMLInputElement | null>(null);
  const uploadRef = useRef<HTMLInputElement | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const chooseFile = (candidate: File | null) => {
    setError(null);
    if (!candidate) return;
    if (!['video/mp4', 'video/quicktime', 'video/webm'].includes(candidate.type)) {
      setError('Select an MP4, MOV or WebM video.');
      return;
    }
    if (candidate.size === 0 || candidate.size > 200 * 1024 * 1024) {
      setError('Videos must be nonempty and no larger than 200 MB.');
      return;
    }
    setFile(candidate);
  };

  const submit = async () => {
    if (!file || !title.trim() || progress) return;
    setError(null);
    try {
      setProgress('Uploading video…');
      const uploaded = await api.media.upload(file, 'clips');
      setProgress('Publishing…');
      const duration =
        videoRef.current?.duration && isFinite(videoRef.current.duration)
          ? videoRef.current.duration
          : 0;
      await api.clips.create({
        title: title.trim(),
        description: description.trim() || null,
        videoUrl: uploaded.url,
        thumbnailUrl: null,
        durationSeconds: duration,
        subject: subject.trim() || null,
        topic: null,
        level: 'beginner',
        keyPoints: [],
        tags: subject.trim() ? [subject.trim().toLowerCase()] : [],
        isPublic: true,
        enableCourseGeneration: true,
      });
      onCreated();
      onClose();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to publish the clip.');
      setProgress(null);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      onMouseDown={(event) => event.target === event.currentTarget && onClose()}
    >
      <section
        role="dialog"
        aria-modal="true"
        aria-label="Create a clip"
        className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/10 bg-[#11121a] shadow-2xl"
      >
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 className="text-lg font-semibold text-white">Create a Clip</h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"
          >
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="max-h-[70vh] space-y-4 overflow-y-auto p-5">
          <div className="space-y-2">
            <p className="text-sm text-white/65">Video (MP4, MOV or WebM; maximum 200 MB)</p>
            <div className="grid grid-cols-2 gap-3" role="group" aria-label="Video source">
              <button type="button" onClick={() => setSource('camera')} disabled={!!progress}
                aria-pressed={source === 'camera'}
                className={`flex items-center justify-center gap-2 rounded-xl border p-3 text-white disabled:opacity-50 ${source === 'camera' ? 'border-lyo-400 bg-lyo-500/25' : 'border-white/20 bg-white/10 hover:bg-white/15'}`}>
                <Camera className="h-5 w-5" /> Camera
              </button>
              <button type="button" onClick={() => setSource('upload')} disabled={!!progress}
                aria-pressed={source === 'upload'}
                className={`flex items-center justify-center gap-2 rounded-xl border p-3 text-white disabled:opacity-50 ${source === 'upload' ? 'border-lyo-400 bg-lyo-500/25' : 'border-white/20 bg-white/10 hover:bg-white/15'}`}>
                <Upload className="h-5 w-5" /> Upload
              </button>
            </div>
            {source === 'camera' && (
              <>
                <CameraRecorder onCaptured={chooseFile} onError={setError} disabled={!!progress} />
                <button type="button" onClick={() => cameraRef.current?.click()} disabled={!!progress}
                  className="w-full rounded-xl border border-white/20 px-3 py-2 text-sm text-white/75 hover:bg-white/10 disabled:opacity-50">
                  Open device camera app instead
                </button>
              </>
            )}
            {source === 'upload' && (
              <button type="button" onClick={() => uploadRef.current?.click()} disabled={!!progress}
                className="flex w-full items-center justify-center gap-2 rounded-xl border border-white/20 bg-white/10 p-3 text-white hover:bg-white/15 disabled:opacity-50">
                <Upload className="h-5 w-5" /> Choose existing video
              </button>
            )}
            <input ref={cameraRef} className="sr-only" type="file" accept="video/*" capture="environment"
              aria-label="Record video with camera" onChange={(event) => chooseFile(event.target.files?.[0] ?? null)} />
            <input ref={uploadRef} className="sr-only" type="file"
              accept="video/mp4,video/quicktime,video/webm"
              aria-label="Upload video from device" onChange={(event) => chooseFile(event.target.files?.[0] ?? null)} />
            <p className="text-xs text-white/50">Use the browser camera to record on desktop or mobile, your phone's camera app, or upload an existing file.</p>
          </div>
          {file && previewUrl && (
            <video
              ref={videoRef}
              src={previewUrl}
              controls
              className="max-h-56 w-full rounded-xl border border-white/10 bg-black"
            />
          )}
          <label className="block text-sm text-white/65">
            Title
            <input
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              maxLength={200}
              className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none"
            />
          </label>
          <label className="block text-sm text-white/65">
            Subject (optional)
            <input
              value={subject}
              onChange={(event) => setSubject(event.target.value)}
              maxLength={100}
              placeholder="e.g. Mathematics"
              className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none"
            />
          </label>
          <label className="block text-sm text-white/65">
            Description (optional)
            <textarea
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              rows={2}
              maxLength={2000}
              className="mt-1.5 w-full resize-y rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none"
            />
          </label>
          {error && (
            <p role="alert" className="text-sm text-red-400">
              {error}
            </p>
          )}
        </div>

        <footer className="flex justify-end gap-3 border-t border-white/10 px-5 py-4">
          <button
            onClick={onClose}
            disabled={!!progress}
            className="rounded-xl border border-white/15 px-4 py-2.5 text-sm text-white/70 hover:bg-white/10"
          >
            Cancel
          </button>
          <button
            onClick={submit}
            disabled={!file || !title.trim() || !!progress}
            className="flex min-w-36 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
          >
            {progress ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                {progress}
              </>
            ) : (
              'Publish clip'
            )}
          </button>
        </footer>
      </section>
    </div>
  );
}
