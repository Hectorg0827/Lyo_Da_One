/** Abortable playback: cancellation settles even when the browser emits no end. */
export function playVoiceBlob(blob, { signal, volume = 1, onAudio, onStart, onProgress } = {}) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) { reject(new DOMException('Cancelled', 'AbortError')); return; }
    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener('abort', abort);
      audio.onplaying = audio.ontimeupdate = audio.onended = audio.onerror = null;
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
      URL.revokeObjectURL(url);
      onAudio?.(null, audio);
      if (error) reject(error); else resolve();
    };
    const abort = () => finish(new DOMException('Cancelled', 'AbortError'));
    signal?.addEventListener('abort', abort, { once: true });
    audio.volume = volume;
    onAudio?.(audio, audio);
    audio.onplaying = () => { if (!settled) onStart?.(); };
    audio.ontimeupdate = () => {
      if (!settled && Number.isFinite(audio.duration) && audio.duration > 0) {
        onProgress?.(Math.min(1, Math.max(0, audio.currentTime / audio.duration)));
      }
    };
    audio.onended = () => {
      if (settled) return;
      onProgress?.(1);
      finish();
    };
    audio.onerror = () => finish(new Error('Audio playback failed'));
    try { Promise.resolve(audio.play()).catch(finish); } catch (error) { finish(error); }
  });
}

/** Device TTS uses the same cancellation contract as server audio. */
export function speakVoiceFallback(text, { signal, language, onStart } = {}) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) { reject(new DOMException('Cancelled', 'AbortError')); return; }
    const synth = globalThis.speechSynthesis;
    if (!synth) { reject(new Error('Speech playback unavailable')); return; }
    const utterance = new SpeechSynthesisUtterance(text);
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener('abort', abort);
      utterance.onstart = utterance.onend = utterance.onerror = null;
      if (error) reject(error); else resolve();
    };
    const abort = () => {
      finish(new DOMException('Cancelled', 'AbortError'));
      synth.cancel();
    };
    signal?.addEventListener('abort', abort, { once: true });
    utterance.lang = language || 'en-US';
    utterance.rate = 1.02;
    utterance.onstart = () => { if (!settled) onStart?.(); };
    utterance.onend = () => finish();
    utterance.onerror = () => finish(new Error('Device speech failed'));
    try { synth.speak(utterance); } catch (error) { finish(error); }
  });
}

/** Progress is an estimate; never repeat already completed segments. */
export function unspokenRemainder(text, fraction = 0) {
  const words = text.trim().split(/\s+/);
  const played = Number.isFinite(fraction) ? Math.max(0, Math.min(1, fraction)) : 0;
  return words.slice(Math.floor(words.length * played)).join(' ');
}


/** A tiny conversational gap between complete thought clips, never within words. */
export function pauseAfterSpeechMs(text) {
  const end = text.trim().replace(/["'”’)]+$/u, '').slice(-1);
  if (end === '?' || end === '!') return 170;
  if (end === '.') return 125;
  if (end === ',' || end === ';' || end === ':') return 80;
  return 0;
}

/** Barge-in must cancel a pause as promptly as it cancels speech. */
export function waitForSpeechPause(milliseconds, { signal } = {}) {
  if (signal?.aborted) return Promise.reject(new DOMException('Cancelled', 'AbortError'));
  if (milliseconds <= 0) return Promise.resolve();
  return new Promise((resolve, reject) => {
    let settled = false;
    const done = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      signal?.removeEventListener('abort', abort);
      if (error) reject(error); else resolve();
    };
    const abort = () => done(new DOMException('Cancelled', 'AbortError'));
    const timer = setTimeout(() => done(), milliseconds);
    signal?.addEventListener('abort', abort, { once: true });
  });
}
