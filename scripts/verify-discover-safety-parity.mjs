import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { REPORT_REASONS, blockOutcome, reportOutcome } from '../web/src/lib/discover-report.mjs';

// Report and Block are what keep Discover safe, and the app stores ask for
// both. A learner has to get the same reasons, the same confirmation and the
// same outcome on the web, iPhone and Android, against the same API. This
// fails when one platform drifts from the web rules in discover-report.mjs.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const swift = read('Sources/Services/DiscoverSafety.swift');
const kotlin = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/DiscoverSafety.kt');

// The same reasons, in the same order, with the same labels.
const webReasons = REPORT_REASONS.map(({ value, label }) => `${value}=${label}`);
const swiftCases = Object.fromEntries([...swift.matchAll(/case (\w+) = "(\w+)"/g)].map((m) => [m[1], m[2]]));
const swiftLabels = Object.fromEntries([...swift.matchAll(/case \.(\w+): return "([^"]+)"/g)].map((m) => [m[1], m[2]]));
const swiftReasons = Object.entries(swiftCases).map(([name, value]) => `${value}=${swiftLabels[name]}`);
const kotlinReasons = [...kotlin.matchAll(/Reason\("(\w+)", "([^"]+)"\)/g)].map((m) => `${m[1]}=${m[2]}`);
assert.deepEqual(swiftReasons, webReasons, 'iOS report reasons differ from the web');
assert.deepEqual(kotlinReasons, webReasons, 'Android report reasons differ from the web');
assert.ok(swift.includes('static let noteLimit = 1000') && kotlin.includes('const val NOTE_LIMIT = 1000'),
  'the note limit is 1000 everywhere');

// The same messages for each outcome.
const messages = [
  reportOutcome(201).message, reportOutcome(404).message, reportOutcome(500).message,
  blockOutcome(404, 'x').message, blockOutcome(500, 'x').message,
];
const blocked = blockOutcome(201, 'NAME').message;
for (const [label, source, named] of [
  ['iOS', swift, blocked.replace('NAME', '\\(name)')],
  ['Android', kotlin, blocked.replace('NAME', '$name')],
]) {
  for (const message of [...messages, named]) {
    assert.ok(source.includes(`"${message}"`), `${label} is missing the message ${JSON.stringify(message)}`);
  }
  // Block is never offered on a library video or the learner's own.
  assert.ok(source.includes('isLibrary'), `${label} does not keep Block off library videos`);
}

// Every platform asks before blocking, with the same words, and lists the
// blocked accounts with Unblock.
const confirm = "You won't see each other's videos or comments in Discover. You can unblock them in Settings.";
const sheets = [
  ['web', read('web/src/components/clips/ReportClipSheet.tsx').replace(/&apos;/g, "'").replace(/\s+/g, ' ')],
  ['iOS', read('Sources/Views/Main/ReelComponents/ReportClipSheet.swift')],
  ['Android', read('android/app/src/main/java/com/lyo/app/ui/screens/clips/ReportClipSheet.kt')],
];
for (const [label, source] of sheets) {
  assert.ok(source.includes(confirm), `${label} report sheet does not confirm a block in the shared words`);
}
for (const [label, path] of [
  ['web', 'web/src/components/settings/BlockedAccounts.tsx'],
  ['iOS', 'Sources/Views/BlockedAccountsView.swift'],
  ['Android', 'android/app/src/main/java/com/lyo/app/ui/screens/settings/BlockedAccountsSection.kt'],
]) {
  assert.ok(read(path).includes('Unblock'), `${label} has no way to unblock`);
}

// The same API on every platform.
const web = read('web/src/lib/api.ts');
const ios = read('Sources/Services/LyoAPIClient.swift');
const android = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
assert.ok(web.includes('`/api/v1/clips/${clipId}/report`') && web.includes("'/api/v1/community/blocks'"), 'web API paths');
assert.ok(ios.includes('"/api/v1/clips/\\(clipId)/report"') && ios.includes('"/api/v1/community/blocks"'), 'iOS API paths');
assert.ok(android.includes('"api/v1/clips/{clipId}/report"') && android.includes('"api/v1/community/blocks"'), 'Android API paths');

console.log('Discover Report and Block offer the same reasons, confirmation, outcomes and API on web, iOS and Android.');
