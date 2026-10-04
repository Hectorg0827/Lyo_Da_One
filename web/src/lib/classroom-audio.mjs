/** A session-local, cancelable cache. A Response preserves the streaming body. */
export class SpeechPreparationCache {
  constructor(limit = 3) { this.limit = limit; this.entries = new Map(); }
  prepare(key, load) {
    if (this.entries.has(key)) return;
    const controller = new AbortController();
    const response = Promise.resolve().then(() => load(controller.signal)).catch(() => null);
    this.entries.set(key, { controller, response });
    while (this.entries.size > this.limit) {
      const oldest = this.entries.keys().next().value;
      this.entries.get(oldest).controller.abort();
      this.entries.delete(oldest);
    }
  }
  take(key) {
    const entry = this.entries.get(key);
    this.entries.delete(key);
    return entry;
  }
  clear() {
    for (const entry of this.entries.values()) entry.controller.abort();
    this.entries.clear();
  }
}

/** Board content remains visible while speech explains it; no fake reading wait. */
export function boardTransitionDelay() { return 0; }

/** Play MP3 bytes as they arrive where MediaSource supports them.
 * Other browsers retain the shared voice via one buffered download.
 * Cancellation owns the fetch as well as the player; a late response cannot speak.
 */
export async function playSpeechResponse(responsePromise, {
  signal: externalSignal, onStarted = () => {}, startupTimeoutMs = 8000,
  createAudio = () => new Audio(),
  MediaSourceClass = globalThis.MediaSource,
  urls = URL,
} = {}) {
  const lifetime = new AbortController();
  const signal = lifetime.signal;
  const cancel = () => lifetime.abort();
  externalSignal?.addEventListener('abort', cancel, { once: true });
  if (externalSignal?.aborted) cancel();
  const audio = createAudio();
  let url, reader, started = false, disposed = false, startupTimer, finishTimer;
  let fail, finish;
  const finished = new Promise((resolve, reject) => { finish = resolve; fail = reject; });
  const abort = () => fail(new DOMException('Playback interrupted', 'AbortError'));
  const playing = () => {
    if (started || disposed) return;
    started = true;
    clearTimeout(startupTimer);
    onStarted();
  };
  const errored = () => fail(new Error('Teacher audio playback failed'));
  audio.addEventListener('playing', playing);
  audio.addEventListener('ended', finish);
  audio.addEventListener('error', errored);
  signal?.addEventListener('abort', abort, { once: true });
  if (signal?.aborted) abort();
  startupTimer = setTimeout(() => fail(new Error('Teacher audio startup timed out')), startupTimeoutMs);
  finishTimer = setTimeout(() => fail(new Error('Teacher audio completion timed out')), 180000);

  const waitFor = (target, name) => new Promise((resolve, reject) => {
    const cleanup = () => {
      target.removeEventListener(name, ready);
      target.removeEventListener('error', error);
      signal?.removeEventListener('abort', canceled);
    };
    const ready = () => { cleanup(); resolve(); };
    const error = () => { cleanup(); reject(new Error('Invalid streamed audio')); };
    const canceled = () => { cleanup(); reject(new DOMException('Interrupted', 'AbortError')); };
    target.addEventListener(name, ready, { once: true });
    target.addEventListener('error', error, { once: true });
    signal?.addEventListener('abort', canceled, { once: true });
    if (signal?.aborted) canceled();
  });
  const ensureActive = () => {
    if (disposed || signal?.aborted) throw new DOMException('Interrupted', 'AbortError');
  };
  const pump = async () => {
    const response = await responsePromise;
    ensureActive();
    if (!response?.ok) throw new Error('Shared voice unavailable');
    const mime = response.headers.get('Content-Type')?.split(';')[0] || 'audio/mpeg';
    if (!response.body || !MediaSourceClass?.isTypeSupported(mime)) {
      const blob = await response.blob();
      ensureActive();
      url = urls.createObjectURL(blob);
      audio.src = url;
      await audio.play();
      return;
    }
    const media = new MediaSourceClass();
    const opened = waitFor(media, 'sourceopen');
    url = urls.createObjectURL(media);
    audio.src = url;
    await opened;
    ensureActive();
    const buffer = media.addSourceBuffer(mime);
    reader = response.body.getReader();
    let playbackRequested = false;
    while (true) {
      const { done, value } = await reader.read();
      ensureActive();
      if (done) break;
      const appended = waitFor(buffer, 'updateend');
      buffer.appendBuffer(value);
      await appended;
      if (!playbackRequested) {
        playbackRequested = true;
        // Playback starts before EOF. Do not await play(), which may itself
        // need more frames: keep feeding the decoder while it buffers.
        void audio.play().catch(fail);
      }
    }
    if (!playbackRequested) throw new Error('Empty teacher audio');
    if (media.readyState === 'open') media.endOfStream();
  };
  // A completed download is not a completed utterance. Only ended advances.
  void pump().catch(fail);
  try {
    await finished;
  } catch (error) {
    error.playbackStarted = started;
    throw error;
  } finally {
    disposed = true;
    externalSignal?.removeEventListener('abort', cancel);
    lifetime.abort();
    clearTimeout(startupTimer);
    clearTimeout(finishTimer);
    signal?.removeEventListener('abort', abort);
    audio.removeEventListener('playing', playing);
    audio.removeEventListener('ended', finish);
    audio.removeEventListener('error', errored);
    audio.pause();
    audio.removeAttribute('src');
    audio.load();
    if (reader) void reader.cancel().catch(() => {});
    if (url) urls.revokeObjectURL(url);
  }
}
