/** Presentation only: these documents never execute code or submit evidence. */
const roles = new Set(['narration', 'board', 'reference', 'practice', 'feedback', 'recovery', 'details']);
const bounded = (value) => typeof value === 'string' && value.trim().length > 0 && value.length <= 1500;
const strings = (value, max) => Array.isArray(value) && value.length > 0 && value.length <= max && value.every(bounded);

export function parseBoardDocument(value) {
  if (!value || value.version !== 1 || !Array.isArray(value.blocks) || !value.blocks.length || value.blocks.length > 20) return null;
  for (const block of value.blocks) {
    if (!block || typeof block !== 'object') return null;
    if (block.kind === 'text' || block.kind === 'code') {
      if (!bounded(block.text) || (block.language != null && (typeof block.language !== 'string' || block.language.length > 40))) return null;
    } else if (block.kind === 'bullets' || block.kind === 'steps') {
      if (!strings(block.items, 20)) return null;
    } else if (block.kind === 'table') {
      if (!strings(block.headers, 8) || !Array.isArray(block.rows) || !block.rows.length || block.rows.length > 20
        || !block.rows.every(row => strings(row, 8) && row.length === block.headers.length)) return null;
    } else return null;
  }
  return value;
}

/** Infer the old wire format too, so either deployment order remains usable. */
export function presentationRoleFor(component) {
  if (roles.has(component.presentation_role)) return component.presentation_role;
  if (component.type === 'QuizCard' || component.type === 'InputField') return 'practice';
  if (component.type === 'TeacherMessage') return 'narration';
  const id = component.component_id || '';
  if (id === 'classroom-recovery/notice') return 'recovery';
  if (id.startsWith('classroom-recovery/')) return 'feedback';
  if (id.includes('board-memory') || id.startsWith('memory-visual:') || component.block_type === 'summary') return 'reference';
  return 'board';
}

export function workspaceGroups(elements) {
  const groups = { board: [], reference: [], practice: [], feedback: [], recovery: [], details: [] };
  for (const element of elements) {
    // An interaction always stays in the learner's area, even on an old server.
    const role = element.kind === 'quiz' || element.kind === 'transfer' ? 'practice'
      : element.kind === 'source' ? 'details' : element.presentationRole || 'board';
    (groups[role] || groups.board).push(element);
  }
  return groups;
}

export function classroomIsPaused(elements) {
  return elements.some(element => element.presentationRole === 'recovery' || element.id === 'classroom-recovery/notice');
}
