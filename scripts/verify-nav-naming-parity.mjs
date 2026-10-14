// One name per surface, checked against the surfaces themselves.
//
// The web sidebar said "Home" and "LYO Tutor" while iOS, Android and the web's
// own phone nav all said "Focus" and reached the AI through the mascot. Nobody
// noticed because nothing compared them: each platform spelled its tab bar out
// in its own file, and a learner moving between them met two names for one
// screen.
//
// So this reads the real tab bars — Swift, Kotlin and the web's shared nav
// model — and fails when they stop agreeing. It checks names, not icons: the
// platforms draw their own, and should.
//
// Courses and Test Prep are deliberately not checked. A sidebar holds eight
// items where a five-slot tab bar cannot, so they are web-only by capacity,
// and demanding them on mobile would be demanding the wrong thing.

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { CROSS_PLATFORM_LABELS, NAV } from '../web/src/lib/nav-items.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const failures = [];

function read(relative) {
  try {
    return readFileSync(path.join(root, relative), 'utf8');
  } catch {
    failures.push(`${relative} is missing — navigation parity cannot be checked`);
    return '';
  }
}

const ios = read('Sources/Views/MainTabView.swift');
const android = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt');
const sidebar = read('web/src/components/layout/Sidebar.tsx');
const mobileNav = read('web/src/components/layout/MobileNav.tsx');
const topBar = read('web/src/components/layout/TopBar.tsx');

/**
 * Source with its comments taken out.
 *
 * The first version of this check read the comments too, and failed on the
 * sidebar's own note explaining which names it had replaced. A check that
 * cannot tell code from prose teaches people to delete the prose.
 */
function code(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/^\s*\/\/.*$/gm, ' ');
}

/** The label must appear in that platform's own tab bar source. */
function requireLabel(source, where, label) {
  if (!source) return;
  if (!source.includes(`"${label}"`)) {
    failures.push(`${where} does not call it ${JSON.stringify(label)}`);
  }
}

for (const [key, label] of Object.entries(CROSS_PLATFORM_LABELS)) {
  requireLabel(ios, `iOS (${key})`, label);
  requireLabel(android, `Android (${key})`, label);
}

// The web's two navs must read their labels from the shared model rather than
// writing them out again — which is exactly how they drifted apart before.
for (const [source, where] of [[sidebar, 'The web sidebar'], [mobileNav, 'The web phone nav']]) {
  if (!source) continue;
  if (!source.includes('nav-items.mjs')) {
    failures.push(`${where} does not read its labels from nav-items.mjs`);
  }
  const body = code(source);
  for (const stale of ['"Home"', "'Home'", '"LYO Tutor"', "'LYO Tutor'"]) {
    if (body.includes(stale)) {
      failures.push(`${where} still hard-codes ${stale}`);
    }
  }
}

// The names the shared model claims are cross-platform must be the ones it
// actually gives those items.
for (const [key, label] of Object.entries(CROSS_PLATFORM_LABELS)) {
  if (NAV[key]?.label !== label) {
    failures.push(`nav-items.mjs calls ${key} ${JSON.stringify(NAV[key]?.label)}, not ${JSON.stringify(label)}`);
  }
}

// ── The classroom shows no global navigation ─────────────────────────────────
//
// An active lesson is an immersive surface: `MainContent` drops the shell's
// padding and max-width there, and every global nav piece opts out by
// returning null. Nothing checked that, so a rewrite of the sidebar silently
// put a 264px rail back beside the lesson and no test noticed.
for (const [source, where] of [
  [sidebar, 'The web sidebar'],
  [mobileNav, 'The web phone nav'],
  [topBar, 'The web top bar'],
]) {
  if (!source) continue;
  if (!/pathname\.startsWith\(\s*['"]\/classroom['"]\s*\)/.test(code(source))) {
    failures.push(`${where} does not step aside for the classroom`);
  }
}

// The internal build name must never reach a learner.
if (code(sidebar).includes('DA ONE') || code(mobileNav).includes('DA ONE')) {
  failures.push('"DA ONE" is an internal name and is shipping in the navigation');
}

if (failures.length > 0) {
  console.error('Navigation naming parity failed:\n');
  for (const failure of failures) console.error(`  - ${failure}`);
  console.error('\nThe tab bars are in Sources/Views/MainTabView.swift, LyoNavHost.kt');
  console.error('and web/src/lib/nav-items.mjs. Change all of them, or none.');
  process.exit(1);
}

console.log(`Navigation naming parity: ${Object.keys(CROSS_PLATFORM_LABELS).length} names agree across iOS, Android and web.`);
