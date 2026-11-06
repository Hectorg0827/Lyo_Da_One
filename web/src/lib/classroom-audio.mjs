/** A session-local, cancelable cache. A Response preserves the streaming body. */
export class SpeechPreparationCache {
  constructor(limit = 3) { this.limit = limit; this.entries = new Map(); }
  hasPending() { return this.entries.size > 0; }
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
 * Keep short, fully downloaded teacher clips in memory for this classroom only.
 * Repeated coaching lines otherwise trigger a fresh 25–60s CPU synthesis even
 * when the same voice just said those exact words. No lesson text or audio is
 * written to browser storage and interrupted/partial streams are never cached.
 */
export class SessionSpeechReplayCache {
  constructor(limit = 24, maxBytes = 4 * 1024 * 1024, maxClipBytes = 512 * 1024) {
    this.limit = limit;
    this.maxBytes = maxBytes;
    this.maxClipBytes = maxClipBytes;
    this.entries = new Map();
    this.totalBytes = 0;
  }

  get(key) {
    const entry = this.entries.get(key);
    if (!entry) return null;
    // LRU: a frequently repeated coaching line should not be evicted first.
    this.entries.delete(key);
    this.entries.set(key, entry);
    return new Response(entry.bytes.slice(), { headers: { 'Content-Type': entry.mime } });
  }

  async remember(key, response, signal) {
    if (!response?.ok || !response.clone || signal?.aborted) return false;
    let clone;
    try {
      clone = response.clone();
      const reader = clone.body?.getReader();
      if (!reader) return false;
      const chunks = [];
      let size = 0;
      while (true) {
        if (signal?.aborted) throw new DOMException('Interrupted', 'AbortError');
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > this.maxClipBytes) {
          // A cloned stream is tee'd: awaiting cancel can hang until the
          // *original playback* reader also ends. Never hold the TTS path.
          void reader.cancel().catch(() => {});
          return false;
        }
        chunks.push(value);
      }
      if (signal?.aborted || size === 0) return false;
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.byteLength;
      }
      const mime = response.headers.get('Content-Type')?.split(';')[0] || 'audio/mpeg';
      const old = this.entries.get(key);
      if (old) this.totalBytes -= old.bytes.byteLength;
      this.entries.delete(key);
      this.entries.set(key, { bytes, mime });
      this.totalBytes += size;
      while (this.entries.size > this.limit || this.totalBytes > this.maxBytes) {
        const oldest = this.entries.keys().next().value;
        const discarded = this.entries.get(oldest);
        this.entries.delete(oldest);
        this.totalBytes -= discarded.bytes.byteLength;
      }
      return true;
    } catch {
      try { void clone?.body?.cancel()?.catch(() => {}); } catch { /* Already locked. */ }
      return false;
    }
  }

  clear() { this.entries.clear(); this.totalBytes = 0; }
}

/** The CPU TTS service must receive at most one speculative line at a time. */
export function firstAudibleTurn(turns) {
  return turns.find(turn =>
    (turn.type === 'speech' || turn.type === 'user_prompt') &&
    (turn.text ?? '').trim());
}

/** Text-only lesson turns must not simulate a missing seven-second narration.
 * The entire caption and transcript remain readable, while each visual beat
 * gets a brief pause before the next line becomes available.
 */
export function silentCaptionDelay(text) {
  return Math.min(1800, Math.max(650, Math.round((text?.length ?? 0) * 9)));
}

/**
 * A bounded speech pipeline for a single teacher turn. The caller starts the
 * next request only AFTER the current segment actually begins playing, so the
 * single-CPU voice server is free to produce the first audible words first.
 * The next segment can then synthesize while the student hears the current one.
 * An externally owned AbortController cancels all requests when interrupted.
 */
export class SpeechLookaheadQueue {
  constructor(segments, load, firstResponse) {
    this.segments = segments;
    this.load = load;
    this.pending = new Map();
    if (firstResponse !== undefined) this.pending.set(0, firstResponse);
  }

  get(index) {
    if (index < 0 || index >= this.segments.length) return null;
    if (!this.pending.has(index)) {
      // A prefetched request may be canceled while the current segment plays.
      // Catch it now so there is no unhandled rejection before take() awaits it.
      const response = Promise.resolve()
        .then(() => this.load(this.segments[index], index))
        .catch(() => null);
      this.pending.set(index, response);
    }
    return this.pending.get(index);
  }

  take(index) {
    const response = this.get(index);
    this.pending.delete(index);
    return response;
  }

  warmNext(index) { return this.get(index + 1); }
  clear() { this.pending.clear(); }
}

/**
 * Identify a safe end of a spoken thought, rather than a fixed number of words.
 * A voice model loses its prosody when a sentence is split in two TTS calls;
 * punctuation gives it the context to finish clauses naturally. Preserve math
 * decimals and common abbreviations, which are not sentence boundaries.
 */
function speechBoundaryStrength(word) {
  const end = word.replace(/["'”’\])}]+$/u, '');
  if (/^(?:mr|mrs|ms|dr|prof|sr|jr|vs|etc|e\.g|i\.e)\.$/iu.test(end) ||
      /^(?:[A-Z]\.){2,}$/u.test(end) || /^[A-Z]\.$/u.test(end)) return 0;
  if (/[.!?]$/u.test(end)) return 2;
  if (/[,;:]$/u.test(end)) return 1;
  return 0;
}

/**
 * The first *complete* clause can be spoken quickly while later speech loads.
 * firstChars/laterChars are preferred response-size hints, not hard cut points:
 * never chop a natural sentence simply because it crossed 40/65 characters.
 * Only punctuation-free run-ons fall back to a bounded word-boundary cut.
 */
export function splitSpeechForStreaming(text, firstChars = 40, laterChars = 65) {
  const words = (text || '').trim().split(/\s+/).filter(Boolean);
  if (!words.length) return [];
  const chunks = [];
  let current = '';
  for (const word of words) {
    const isFirst = chunks.length === 0;
    const target = Math.max(24, isFirst ? firstChars : laterChars);
    // A rare run-on sentence still must not monopolize a CPU speech service.
    const hardLimit = Math.max(isFirst ? 120 : 180, Math.round(target * 2.5));
    if (current && current.length + 1 + word.length > hardLimit) {
      chunks.push(current);
      current = word;
    } else {
      current = current ? `${current} ${word}` : word;
    }
    const boundary = speechBoundaryStrength(word);
    const naturalMinimum = Math.max(24, Math.floor(target * 0.7));
    if (boundary && current.length >= naturalMinimum) {
      chunks.push(current);
      current = '';
    }
  }
  if (current) {
    // A separate tiny last utterance is more jarring than including the last
    // words in the previous phrase; this is safe because audio has not started.
    if (chunks.length && current.length < 20) chunks[chunks.length - 1] += ` ${current}`;
    else chunks.push(current);
  }
  return chunks;
}

/**
 * Kokoro's native `stream:true` already emits audio in sentence chunks. Send
 * an entire short teacher line in ONE upstream call instead of paying the CPU
 * startup cost for each comma/sentence. Bound unusually long turns and keep
 * natural word/clause boundaries so they can still be interrupted safely.
 */
export function groupSpeechForProvider(text, maxChars = 280) {
  const clauses = splitSpeechForStreaming(text);
  const groups = [];
  let current = '';
  for (const clause of clauses) {
    const merged = current ? `${current} ${clause}` : clause;
    if (current && merged.length > maxChars) {
      groups.push(current);
      current = clause;
    } else {
      current = merged;
    }
  }
  if (current) groups.push(current);
  return groups;
}

/** Board content remains visible while speech explains it; no fake reading wait. */
export function boardTransitionDelay() { return 0; }

/** MediaSource can reject play() when its first appended MP3 fragment has not
 * yet supplied a decodable frame. More stream bytes can resolve that specific
 * transient condition; autoplay denials and other errors cannot.
 */
export function retryPlaybackAfterMoreAudio(error) {
  return error?.name === 'NotSupportedError';
}

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
    let playbackAttemptPending = false;
    let appendedChunks = 0;
    let streamComplete = false;
    let terminalPlaybackRetries = 0;
    const requestPlayback = () => {
      if (started || disposed || signal.aborted || playbackAttemptPending) return;
      playbackAttemptPending = true;
      // Do not await play(): a browser can keep that promise pending while it
      // buffers, and the reader must keep feeding decoder frames meanwhile.
      Promise.resolve().then(() => audio.play()).then(() => {
        playbackAttemptPending = false;
      }).catch((error) => {
        playbackAttemptPending = false;
        if (retryPlaybackAfterMoreAudio(error)) {
          if (!streamComplete) return;
          // Once at EOF is enough to distinguish an incomplete first MP3
          // fragment from a genuinely unplayable audio stream.
          if (terminalPlaybackRetries++ < 1) {
            queueMicrotask(requestPlayback);
            return;
          }
        }
        fail(error);
      });
    };
    while (true) {
      const { done, value } = await reader.read();
      ensureActive();
      if (done) break;
      const appended = waitFor(buffer, 'updateend');
      buffer.appendBuffer(value);
      await appended;
      appendedChunks += 1;
      requestPlayback();
    }
    streamComplete = true;
    if (!appendedChunks) throw new Error('Empty teacher audio');
    if (media.readyState === 'open') media.endOfStream();
    // Some decoders only recognize a short MP3 after the final frame lands.
    // If the first fragment was rejected, give the now-complete stream a turn.
    if (!started && !playbackAttemptPending) requestPlayback();
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
  startupTimeoutMs = 2500,
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
    let timeout, startupTimer;
    const cleanup = () => {
      clearTimeout(timeout);
      clearTimeout(startupTimer);
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
    utterance.onstart = () => {
      clearTimeout(startupTimer);
      onStarted();
    };
    utterance.onend = () => finish();
    utterance.onerror = (event) => finish(new Error(event?.error || 'Browser speech failed'));
    timeout = setTimeout(() => {
      synth.cancel();
      finish(new Error('Browser speech timed out'));
    }, Math.max(10000, text.length * 120));
    startupTimer = setTimeout(() => {
      synth.cancel();
      finish(new Error('Browser speech did not start'));
    }, startupTimeoutMs);
    try {
      synth.cancel();
      synth.speak(utterance);
    } catch (error) {
      finish(error);
    }
  });
}
