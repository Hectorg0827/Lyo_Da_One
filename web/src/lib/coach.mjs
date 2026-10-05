/**
 * Lyo Coach presentation decisions.
 *
 * The server owns pedagogy and evidence. The client only decides how to say
 * those decisions and where an approved mission action opens.
 */
import {
  classroomEntryHref,
  defaultObjective,
  practiceEntryHref,
  reviewEntryHref,
} from './entry-contract.mjs';

export function readinessLabel(readiness) {
  switch (readiness?.readiness_level) {
    case 'ready': return 'Ready';
    case 'getting_there': return 'Getting there';
    case 'not_ready': return 'Not ready yet';
    default: return 'Readiness unavailable';
  }
}

export function readinessExplanation(readiness) {
  if (!readiness) return 'Lyo could not read your evidence just now.';
  if (readiness.total_skills <= 0) return 'Add the skills or topics for this goal to measure readiness.';
  if (readiness.assessed_skills <= 0) return 'No skill has been assessed yet. Start the first check below.';
  if (readiness.critical_gaps > 0) {
    return `${readiness.critical_gaps} ${readiness.critical_gaps === 1 ? 'skill still needs' : 'skills still need'} application evidence.`;
  }
  return 'Your required skills have strong evidence. Keep retrieval light and current.';
}

export function actionLabel(action) {
  return ({
    diagnose: 'Quick check',
    remediate: 'Repair the gap',
    guide: 'Guided practice',
    check_application: 'Apply it',
    check_transfer: 'Challenge',
    review: 'Retrieve it',
    advance: 'Light review',
  })[action] ?? 'Study';
}

/**
 * Route every Coach mission through the existing Classroom entry contract.
 * There is deliberately no client-side "quiz AI": when the Coach asks for an
 * assessment, the same Classroom/Teaching Policy runtime records the evidence.
 */
export function missionEntryHref(item) {
  if (!item?.title) return null;
  if (item.action === 'review' || item.target_evidence_type === 'retention') {
    return reviewEntryHref(item.title, item.concept_id);
  }
  if (item.action === 'diagnose' || item.action === 'check_application' || item.action === 'check_transfer') {
    return practiceEntryHref(item.title);
  }
  return classroomEntryHref({
    topic: item.title,
    objective: defaultObjective(item.title),
  });
}
