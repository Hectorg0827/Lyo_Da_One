/**
 * Lyo's goal-first front door: one input, three existing engines.
 *
 * This is intentionally a deterministic, minimal client-side entry contract,
 * NOT a second LLM router. When uncertain, preserve the full request in Chat:
 * the canonical server InteractionContract is the final authority.
 *
 * Direct Chat/Classroom/Test Prep shortcuts bypass this inference entirely.
 */
import { classroomEntryHref, testPrepEntryHref } from './entry-contract.mjs';

const EXAM = /\b(?:i have (?:a|an|my) (?:[a-z]+ ){0,5}(?:test|exam)|(?:test|exam|midterm|final|certification) (?:on|in|next|tomorrow|this|coming)|(?:study|prepare|revise|practice) for (?:a|an|my|the) (?:[a-z]+ ){0,5}(?:test|exam)|tengo (?:un )?examen|preparar(?:me)? para (?:un |el )?examen)\b/i;
const COACH = /\b(?:what should i (?:study|work on|learn|review)|(?:what(?:'s| is) my|give me (?:my|a)) (?:mission|study plan)|how ready am i|(?:i have|i've got) \d+ minutes? (?:to study|for studying)|qu[eé] (?:debo|deber[ií]a) estudiar)\b/i;
const TEACH = /\b(?:teach me|walk me through|start (?:a |my )?(?:lesson|course)|(?:make|create|build) (?:me )?(?:a )?course|i want to learn|i'd like to learn|help me learn|learn (?:to|how to)|ens[eé][nñ]ame|quiero aprender|ay[uú]dame a aprender)\b/i;
const QUESTION = /^(?:what|who|when|where|why|how|which|is |are |can |could |should |do |does |did |will |would |tell me|explain|summari[sz]e|compare|analy[sz]e|find|search|show me|translate|write|draft|help me (?:with|fix)|qu[eé]|qui[eé]n|cu[aá]ndo|d[oó]nde|por qu[eé]|c[oó]mo|explica|resume|traduce)\b/i;

function chatHref(request) {
  return '/chat?prompt=' + encodeURIComponent(request);
}

/**
 * Explicit learner goal overrides inferred intent. Unclear requests go to
 * Chat, not an irreversible course generation or graded assessment.
 */
export function routeLearningRequest(input, options = {}) {
  const request = typeof input === 'string' ? input.trim() : '';
  if (!request) return null;
  const goal = options.goal || '';

  if (goal === 'exam' || EXAM.test(request)) {
    const prompt = EXAM.test(request) ? request : 'I have a test. Help me prepare for ' + request;
    return { surface: 'test_prep_intake', href: chatHref(prompt), reason: 'exam_intent' };
  }
  if (COACH.test(request)) {
    return { surface: 'coach_chat', href: chatHref(request), reason: 'coach_intent' };
  }
  const explicitTeaching = TEACH.test(request);
  if (explicitTeaching || (!QUESTION.test(request) && goal !== 'chat')) {
    const href = classroomEntryHref({
      topic: request,
      recordScope: 'unit',
      level: options.level,
      minutes: options.minutes,
      language: options.language,
      objective: options.objective,
    });
    return href ? { surface: 'classroom', href, reason: explicitTeaching ? 'teach_intent' : 'topic_intent' } : null;
  }
  return { surface: 'chat', href: chatHref(request), reason: 'direct_answer' };
}

/** Visible shortcuts never infer a different capability. */
export function directLearningHref(surface, input = '') {
  const request = typeof input === 'string' ? input.trim() : '';
  if (surface === 'chat') return request ? chatHref(request) : '/chat';
  if (surface === 'test_prep') return testPrepEntryHref();
  if (surface === 'classroom') return request ? classroomEntryHref({ topic: request, recordScope: 'unit' }) : '/classroom';
  return null;
}
