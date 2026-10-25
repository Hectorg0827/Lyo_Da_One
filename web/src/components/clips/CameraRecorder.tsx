'use client';

import { useEffect, useRef, useState } from 'react';
import { Camera, Circle, Loader2, Square, VideoOff } from 'lucide-react';

const MAX_SECONDS = 120;
const MAX_BYTES = 200 * 1024 * 1024;
const MIME_TYPES = [
  'video/mp4;codecs=avc1.42E01E,mp4a.40.2',
  'video/mp4',
  'video/webm;codecs=vp8,opus',
  'video/webm',
];

type CameraStatus = 'idle' | 'starting' | 'ready' | 'recording' | 'processing';

function cameraErrorMessage(error: unknown): string {
  if (error instanceof DOMException) {
    if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
      return 'Camera and microphone access was denied. Allow access in your browser settings, then try again.';
    }
    if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
      return 'No working camera or microphone was found on this device.';
    }
    if (error.name === 'NotReadableError') {
      return 'The camera is busy in another app. Close that app and try again.';
    }
  }
  return 'Could not start recording. Check your camera and microphone, or upload an existing video.';
}

/**
 * Records an actual browser camera stream. Captured files are handed to the
 * existing clip preview/upload path; no publish happens until the learner
 * reviews the recording and explicitly taps Publish.
 */
export default function CameraRecorder({
  onCaptured,
  onError,
  disabled = false,
}: {
  onCaptured: (file: File) => void;
  onError: (message: string) => void;
  disabled?: boolean;
}) {
  const [status, setStatus] = useState<CameraStatus>('idle');
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const liveVideoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const bytesRef = useRef(0);
  const exceededSizeRef = useRef(false);
  const mountedRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const clearRecordingTimer = () => {
    if (timerRef.current !== null) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  };

  const stopTracks = () => {
    streamRef.current?.getTracks().forEach(track => track.stop());
    streamRef.current = null;
    if (liveVideoRef.current) liveVideoRef.current.srcObject = null;
  };

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      clearRecordingTimer();
      const recorder = recorderRef.current;
      if (recorder && recorder.state !== 'inactive') {
        // Discard incomplete recordings when the sheet closes or the user
        // switches to Upload. Never keep capturing in the background.
        recorder.ondataavailable = null;
        recorder.onstop = null;
        recorder.onerror = null;
        recorder.stop();
      }
      stopTracks();
    };
  }, []);

  useEffect(() => {
    if ((status === 'ready' || status === 'recording') && liveVideoRef.current && streamRef.current) {
      liveVideoRef.current.srcObject = streamRef.current;
      void liveVideoRef.current.play().catch(() => {
        // The user can still tap the preview if their browser blocks autoplay.
      });
    }
  }, [status]);

  const openCamera = async () => {
    if (disabled || status !== 'idle') return;
    if (typeof navigator === 'undefined' || !navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      onError('This browser cannot record video directly. Use the device camera option or upload a video.');
      return;
    }
    onError('');
    setStatus('starting');
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: 'environment' } },
        audio: true,
      });
      if (!mountedRef.current) {
        stream.getTracks().forEach(track => track.stop());
        return;
      }
      streamRef.current = stream;
      setStatus('ready');
    } catch (error) {
      if (mountedRef.current) {
        onError(cameraErrorMessage(error));
        setStatus('idle');
      }
    }
  };

  const finishCamera = () => {
    const recorder = recorderRef.current;
    if (recorder && recorder.state !== 'inactive') {
      recorder.ondataavailable = null;
      recorder.onstop = null;
      recorder.onerror = null;
      recorder.stop();
    }
    recorderRef.current = null;
    clearRecordingTimer();
    stopTracks();
    setStatus('idle');
  };

  const stopRecording = () => {
    if (recorderRef.current?.state === 'recording') {
      setStatus('processing');
      recorderRef.current.stop();
    }
  };

  const startRecording = () => {
    if (!streamRef.current || disabled || status !== 'ready') return;
    const mimeType = MIME_TYPES.find(type => MediaRecorder.isTypeSupported(type));
    if (!mimeType) {
      onError('This browser cannot save MP4 or WebM recordings. Use the device camera option instead.');
      return;
    }
    try {
      const recorder = new MediaRecorder(streamRef.current, { mimeType });
      recorderRef.current = recorder;
      chunksRef.current = [];
      bytesRef.current = 0;
      exceededSizeRef.current = false;
      setElapsedSeconds(0);

      recorder.ondataavailable = event => {
        if (!event.data.size) return;
        chunksRef.current.push(event.data);
        bytesRef.current += event.data.size;
        if (bytesRef.current > MAX_BYTES && recorder.state === 'recording') {
          exceededSizeRef.current = true;
          recorder.stop();
          setStatus('processing');
        }
      };
      recorder.onerror = () => {
        onError('Recording failed. Please try again or upload a video.');
        finishCamera();
      };
      recorder.onstop = () => {
        clearRecordingTimer();
        stopTracks();
        recorderRef.current = null;
        if (!mountedRef.current) return;
        setStatus('idle');
        if (exceededSizeRef.current) {
          onError('The recording exceeded 200 MB. Record a shorter clip.');
          return;
        }
        const type = recorder.mimeType.split(';')[0] || 'video/webm';
        const blob = new Blob(chunksRef.current, { type });
        if (!blob.size) {
          onError('No video was captured. Please record again.');
          return;
        }
        if (blob.size > MAX_BYTES) {
          onError('The recording exceeded 200 MB. Record a shorter clip.');
          return;
        }
        const extension = type === 'video/mp4' ? 'mp4' : 'webm';
        onCaptured(new File([blob], `lyo-camera-${Date.now()}.${extension}`, { type }));
      };
      recorder.start(1000);
      setStatus('recording');
      const startedAt = Date.now();
      timerRef.current = setInterval(() => {
        const seconds = Math.floor((Date.now() - startedAt) / 1000);
        setElapsedSeconds(Math.min(seconds, MAX_SECONDS));
        if (seconds >= MAX_SECONDS && recorder.state === 'recording') {
          setStatus('processing');
          recorder.stop();
        }
      }, 250);
    } catch {
      onError('This browser could not initialize the video recorder. Try your device camera or upload.');
      finishCamera();
    }
  };

  const active = status === 'ready' || status === 'recording' || status === 'processing';
  return (
    <div className="space-y-3 rounded-xl border border-white/15 bg-black/30 p-3">
      {active ? (
        <video
          ref={liveVideoRef}
          autoPlay
          muted
          playsInline
          aria-label="Live camera preview"
          className="max-h-64 w-full rounded-lg bg-black object-contain"
        />
      ) : (
        <div className="flex min-h-32 flex-col items-center justify-center gap-2 text-white/55">
          <VideoOff className="h-7 w-7" />
          <span className="text-sm">Camera is off until you enable it</span>
        </div>
      )}

      {status === 'recording' || status === 'processing' ? (
        <div className="flex items-center justify-between gap-3">
          <span role="status" className="text-sm font-medium text-red-300">
            ● {status === 'processing' ? 'Saving recording…' : `Recording ${String(Math.floor(elapsedSeconds / 60)).padStart(2, '0')}:${String(elapsedSeconds % 60).padStart(2, '0')}`}
          </span>
          <button
            type="button"
            onClick={stopRecording}
            disabled={disabled || status === 'processing'}
            className="flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            <Square className="h-4 w-4" /> Stop
          </button>
        </div>
      ) : status === 'ready' ? (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={startRecording}
            disabled={disabled}
            className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            <Circle className="h-4 w-4 fill-current" /> Start recording
          </button>
          <button type="button" onClick={finishCamera} className="rounded-lg border border-white/20 px-4 py-2 text-sm text-white/75">
            Cancel camera
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={openCamera}
          disabled={disabled || status === 'starting'}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-white px-4 py-2.5 text-sm font-semibold text-black disabled:opacity-50"
        >
          {status === 'starting' ? <Loader2 className="h-4 w-4 animate-spin" /> : <Camera className="h-4 w-4" />}
          {status === 'starting' ? 'Opening camera…' : 'Enable camera & microphone'}
        </button>
      )}
      <p className="text-xs text-white/55">
        Record up to 2 minutes. Nothing is uploaded until you review the video and select Publish clip.
      </p>
    </div>
  );
}
