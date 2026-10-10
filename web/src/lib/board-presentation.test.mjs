import test from 'node:test';
import assert from 'node:assert/strict';
import { parseBoardDocument, presentationRoleFor, workspaceGroups, classroomIsPaused, workspaceScrollAnchor } from './board-presentation.mjs';

test('accepts tools used by different subjects without interpreting or executing their content', () => {
  const blocks = [
    { kind: 'steps', items: ['Subtract 5', 'Divide by 3', 'x = 4'] },
    { kind: 'bullets', items: ['Claim', 'Evidence', 'Reasoning'] },
    { kind: 'table', headers: ['Term', 'Meaning'], rows: [['Bonjour', 'Hello'], ['Merci', 'Thank you']] },
    { kind: 'code', language: 'python', text: '    return total' },
    { kind: 'text', text: '$E = mc^2$ · 葉は光を吸収する。' },
  ];
  const document = { version: 1, blocks };
  assert.equal(parseBoardDocument(document), document);
  assert.equal(parseBoardDocument(document).blocks[3].text, '    return total');
});

test('rejects unsupported, incomplete, ragged and oversized documents as a whole', () => {
  for (const value of [null, { version: 2, blocks: [{ kind: 'text', text: 'Future format' }] },
    { version: 1, blocks: [] }, { version: 1, blocks: [{ kind: 'script', text: 'execute()' }] },
    { version: 1, blocks: [{ kind: 'table', headers: ['A', 'B'], rows: [['A']] }] },
    { version: 1, blocks: [{ kind: 'code', text: ' ' }] },
    { version: 1, blocks: [{ kind: 'steps', items: ['valid', 42] }] },
    { version: 1, blocks: Array.from({ length: 21 }, () => ({ kind: 'text', text: 'Too many' })) },
  ]) assert.equal(parseBoardDocument(value), null);
});

test('legacy components keep references, recovery and practice distinct', () => {
  assert.equal(presentationRoleFor({ component_id: 'classroom-recovery/notice' }), 'recovery');
  assert.equal(presentationRoleFor({ component_id: 'classroom-recovery/answer/0' }), 'feedback');
  assert.equal(presentationRoleFor({ component_id: 'memory-visual:earlier' }), 'reference');
  assert.equal(presentationRoleFor({ type: 'QuizCard' }), 'practice');
  assert.equal(presentationRoleFor({ type: 'ExampleBlock', presentation_role: 'future' }), 'board');
  assert.equal(presentationRoleFor({ presentation_role: 'details' }), 'details');
});

test('practice stays a task; source details do not become board notes or pauses', () => {
  const elements = [
    { id: 'current', kind: 'summary' }, { id: 'question', kind: 'quiz', presentationRole: 'board' },
    { id: 'reference', kind: 'teaching_visual', presentationRole: 'reference' },
    { id: 'source', kind: 'source' }, { id: 'notice', kind: 'summary', presentationRole: 'recovery' },
  ];
  const groups = workspaceGroups(elements);
  assert.deepEqual(groups.board.map(el => el.id), ['current']);
  assert.deepEqual(groups.practice.map(el => el.id), ['question']);
  assert.deepEqual(groups.reference.map(el => el.id), ['reference']);
  assert.deepEqual(groups.details.map(el => el.id), ['source']);
  assert.equal(classroomIsPaused(elements), true);
  assert.equal(classroomIsPaused(elements.slice(0, 4)), false);
});

test('new teaching tools receive focus while reference additions preserve the current teaching moment', () => {
  const board = [{ id: 'steps', kind: 'summary' }];
  assert.equal(workspaceScrollAnchor(board), 'steps');
  board.push({ id: 'process', kind: 'teaching_visual' });
  assert.equal(workspaceScrollAnchor(board), 'process');
  board.push({ id: 'memory', kind: 'summary', presentationRole: 'reference' });
  board.push({ id: 'source', kind: 'source' });
  assert.equal(workspaceScrollAnchor(board), 'process');
});

test('answering or skipping a card keeps its feedback in place; recovery takes priority', () => {
  const board = [{ id: 'tool', kind: 'teaching_visual' }, { id: 'task', kind: 'quiz' }];
  assert.equal(workspaceScrollAnchor(board), 'task');
  board[1] = { ...board[1], answered: 'a', skipped: true };
  assert.equal(workspaceScrollAnchor(board), 'task');
  board.push({ id: 'notice', kind: 'summary', presentationRole: 'recovery' });
  assert.equal(workspaceScrollAnchor(board), 'notice');
});
