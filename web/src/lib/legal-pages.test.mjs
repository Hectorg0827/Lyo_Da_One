import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const PAGES = ['privacy', 'terms', 'support'];

test('the legal pages are public (outside the signed-in group) and marked as drafts', () => {
  for (const page of PAGES) {
    assert.ok(existsSync(new URL(`../app/${page}/page.tsx`, import.meta.url)), `/${page} exists`);
    assert.ok(!existsSync(new URL(`../app/(main)/${page}/page.tsx`, import.meta.url)), `/${page} is not behind sign-in`);
    const source = read(`../app/${page}/page.tsx`);
    assert.ok(source.trimStart().startsWith('/*') && source.slice(0, 400).includes('DRAFT'), `/${page} starts with the draft notice`);
    assert.ok(!source.includes("'use client'"), `/${page} renders on the server, readable without JavaScript`);
  }
  assert.ok(read('../components/legal/LegalPage.tsx').includes("SUPPORT_EMAIL = 'support@lyoai.app'"));
});

test('the privacy policy covers what LYO actually does with data', () => {
  const privacy = read('../app/privacy/page.tsx');
  for (const topic of ['AI providers', 'Sign in with Google or Apple', 'Location', 'Push notification', 'Analytics and crash reports', 'Messages', 'Deleting your account', 'Children']) {
    assert.ok(privacy.includes(topic), `privacy mentions ${topic}`);
  }
});

test('the sitemap lists the legal pages', () => {
  const sitemap = read('../app/sitemap.ts');
  for (const page of PAGES) assert.ok(sitemap.includes(`https://www.lyoai.app/${page}`), page);
});

test('login, signup and Settings link to our own legal pages, not the old lyo.app domain', () => {
  const login = read('../app/auth/login/page.tsx');
  const signup = read('../app/auth/signup/page.tsx');
  const settings = read('../app/(main)/settings/page.tsx');
  for (const source of [login, signup, settings]) {
    assert.ok(source.includes('href="/privacy"') && source.includes('href="/terms"'));
    assert.ok(!/[/@]lyo\.app/.test(source), 'no links to lyo.app');
  }
  assert.ok(login.includes('href="/support"') && settings.includes('href="/support"'));
  assert.ok(!/[/@]lyo\.app/.test(read('../app/not-found.tsx')));
});
