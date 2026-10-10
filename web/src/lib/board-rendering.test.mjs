import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';

// Exercise the actual JSX renderer and markdown libraries, without a browser mock.
const source = readFileSync(new URL('../components/classroom/BoardDocumentView.tsx', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext, jsx: ts.JsxEmit.ReactJSX } }).outputText
  .replace(/from (['"])([^'"]+)\1/g, (_, quote, name) => `from ${JSON.stringify(import.meta.resolve(name))}`);
const { BoardDocumentView } = await import(`data:text/javascript;base64,${Buffer.from(compiled).toString('base64')}`);

test('renders worked steps, authored code and an accessible rectangular table', () => {
  const html = renderToStaticMarkup(React.createElement(BoardDocumentView, { document: { version: 1, blocks: [
    { kind: 'steps', items: ['Observe the input', 'Explain the transformation'] },
    { kind: 'code', language: 'python', text: '    return total' },
    { kind: 'table', headers: ['Term', 'Meaning'], rows: [['Bonjour', 'Hello']] },
  ] } }));
  assert.match(html, /<ol/);
  assert.match(html, /<code>    return total<\/code>/);
  assert.match(html, /<th scope="col"[^>]*>Term<\/th>/);
  assert.match(html, /aria-label="Lesson table"/);
  assert.match(html, /<td[^>]*>Bonjour<\/td>/);
});

test('legacy markdown remains readable and never enables raw HTML or executable links', () => {
  const html = renderToStaticMarkup(React.createElement(BoardDocumentView, { fallback: '# Observation\n\n- Evidence\n- Reasoning\n\n<script>alert(1)</script>\n\n[unsafe](javascript:alert(1))' }));
  assert.match(html, /<h1>Observation<\/h1>/);
  assert.match(html, /<ul>/);
  assert.doesNotMatch(html, /<script>|href="javascript:/);
  assert.match(html, /Evidence/);
});
