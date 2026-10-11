/** A diagram's saves outlive its view and remain serialized after reopening. */
export function createVisualSaveQueue(save, delayMs = 300) {
  const entries = new Map();
  const listeners = new Map();
  const keyFor = update => JSON.stringify([update.conversationId, update.messageId, update.blockId]);
  const emit = key => { for (const listener of listeners.get(key) ?? []) listener(); };

  async function flush(key) {
    const entry = entries.get(key);
    if (!entry || entry.busy || !entry.pending) return;
    clearTimeout(entry.timer);
    entry.timer = null;
    entry.busy = true;
    try {
      while (entry.pending) {
        const update = entry.pending;
        entry.pending = null;
        let saved = false;
        try { saved = await save(update); } catch { /* Retain the edit for retry. */ }
        if (!saved) {
          entry.pending ??= update;
          entry.snapshot = { values: entry.pending.values, failed: true };
          emit(key);
          return;
        }
      }
      entries.delete(key);
      emit(key);
    } finally {
      entry.busy = false;
    }
  }

  return {
    keyFor,
    enqueue(update) {
      const key = keyFor(update);
      let entry = entries.get(key);
      if (!entry) {
        entry = { pending: null, busy: false, timer: null, snapshot: null };
        entries.set(key, entry);
      }
      entry.pending = { ...update, values: { ...update.values } };
      entry.snapshot = { values: entry.pending.values, failed: false };
      emit(key);
      clearTimeout(entry.timer);
      if (!entry.busy) entry.timer = setTimeout(() => { void flush(key); }, delayMs);
    },
    flush,
    getSnapshot: key => entries.get(key)?.snapshot ?? null,
    subscribe(key, listener) {
      if (!listeners.has(key)) listeners.set(key, new Set());
      listeners.get(key).add(listener);
      return () => {
        const subscribers = listeners.get(key);
        subscribers?.delete(listener);
        if (!subscribers?.size) listeners.delete(key);
      };
    },
  };
}
