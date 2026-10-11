/** Own one video element; obsolete play promises cannot change the selected reel. */
export class DiscoverPlaybackController {
  constructor(video, { onBlocked = () => {}, onError = () => {} } = {}) {
    this.video = video;
    this.onBlocked = onBlocked;
    this.onError = onError;
    this.version = 0;
    this.disposed = false;
    this.intent = {};
  }

  update(intent) {
    this.intent = intent;
    const version = ++this.version;
    const shouldPlay = this.canAdvance();
    if (this.disposed || !shouldPlay) {
      this.video.pause();
      return;
    }
    Promise.resolve(this.video.play()).catch((error) => {
      if (this.disposed || version !== this.version || error?.name === 'AbortError') return;
      if (error?.name === 'NotAllowedError') this.onBlocked();
      else this.onError();
    });
  }

  canAdvance() {
    const intent = this.intent;
    return !this.disposed && intent.selected && intent.foreground && !intent.paused && !intent.scrubbing && !intent.failed && !intent.ended;
  }

  seek(seconds) {
    const duration = this.video.duration;
    if (this.disposed || !Number.isFinite(seconds) || !Number.isFinite(duration) || duration <= 0) return;
    this.video.currentTime = Math.max(0, Math.min(duration, seconds));
  }

  dispose() {
    this.disposed = true;
    ++this.version;
    this.video.pause();
  }
}

/** A refreshed feed owns a new cursor; late responses from older feeds are discarded. */
export class DiscoverPageCursor {
  constructor() { this.reset(); }
  reset() { this.generation = (this.generation || 0) + 1; this.nextPage = 2; this.inFlight = null; }
  begin() {
    if (this.inFlight) return null;
    this.inFlight = { page: this.nextPage, generation: this.generation };
    return this.inFlight;
  }
  complete(request) {
    if (request !== this.inFlight || request.generation !== this.generation) return false;
    this.nextPage = request.page + 1;
    this.inFlight = null;
    return true;
  }
  fail(request) { if (request === this.inFlight) this.inFlight = null; }
}

export function mergeClipPage(current, incoming) {
  const seen = new Set(current.map((clip) => String(clip.id)));
  return [...current, ...incoming.filter((clip) => {
    const id = String(clip.id);
    if (seen.has(id)) return false;
    seen.add(id);
    return true;
  })];
}

export function nextClipIndex(ids, selectedId, finishedId) {
  if (selectedId !== finishedId) return null;
  const index = ids.indexOf(finishedId);
  return index >= 0 && index + 1 < ids.length ? index + 1 : null;
}
