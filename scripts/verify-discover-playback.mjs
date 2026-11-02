import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// CI contract: the three platforms must all advance at end-of-media, prewarm
// a neighbour rather than initializing it after the swipe, and recover from
// an unplayable source. Real decoder/network performance is tested on device.
const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const web = read('web/src/app/(main)/discover/page.tsx');
const ios = read('Sources/Views/Main/DiscoverReelView.swift');
const iosPlayer = read('Sources/Services/DiscoverPlayerController.swift');
const iosFeed = read('Sources/Views/Main/DiscoverView.swift');
const android = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/ClipsScreen.kt');
const gradle = read('android/app/build.gradle.kts');
const androidApi = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
const webTopBar = read('web/src/components/layout/TopBar.tsx');

for (const text of [
  'if (controllerRef.current?.canAdvance()) onEnded()',
  'onEnded={() => advanceFrom(i)}',
  'shouldLoad={Math.abs(i - activeIndex) <= 1}',
  'preload="auto"',
  'Retry video',
  'Next clip',
  'api.clips.discover(page, 20, { ...requestOptions, sort: feedMode })',
  'aria-label="Seek video"',
  'Unmute video',
  'visibilitychange',
]) assert.ok(web.includes(text), 'Web playback contract missing: ' + text);
assert.ok(!/<video[^>]*\bloop\b/.test(web), 'Web videos may not loop indefinitely');

for (const text of [
  'onFinished: { advanceAfter(item.id) }',
  '.tag(item.id)',
  'TabView(selection:',
]) assert.ok(iosFeed.includes(text), 'iOS feed contract missing: ' + text);
for (const text of [
  'onFinished()',
  'loadFailed',
  'Button("Retry")',
  '.accessibilityLabel("Seek video")',
  '.onChange(of: scenePhase)',
]) assert.ok(ios.includes(text), 'iOS playback contract missing: ' + text);
for (const text of ['newPlayer.preroll(atRate: 1.0)', 'player === observedPlayer', 'state.shouldPlay', 'seekGeneration', 'removeTimeObserver']) {
  assert.ok(iosPlayer.includes(text), 'iOS player ownership contract missing: ' + text);
}
assert.ok(!ios.includes('newPlayer?.seek(to: .zero)'), 'iOS video must advance, not loop');

for (const text of [
  'ExoPlayer.Builder(context).build()',
  'prepare()',
  'index - 1..index + 1',
  'Player.STATE_ENDED',
  'endedCallback()',
  'pagerState.animateScrollToPage(page + 1)',
  'Retry',
  'Next clip',
  'DiscoverSafety.pagesToFetch(page, removedSinceLoad, 20)',
  'discoverPage(number, feedMode, selectedSubject',
  'LifecycleEventObserver',
  'Slider(',
  'DiscoverPlaybackIntent(',
  'generation != feedGeneration',
]) assert.ok(android.includes(text), 'Android playback contract missing: ' + text);
assert.ok(!android.includes('VideoView(context)'), 'Android must not rebuild VideoView on each swipe');

// Discover chrome parity: the brand and search are anchored outside the
// scrolling filter rail, and mode/subject/search selections hit the server.
// The old Android stock floating + must not obstruct reel actions.
for (const marker of [
  'R.drawable.lyo_discover_logo',
  'Search Discover videos',
  'DiscoverFeed.SAVED',
  'selectedSubject',
  'submittedQuery',
  'CreateVideoPill(',
]) assert.ok(android.includes(marker), 'Android Discover chrome missing: ' + marker);
assert.ok(!android.includes('FloatingActionButton('), 'Android Discover must not render stock floating +');
for (const marker of ['@Query("sort") sort', '@Query("q") query', 'discoverClipFilters()', 'savedClips(']) {
  assert.ok(androidApi.includes(marker), 'Android Discover server filters missing: ' + marker);
}
assert.ok(web.includes('/brand/lyo-logo.png') && web.includes('Search Discover videos'), 'Web Discover fixed brand/search missing');
assert.ok(webTopBar.includes("pathname.startsWith('/discover')"), 'Web Discover should not have duplicate global header');
assert.ok(gradle.includes('media3-exoplayer') && gradle.includes('media3-ui'), 'Media3 dependency absent');

console.log('Discover autoplay, bounded prefetch, seek controls, lifecycle and recovery contracts present on web/iOS/Android; decoder performance still requires devices.');
