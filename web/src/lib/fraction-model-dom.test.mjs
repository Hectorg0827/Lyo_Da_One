import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import Module, { createRequire } from 'node:module';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';

import { parseTeachingVisual } from './teaching-activity.mjs';
import { inferExplicitFractionVisual } from './infer-explicit-fraction-visual.mjs';

const webRoot = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');
const dom = new JSDOM('<!doctype html><body></body>', { url: 'http://localhost' });
Object.assign(globalThis, {
  window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, IS_REACT_ACT_ENVIRONMENT: true,
});

const loaded = new Map();
const mocks = {
  '@/stores/classroom-store': { useClassroomStore: selector => selector({ languageCode: 'en', updateActivity: () => {} }) },
};

/** Load the actual React component, including its real fraction SVG renderer. */
function loadTsx(filename) {
  if (loaded.has(filename)) return loaded.get(filename).exports;
  const mod = new Module(filename);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(webRoot);
  loaded.set(filename, mod);
  mod.require = name => {
    if (mocks[name]) return mocks[name];
    if (name.startsWith('@/') || name.startsWith('./')) {
      const base = name.startsWith('@/') ? path.join(webRoot, 'src', name.slice(2))
        : path.resolve(path.dirname(filename), name);
      if (base.endsWith('.mjs')) return require(base);
      const resolved = ['.tsx', '.ts'].map(ext => base + ext).find(existsSync);
      if (resolved) return loadTsx(resolved);
    }
    return require(name);
  };
  mod._compile(ts.transpileModule(readFileSync(filename, 'utf8'), { compilerOptions: {
    jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, filename);
  return mod.exports;
}

const { TeachingVisualCard } = loadTsx(path.join(webRoot, 'src/components/classroom/TeachingVisualView.tsx'));

async function renderVisual(visual, readOnly = true) {
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  await act(async () => root.render(React.createElement(TeachingVisualCard, { id: 'visual:model', visual, readOnly })));
  return { container, close: async () => {
    await act(async () => root.unmount());
    container.remove();
  } };
}

function fraction(kind, parts, value, description) {
  return parseTeachingVisual({
    kind, parts, value, whole: 1, unit: 'whole',
    title: 'Fraction model', caption: description, description,
  });
}

test('fraction bar is a real accessible SVG with five distinct, exactly three shaded partitions', async () => {
  const visual = fraction('fraction_bar', 5, 3,
    'A single whole rectangle is divided into 5 equal parts, with 3 of those parts shaded blue.');
  assert.ok(visual, 'the bounded teaching-tool contract should accept 3/5');
  const view = await renderVisual(visual);
  try {
    const svg = view.container.querySelector('svg[role="img"]');
    assert.ok(svg, 'an actual SVG image, not diagram prose or an empty placeholder');
    assert.match(svg.getAttribute('aria-label'), /^3\/5 · /);
    const partitions = [...svg.querySelectorAll('rect')];
    assert.equal(partitions.length, 5, 'one partition per denominator unit');
    assert.equal(partitions.filter(part => part.getAttribute('fill') === 'var(--lyo-300)').length, 3,
      'numerator is encoded as three shaded cells, independent of answer options');
    assert.equal(new Set(partitions.map(part => part.getAttribute('x'))).size, 5,
      'partitions are spatially distinct rather than five rectangles stacked on top');
  } finally { await view.close(); }
});

test('fraction bar updates its accessible description when a learner changes the shaded count', async () => {
  const visual = fraction('fraction_bar', 6, 2, 'The original bar has 2 of 6 pieces shaded.');
  const view = await renderVisual(visual, false);
  try {
    const svg = view.container.querySelector('svg[role="img"]');
    assert.match(svg.getAttribute('aria-label'), /2\/6 · 2 of 6 equal sections shaded/);
    await act(async () => view.container.querySelector('button[aria-label="Add one part"]')
      .dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true })));
    assert.match(svg.getAttribute('aria-label'), /3\/6 · 3 of 6 equal sections shaded/);
    assert.equal(svg.querySelectorAll('rect[fill="var(--lyo-300)"]').length, 3);
  } finally { await view.close(); }
});

test('real staging lesson narration becomes a drawable, exact 3/5 SVG through the inference bridge', async () => {
  const narration = 'Look at the fraction bar model. A single whole rectangle is divided into 5 equal parts, with 3 of those parts shaded blue. Which fraction correctly represents the shaded portion of the rectangle? A) 2/5 B) 3/5 C) 5/3 D) 3/8';
  const visual = inferExplicitFractionVisual(narration);
  assert.ok(visual, 'model narration must resolve to a structured drawable visual');
  const view = await renderVisual(visual);
  try {
    const svg = view.container.querySelector('svg[role="img"]');
    assert.ok(svg, 'text inferred from the lesson must become actual rendered SVG geometry');
    assert.match(svg.getAttribute('aria-label'), /^3\/5 · /);
    assert.equal(svg.querySelectorAll('rect').length, 5);
    assert.equal(svg.querySelectorAll('rect[fill="var(--lyo-300)"]').length, 3);
    assert.doesNotMatch(svg.textContent, /2\/5|5\/3|3\/8/, 'distractor answers must not leak into the geometry');
  } finally { await view.close(); }
});

test('fraction pie uses genuine circular segments and not the bar-shaped SVG', async () => {
  const visual = fraction('fraction_pie', 4, 1,
    'A circle is divided into 4 equal sectors and exactly 1 sector is shaded.');
  assert.ok(visual);
  const view = await renderVisual(visual);
  try {
    assert.ok(view.container.querySelector('svg'), 'the pie must exist as vector geometry');
    assert.equal(view.container.querySelectorAll('path[role="button"]').length, 4);
    assert.equal(view.container.querySelectorAll('path[aria-pressed="true"]').length, 1);
    assert.equal(view.container.querySelectorAll('svg[viewBox="0 0 600 64"] rect').length, 0,
      'pie should never silently fall back to a rectangle strip');
  } finally { await view.close(); }
});

test('impossible counts are rejected upstream instead of rendering a fabricated fraction diagram', async () => {
  for (const [parts, value] of [[5, 7], [5, -1], [0, 0], [21, 2], [2.5, 1], [5, NaN]]) {
    assert.equal(fraction('fraction_bar', parts, value, 'Fraction model'), null,
      `${String(value)}/${String(parts)} must not enter the SVG renderer`);
  }
});
