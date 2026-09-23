import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { classifyChatLink } from './chat-links.mjs';

// ─── An app link stays in the app ────────────────────────────────────────────

test('a link to our own domain becomes a route, not a page load', () => {
  // The Test Prep handoff used to write https://lyoai.app/test-prep. Followed
  // as an absolute URL that is a full reload: the learner leaves the running
  // app and loses the conversation they are in.
  assert.deepEqual(
    classifyChatLink('https://lyoai.app/test-prep'),
    { kind: 'internal', href: '/test-prep' },
  );
  assert.deepEqual(
    classifyChatLink('https://www.lyoai.app/test-prep?from=chat#today'),
    { kind: 'internal', href: '/test-prep?from=chat#today' },
  );
});

test('a path is already a route', () => {
  assert.deepEqual(classifyChatLink('/test-prep'), { kind: 'internal', href: '/test-prep' });
});

test('a link somewhere else is external and says so', () => {
  assert.deepEqual(
    classifyChatLink('https://example.com/x'),
    { kind: 'external', href: 'https://example.com/x' },
  );
});

// ─── A model-produced href is untrusted ──────────────────────────────────────

test('a script URL never becomes an anchor', () => {
  // Chat text is generated. An anchor carrying javascript: is execution one
  // click away, so it is not rendered as a link at all.
  assert.equal(classifyChatLink('javascript:alert(1)').kind, 'unsafe');
  assert.equal(classifyChatLink('JavaScript:alert(1)').kind, 'unsafe');
  assert.equal(classifyChatLink('data:text/html,<script>').kind, 'unsafe');
});

test('a protocol-relative URL is not mistaken for a path', () => {
  // `//evil.com` starts with a slash and is an external origin, which is the
  // one case where "looks like a path" is wrong.
  assert.equal(classifyChatLink('//evil.com').kind, 'unsafe');
});

test('nothing is not a link', () => {
  for (const value of ['', '   ', null, undefined]) {
    assert.equal(classifyChatLink(value).kind, 'unsafe');
  }
});

// ─── The renderer that was missing ───────────────────────────────────────────

test('chat markdown renders anchors at all', () => {
  // There was no `a` component, so every link Lyo ever sent fell through to
  // an unstyled default anchor that inherited the bubble's text colour. The
  // link was in the message and invisible.
  const source = readFileSync(new URL('../components/chat/markdown-config.tsx', import.meta.url), 'utf8');
  assert.match(source, /\ba:\s*ChatLink\b/);
  assert.match(source, /classifyChatLink/);
  // Internal links go through the router; external ones cannot reach opener.
  assert.match(source, /next\/link/);
  assert.match(source, /rel="noopener noreferrer"/);
});

test('the Test Prep card reads the server handoff, never the reply text', () => {
  const source = readFileSync(
    new URL('../components/chat/TestPrepReadyCard.tsx', import.meta.url), 'utf8');
  // Start now goes through the same entry helper the Test Prep page uses, so
  // a session opened from Chat teaches what it would have taught from there.
  assert.match(source, /sessionEntryHref/);
  // It must not sniff the message for a phrase.
  assert.doesNotMatch(source, /includes\(['"]Test Prep|indexOf\(['"]/);
  // Start now only exists when the server named a session.
  assert.match(source, /handoff\.next_session \? sessionEntryHref/);
});
