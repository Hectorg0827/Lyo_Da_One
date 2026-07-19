'use client';

/**
 * Tiny synthesized classroom ambiance — no audio assets needed.
 * Everything is generated with WebAudio primitives, deliberately subtle.
 * Browsers require a user gesture before audio; callers only invoke these
 * after the learner has toggled sound on (a click).
 */

let ctx: AudioContext | null = null;

function audioCtx(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  if (!ctx) {
    try {
      ctx = new AudioContext();
    } catch {
      return null;
    }
  }
  if (ctx.state === 'suspended') void ctx.resume();
  return ctx;
}

function tone(freq: number, start: number, duration: number, gainPeak: number, type: OscillatorType = 'sine') {
  const ac = audioCtx();
  if (!ac) return;
  const osc = ac.createOscillator();
  const gain = ac.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0, ac.currentTime + start);
  gain.gain.linearRampToValueAtTime(gainPeak, ac.currentTime + start + 0.015);
  gain.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + start + duration);
  osc.connect(gain).connect(ac.destination);
  osc.start(ac.currentTime + start);
  osc.stop(ac.currentTime + start + duration + 0.05);
}

function noise(start: number, duration: number, gainPeak: number, filterFreq: number) {
  const ac = audioCtx();
  if (!ac) return;
  const length = Math.ceil(ac.sampleRate * duration);
  const buffer = ac.createBuffer(1, length, ac.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i++) data[i] = Math.random() * 2 - 1;
  const src = ac.createBufferSource();
  src.buffer = buffer;
  const filter = ac.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.value = filterFreq;
  const gain = ac.createGain();
  gain.gain.setValueAtTime(0, ac.currentTime + start);
  gain.gain.linearRampToValueAtTime(gainPeak, ac.currentTime + start + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + start + duration);
  src.connect(filter).connect(gain).connect(ac.destination);
  src.start(ac.currentTime + start);
}

export type AmbientSound = 'bell' | 'page_turn' | 'chair_scrape' | 'soft_laugh' | 'chalk' | 'correct' | 'incorrect';

export function playSound(sound: AmbientSound) {
  switch (sound) {
    case 'bell':
      // Two-tone school bell, gentle.
      tone(659, 0, 1.4, 0.08);      // E5
      tone(784, 0.18, 1.6, 0.06);   // G5
      break;
    case 'page_turn':
      noise(0, 0.28, 0.05, 2400);
      break;
    case 'chair_scrape':
      noise(0, 0.22, 0.04, 300);
      break;
    case 'soft_laugh':
      tone(523, 0, 0.1, 0.04);
      tone(587, 0.12, 0.1, 0.035);
      break;
    case 'chalk':
      noise(0, 0.12, 0.025, 5200);
      break;
    case 'correct':
      tone(523, 0, 0.14, 0.06);
      tone(784, 0.12, 0.22, 0.06);
      break;
    case 'incorrect':
      tone(311, 0, 0.25, 0.05);
      break;
  }
}
