import test from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

test('chemistry question inline formulas render as KaTeX, not literal dollar notation', () => {
  const content = String.raw`A sample contains carbon dioxide ($CO_2$). The atomic masses are ($12.01\text{ g/mol}$) and ($16.00\text{ g/mol}$).`;
  const html = renderToStaticMarkup(React.createElement(ReactMarkdown, {
    remarkPlugins: [remarkGfm, remarkMath],
    rehypePlugins: [rehypeKatex],
  }, content));
  assert.match(html, /class="katex"/);
  assert.doesNotMatch(html, /\$CO_2\$/);
  assert.doesNotMatch(html, /\\text\{/);
});

test('ordinary answer choices remain readable text', () => {
  const html = renderToStaticMarkup(React.createElement(ReactMarkdown, {
    remarkPlugins: [remarkGfm, remarkMath],
    rehypePlugins: [rehypeKatex],
  }, '44.01 g/mol'));
  assert.match(html, /44\.01 g\/mol/);
});
