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
 * Source with its comments taken out, and only its comments.
 *
 * The first version of this check read the comments too, and failed on the
 * sidebar's own note explaining which names it had replaced. A check that
 * cannot tell code from prose teaches people to delete the prose.
 *
 * The second version stripped whole comment lines with a regex, which left a
 * trailing `// was "Focus"` in place — so renaming a tab and mentioning the
 * old name in a comment on the same line still passed. This walks the source
 * instead, because telling a comment from a string is the one thing a regex
 * cannot do: `"https://..."` is a string, not a comment.
 */
function code(source) {
  let out = '';
  let quote = null; // the delimiter we are inside, or null
  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1];

    if (quote) {
      out += ch;
      if (ch === '\\') {
        out += source[i + 1] ?? '';
        i += 1;
      } else if (ch === quote) {
        quote = null;
      }
      continue;
    }

    if (ch === '"' || ch === "'" || ch === '`') {
      quote = ch;
      out += ch;
      continue;
    }

    if (ch === '/' && next === '/') {
      while (i < source.length && source[i] !== '\n') i += 1;
      out += '\n';
      continue;
    }

    if (ch === '/' && next === '*') {
      i += 2;
      while (i < source.length && !(source[i] === '*' && source[i + 1] === '/')) i += 1;
      i += 1;
      out += ' ';
      continue;
    }

    out += ch;
  }
  return out;
}


/** The label must appear in that platform's own tab bar source. */
function requireLabel(source, where, label) {
  if (!source) return;
  if (!source.includes(`"${label}"`)) {
    failures.push(`${where} does not call it ${JSON.stringify(label)}`);
  }
}

// `code()`, not the raw source: a comment that happens to quote the old name
// would otherwise satisfy the check for a label nobody renders any more.
for (const [key, label] of Object.entries(CROSS_PLATFORM_LABELS)) {
  requireLabel(code(ios), `iOS (${key})`, label);
  requireLabel(code(android), `Android (${key})`, label);
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
//
// The check looks for a `/classroom` test that returns null nearby, rather
// than for one spelling of it. The first version demanded
// `pathname.startsWith('/classroom')` and broke the moment someone switched
// to the stricter `isActiveHref('/classroom', pathname)` — failing a change
// that was an improvement. A check that only recognises the exact line it was
// written against is a check against editing the file.
function stepsAsideForClassroom(source) {
  const body = code(source);
  for (let at = body.indexOf('/classroom'); at !== -1; at = body.indexOf('/classroom', at + 1)) {
    if (/^[^;]{0,120}?return\s+null/.test(body.slice(at))) return true;
  }
  return false;
}

for (const [source, where] of [
  [sidebar, 'The web sidebar'],
  [mobileNav, 'The web phone nav'],
  [topBar, 'The web top bar'],
]) {
  if (!source) continue;
  if (!stepsAsideForClassroom(source)) {
    failures.push(`${where} does not step aside for the classroom`);
  }
}

// ── One icon set, both navs ──────────────────────────────────────────────────
//
// The rail was redrawn and the phone bar was left on stock Lucide, so the two
// navs on one site disagreed about their glyphs the same way they once
// disagreed about their names. Both read `NavIcons` now, and neither pulls a
// tab glyph out of the stock pack. (Lucide is fine elsewhere — the settings
// cog is still one; this is about the tabs.)
const STOCK_TAB_GLYPHS = ['Target', 'Compass', 'Users', 'SquarePlus', 'Home', 'MessageSquare'];

for (const [source, where] of [
  [sidebar, 'The web sidebar'],
  [mobileNav, 'The web phone nav'],
]) {
  if (!source) continue;
  const body = code(source);
  if (!body.includes("from './NavIcons'")) {
    failures.push(`${where} does not use the drawn icon set in NavIcons`);
  }
  const lucide = body.match(/import\s*\{([^}]*)\}\s*from\s*['"]lucide-react['"]/);
  const imported = lucide ? lucide[1].split(',').map((name) => name.trim()) : [];
  for (const glyph of imported.filter((name) => STOCK_TAB_GLYPHS.includes(name))) {
    failures.push(`${where} still uses the stock ${glyph} glyph for a tab`);
  }
}

// The accent that makes the set a family belongs in one place, not copied
// into each nav.
if (code(sidebar).includes("'#ff8c00'") || code(mobileNav).includes("'#ff8c00'")) {
  failures.push('A nav hard-codes the brand accent instead of reading NAV_ACCENT');
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
