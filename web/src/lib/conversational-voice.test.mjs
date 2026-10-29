import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const compiled = ts.transpileModule(readFileSync(new URL('./conversational-voice.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const module = { exports: {} };
new Function('exports', 'module', compiled)(module.exports, module);
const { voiceEndOfTurnDelayMs } = module.exports;

test('unfinished thoughts and ellipses allow a two-second thinking pause', () => {
  for (const text of ['I think the reason is...', 'I think…', 'I wanted to', 'Creo que es porque']) {
    assert.equal(voiceEndOfTurnDelayMs(text), 2200);
  }
});

test('complete replies still get fast turn-taking', () => {
  assert.equal(voiceEndOfTurnDelayMs('yes'), 420);
  assert.equal(voiceEndOfTurnDelayMs('What is gravity?'), 430);
  assert.equal(voiceEndOfTurnDelayMs('why'), 900);
});
