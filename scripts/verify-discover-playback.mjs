import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// CI contract: the three platforms must all advance at end-of-media, prewarm
// a neighbour rather than initializing it after the swipe, and recover from
// an unplayable source. Real decoder/network performance is tested on device.
const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const web = read('web/src/app/(main)/discover/page.tsx');
const ios = read('Sources/Views/Main/DiscoverReelView.swift');
const iosFeed = read('Sources/Views/Main/DiscoverView.swift');
const android = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/ClipsScreen.kt');
const gradle = read('android/app/build.gradle.kts');

for (const text of [
  'onEnded={onEnded}',
  'onEnded={() => advanceFrom(i)}',
  'shouldLoad={Math.abs(i - activeIndex) <= 1}',
  'preload="auto"',
  'Retry video',
  'Next clip',
  'api.clips.discover(page)',
]) assert.ok(web.includes(text), 'Web playback contract missing: ' + text);
assert.ok(!/<video[\\s\\S]*?\\bloop\\b/.test(web), 'Web videos may not loop indefinitely');

for (const text of [
  'onFinished: { advanceAfter(item.id) }',
  '.tag(item.id)',
  'TabView(selection:',
]) assert.ok(iosFeed.includes(text), 'iOS feed contract missing: ' + text);
for (const text of [
  'newPlayer.preroll(atRate: 1.0)',
  'if isActive && !showQuiz',
  'onFinished()',
  'loadFailed',
  'Button("Retry")',
]) assert.ok(ios.includes(text), 'iOS playback contract missing: ' + text);
assert.ok(!ios.includes('newPlayer?.seek(to: .zero)'), 'iOS video must advance, not loop');

for (const text of [
  'ExoPlayer.Builder(context).build()',
  'prepare()',
  'index - 1..index + 1',
  'Player.STATE_ENDED',
  'onPlaybackEnded()',
  'pagerState.animateScrollToPage(page + 1)',
  'Retry',
  'Next clip',
  'ApiClient.api.discoverClips(page, 20)',
]) assert.ok(android.includes(text), 'Android playback contract missing: ' + text);
assert.ok(!android.includes('VideoView(context)'), 'Android must not rebuild VideoView on each swipe');
assert.ok(gradle.includes('media3-exoplayer') && gradle.includes('media3-ui'), 'Media3 dependency absent');

console.log('Discover autoplay, prefetch, auto-advance and recovery contracts present on web/iOS/Android.');
