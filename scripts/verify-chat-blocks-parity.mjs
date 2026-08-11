#!/usr/bin/env node
/**
 * Chat structured-content contract.
 *
 * verify-chat-continuity.mjs pins transport, history, and layout — it would
 * pass green with all three clients rendering completely different content.
 * This pins the content itself: the block vocabulary, and the rule that a
 * check's correctness is decided by the server.
 *
 * The strongest assertions here are the FORBIDDEN ones. A client that starts
 * comparing a selection against `correct_index` has quietly reintroduced the
 * bug this whole feature exists to remove (chat praising a wrong answer), and
 * no type checker or build will catch that.
 */
import fs from 'node:fs';
import {
  CHAT_BLOCK_TYPES,
  LESSON_SECTION_KINDS,
  CALLOUT_VARIANTS,
  CHAT_CHECK_ENDPOINT,
  CHECK_REQUEST_FIELDS,
  CHAT_MASTERY_SOURCE,
} from '../web/src/lib/chat-contract.mjs';

const contracts = [
  {
    name: 'Web block vocabulary',
    path: 'web/src/types/index.ts',
    // Every wire type must be representable, or blocks get dropped silently.
    needles: [...CHAT_BLOCK_TYPES.map((t) => `'${t}'`), 'ChatBlock', 'CheckAnswerResult'],
  },
  {
    name: 'Web consumes the smart_blocks event',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      "chunk.type === 'smart_blocks'",
      // Server-suggested follow-ups were dropped entirely before.
      "chunk.type === 'actions'",
      // Blocks count as content, or a blocks-only turn is treated as empty
      // and wiped by the recovery path.
      'receivedContent',
      // Reload must restore structure rather than flattening to text.
      'message.blocks',
      'answerCheck',
    ],
  },
  {
    name: 'Web renders each lesson beat distinctly',
    path: 'web/src/components/chat/blocks/BlockRenderer.tsx',
    needles: ["case 'quiz'", "case 'dataViz'", "'callout'", 'CheckBlock'],
  },
  {
    name: 'Web check is graded by the server',
    path: 'web/src/components/chat/blocks/CheckBlock.tsx',
    needles: [
      'answerCheck',
      // The verdict is read off the stored server result, not computed.
      'message.checkResults',
      'bailed_out',
      'misconception',
    ],
    forbidden: [
      // Any of these means the client is deciding correctness itself, from the
      // answer key on the wire, rather than from the server's verdict.
      'content.correct_index',
      'content?.correct_index',
    ],
  },
  {
    name: 'Web check request carries no answer key',
    path: 'web/src/lib/api.ts',
    needles: [CHAT_CHECK_ENDPOINT, ...CHECK_REQUEST_FIELDS.map((f) => `${f}:`)],
    forbidden: ['correct_index:'],
  },
  {
    name: 'Backend block vocabulary',
    path: '../lyobackendjune/lyo_app/ai/schemas/smart_block.py',
    optional: true, // backend lives in a sibling repo; skip when absent
    needles: ['def callout', 'def table', 'reveals', 'bailout_index'],
  },
  {
    name: 'Backend grades checks and records mastery from chat',
    path: '../lyobackendjune/lyo_app/api/v1/stream_lyo2.py',
    optional: true,
    needles: [
      '/chat/check',
      '_grade_check_block',
      'trace_knowledge',
      'record_misconception',
      // Fail closed on a malformed block.
      'correct_index >= 0',
    ],
  },
  {
    name: 'Backend lesson beats match the shared contract',
    path: '../lyobackendjune/lyo_app/ai/lesson_composer.py',
    optional: true,
    needles: [...LESSON_SECTION_KINDS.map((k) => `${k} = "${k}"`)],
  },
];

const failures = [];
const checked = [];

for (const contract of contracts) {
  if (!fs.existsSync(contract.path)) {
    if (contract.optional) continue;
    failures.push(`${contract.name}: missing file ${contract.path}`);
    continue;
  }
  checked.push(contract.name);
  const source = fs.readFileSync(contract.path, 'utf8');
  for (const needle of contract.needles ?? []) {
    if (!source.includes(needle)) failures.push(`${contract.name}: missing ${needle}`);
  }
  for (const forbidden of contract.forbidden ?? []) {
    if (source.includes(forbidden)) {
      failures.push(`${contract.name}: must not contain ${forbidden}`);
    }
  }
}

// The callout variants the renderer styles must match the ones the backend
// is allowed to emit, or a trap renders unstyled as ordinary prose.
const renderer = fs.readFileSync('web/src/components/chat/blocks/BlockRenderer.tsx', 'utf8');
for (const variant of CALLOUT_VARIANTS) {
  if (!renderer.includes(`'${variant}'`)) {
    failures.push(`Callout variants: renderer does not handle '${variant}'`);
  }
}

// Mastery written from chat must be attributable, or chat's contribution is
// indistinguishable from the classroom's.
const backendCheck = '../lyobackendjune/lyo_app/personalization/models.py';
if (fs.existsSync(backendCheck)) {
  const models = fs.readFileSync(backendCheck, 'utf8');
  if (!models.includes('source_of_mastery')) {
    failures.push(`Mastery attribution: source_of_mastery missing (expected '${CHAT_MASTERY_SOURCE}')`);
  }
}

if (failures.length > 0) {
  console.error('Chat structured-content contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(
  `Chat blocks contract: ${checked.length} surfaces share one block vocabulary, ` +
    'lesson beats render distinctly, and check correctness is decided server-side ' +
    '(no client compares against correct_index).'
);
