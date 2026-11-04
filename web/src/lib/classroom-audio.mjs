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

/**
 * Short first utterance lets self-hosted CPU speech begin while the teacher's
 * full explanation is still being synthesized. Split only at word boundaries;
 * the same voice and rate are used for every segment. Never trim content away.
 */
export function splitSpeechForStreaming(text, firstChars = 40, laterChars = 65) {
  const words = (text || '').trim().split(/\s+/).filter(Boolean);
  if (!words.length) return [];
  const chunks = [];
  let current = '';
  for (const word of words) {
    const limit = chunks.length === 0 ? firstChars : laterChars;
    if (current && current.length + 1 + word.length > limit) {
      chunks.push(current);
      current = word;
    } else {
      current = current ? `${current} ${word}` : word;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

/** Board content remains visible while speech explains it; no fake reading wait. */
export function boardTransitionDelay() { return 0; }

/** Play MP3 bytes as they arrive where MediaSource supports them.
 * Other browsers retain the shared voice via one buffered download.
 * Cancellation owns the fetch as well as the player; a late response cannot speak.
 */
export async function playSpeechResponse(responsePromise, {
  signal: externalSignal, onStarted = () => {}, startupTimeoutMs = 30000,
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


/**
 * Accessible backup when the configured classroom speech service is offline.
 * Prefer a local natural voice, keep the speaker's language, and let the
 * classroom's AbortController own cancellation. This never calls a paid API.
 */
export function speakBrowserFallback(text, {
  language = 'en', rate = 1, signal, onStarted = () => {},
  synth = globalThis.speechSynthesis,
  Utterance = globalThis.SpeechSynthesisUtterance,
} = {}) {
  if (!synth || !Utterance || !text?.trim()) {
    return Promise.reject(new Error('No browser speech voice available'));
  }
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new DOMException('Playback interrupted', 'AbortError'));
      return;
    }
    const utterance = new Utterance(text);
    const lang = language === 'auto' ? 'en' : language;
    const voices = synth.getVoices?.() ?? [];
    const sameLanguage = voices.filter((voice) =>
      voice.lang?.toLowerCase().startsWith(lang.slice(0, 2).toLowerCase()));
    const preferred = [
      /natural|neural|enhanced|premium/i,
      /aria|jenny|samantha|karen|google us english|google español/i,
    ];
    utterance.voice = preferred.map((pattern) => sameLanguage.find((voice) =>
      pattern.test(voice.name))).find(Boolean) || sameLanguage[0] || null;
    utterance.lang = utterance.voice?.lang || lang;
    utterance.rate = Math.max(0.8, Math.min(1.2, rate));
    let settled = false;
    let timeout;
    const cleanup = () => {
      clearTimeout(timeout);
      signal?.removeEventListener('abort', interrupted);
      utterance.onstart = utterance.onend = utterance.onerror = null;
    };
    const finish = (error) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (error) reject(error);
      else resolve();
    };
    const interrupted = () => {
      synth.cancel();
      finish(new DOMException('Playback interrupted', 'AbortError'));
    };
    signal?.addEventListener('abort', interrupted, { once: true });
    utterance.onstart = () => onStarted();
    utterance.onend = () => finish();
    utterance.onerror = (event) => finish(new Error(event?.error || 'Browser speech failed'));
    timeout = setTimeout(() => {
      synth.cancel();
      finish(new Error('Browser speech timed out'));
    }, Math.max(10000, text.length * 120));
    try {
      synth.cancel();
      synth.speak(utterance);
    } catch (error) {
      finish(error);
    }
  });
}
