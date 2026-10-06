import { readFileSync } from 'node:fs';

// A creator's totals are the figures they read to decide whether any of this
// is worth their time, so the rule underneath them is a contract: a count the
// backend did not send is not a zero. Sum the missing ones as zero on one
// platform and that platform quietly understates someone's reach while
// looking exactly like the others. This fails when they drift.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const swift = read('Sources/Services/CreatorStats.swift');
const web = read('web/src/lib/creator-stats.mjs');
const kotlin = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/CreatorStats.kt');
const platforms = [['iOS', swift], ['web', web], ['Android', kotlin]];

// Every total says how much of the library it covers, so a partial one is
// never passed off as whole.
for (const [label, source] of platforms) {
  for (const symbol of ['reporting', 'isReported', 'isComplete', 'coverageNote']) {
    if (!source.includes(symbol)) {
      throw new Error(`${label} creator stats: missing ${symbol}`);
    }
  }
  if (!source.includes('from ')) {
    throw new Error(`${label} creator stats: missing the coverage qualifier`);
  }
}

// All four metrics, in the same order, on all three.
const ORDER = ['views', 'likes', 'comments', 'shares'];
for (const [label, source] of platforms) {
  const seen = ORDER.filter((metric) => {
    const pattern = new RegExp(`\\b(${metric}|${metric[0].toUpperCase()}${metric.slice(1)})\\b`);
    return pattern.test(source);
  });
  if (seen.length !== ORDER.length || seen.join() !== ORDER.join()) {
    throw new Error(`${label} creator stats: metrics are ${seen.join(', ')}, expected ${ORDER.join(', ')}`);
  }
}

// The counts a clip carries have to stay optional at the source, or the rule
// above cannot tell a missing figure from a real zero however careful it is.
const clipModel = read('Sources/Models/ClipModels.swift');
for (const field of ['viewCount', 'likeCount', 'commentCount', 'shareCount']) {
  if (!new RegExp(`var ${field}: Int\\?`).test(clipModel)) {
    throw new Error(`iOS Clip.${field} must be optional: nil is how "not reported" is carried`);
  }
}
const clipDto = read('android/app/src/main/java/com/lyo/app/data/api/Dtos.kt');
for (const field of ['viewCount', 'likeCount', 'commentCount', 'shareCount']) {
  if (!new RegExp(`val ${field}: Int\\? `).test(clipDto)) {
    throw new Error(`Android ClipDto.${field} must be nullable: null is how "not reported" is carried`);
  }
}

console.log(
  'Creator totals carry their coverage on iOS, web and Android, and clip counts stay optional at the source.',
);
