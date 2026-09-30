import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../stores/classroom-store.ts', import.meta.url), 'utf8');

test('classroom voice starts synthesis before queued narration reaches the player', () => {
  assert.match(source, /const prefetchedSpeech = new Map<string, Promise<Blob \| null>>\(\)/);
  assert.match(
    source,
    /turns\s*\.filter\(\(turn\) => turn\.type === 'speech'[\s\S]*?\.forEach\(\(turn\) => prefetchSpeechLine/,
  );
});

test('narration consumes the prefetched voice blob instead of starting a duplicate request', () => {
  assert.match(source, /const prefetched = prefetchedSpeech\.get\(key\)/);
  assert.match(source, /prefetched\s*\? await prefetched\s*:\s*await requestSpeechBlob/);
  assert.match(source, /prefetchedSpeech\.delete\(key\)/);
});

test('voice prefetch stays bounded and preserves the device-voice fallback', () => {
  assert.match(source, /while \(prefetchedSpeech\.size > 6\)/);
  assert.match(source, /speakWithLocalizedDeviceVoice\(text, language, generation, onDone\)/);
});
