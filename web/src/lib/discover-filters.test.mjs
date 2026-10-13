import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeDiscoverFeed, discoverFilterHref, discoverSubjects } from './discover-filters.mjs';
import { readFileSync } from 'node:fs';

test('defaults unknown tabs to For You without fake options', () => {
  assert.equal(normalizeDiscoverFeed(null), 'for_you');
  assert.equal(normalizeDiscoverFeed('following'), 'for_you');
  assert.equal(normalizeDiscoverFeed('saved'), 'saved');
  assert.equal(normalizeDiscoverFeed('latest'), 'latest');
});
test('filter navigation preserves search and removes obsolete deep link', () => {
  assert.equal(discoverFilterHref('q=fractions&clip=123&compose=clip', 'saved'), '/discover?q=fractions&feed=saved');
  assert.equal(discoverFilterHref('q=algebra&feed=saved', 'for_you', 'Math & Science'), '/discover?q=algebra&subject=Math+%26+Science');
  assert.equal(discoverFilterHref('subject=Math', 'for_you'), '/discover');
});
test('only real subjects appear and case variants do not repeat', () => {
  assert.deepEqual(discoverSubjects(
    [{ name: 'Math', count: 12 }, { name: 'science', count: 3 }, { name: 'General', count: 99 }],
    [{ metadata: { subject: 'math' } }, { subject: 'History' }, { subject: '' }],
    ''
  ), ['Math', 'science', 'History']);
  assert.deepEqual(discoverSubjects([], [], 'Chemistry'), ['Chemistry']);
});
test('Discover has one search input, responsive tabs and server-side paging', () => {
  const page = readFileSync(new URL('../app/(main)/discover/page.tsx', import.meta.url), 'utf8');
  const topBar = readFileSync(new URL('../components/layout/TopBar.tsx', import.meta.url), 'utf8');
  assert.ok(!page.includes('placeholder="Search discoveries…"', 'no second search'));
  assert.ok(topBar.includes('placeholder="Search discoveries..."'), 'global search remains');
  assert.ok(page.includes('aria-label="Discover video filters"'));
  assert.ok(page.includes('overflow-x-auto') && page.includes('aria-pressed={active}'));
  assert.ok(page.includes('api.clips.saved(page, 20, requestOptions)'));
  assert.ok(page.includes('api.clips.discover(page, 20, { ...requestOptions, sort: feedMode })'));
});
