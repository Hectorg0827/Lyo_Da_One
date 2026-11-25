/**
 * Adapt the actual /api/v1/learning/courses/{id} response to the Web reader.
 * The API returns top-level lessons with string content. Other saved courses
 * have nested modules and structured blocks. Never invent lesson content.
 */
const blockTypes = new Set([
  'text', 'heading', 'code', 'image', 'video', 'quiz',
  'flashcard', 'diagram', 'analogy', 'summary', 'exercise',
]);

function record(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value : null;
}

function numeric(value, fallback) {
  const number = typeof value === 'number' ? value
    : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(number) && number >= 0 ? number : fallback;
}

function normalizeBlockArray(value, lessonId) {
  if (!Array.isArray(value)) return [];
  return value.flatMap((candidate, index) => {
    const item = record(candidate);
    if (!item) return [];
    const type = String(item.type || 'text');
    if (!blockTypes.has(type)) return [];
    const rawContent = item.content;
    if (typeof rawContent !== 'string' && !(
      (type === 'quiz' || type === 'flashcard' || type === 'summary')
      && rawContent && typeof rawContent === 'object'
    )) return [];
    if (typeof rawContent === 'string' && !rawContent.trim()) return [];
    return [{
      id: String(item.id ?? `${lessonId}:block-${index}`),
      type,
      content: rawContent,
      ...(record(item.metadata) ? { metadata: item.metadata } : {}),
    }];
  });
}

export function normalizeLessonBlocks(value, lessonId) {
  if (Array.isArray(value)) return normalizeBlockArray(value, lessonId);
  if (typeof value !== 'string' || !value.trim()) return [];
  const source = value.trim();
  // Some legacy records store a JSON-serialized block array. Only accept a
  // real block array; arbitrary malformed JSON remains readable as plain text.
  if (source.startsWith('[')) {
    try {
      const decoded = JSON.parse(source);
      const blocks = normalizeBlockArray(decoded, lessonId);
      if (blocks.length > 0) return blocks;
    } catch {
      // Plain text is legitimate course content; never discard it.
    }
  }
  return [{ id: `${lessonId}:text`, type: 'text', content: source }];
}

function normalizeLesson(item, lessonIndex, moduleId) {
  const l = record(item);
  if (!l) return null;
  const id = String(l.id ?? `${moduleId}:lesson-${lessonIndex}`);
  const content = normalizeLessonBlocks(l.content, id);
  const blocks = content.length ? content : normalizeLessonBlocks(l.blocks, id);
  const lessonType = String(l.type ?? 'text');
  const lessonTypes = new Set(['text', 'video', 'quiz', 'exercise', 'flashcard', 'interactive']);
  return {
    id,
    title: String(l.title ?? `Lesson ${lessonIndex + 1}`),
    type: lessonTypes.has(lessonType) ? lessonType : 'text',
    duration: numeric(l.estimated_duration_minutes ?? l.duration_minutes ?? l.duration, 10),
    order: numeric(l.order ?? (l.order_index != null ? Number(l.order_index) + 1 : undefined), lessonIndex + 1),
    isCompleted: l.is_completed === true || l.isCompleted === true,
    content: blocks,
  };
}

function sortedLessons(rawLessons, moduleId) {
  if (!Array.isArray(rawLessons)) return [];
  return rawLessons.map((item, index) => normalizeLesson(item, index, moduleId))
    .filter(Boolean)
    .sort((a, b) => a.order - b.order);
}

export function normalizeCourseModules(raw) {
  const course = record(raw);
  if (!course) return [];
  const id = String(course.id || 'course');
  const modules = Array.isArray(course.modules) ? course.modules.flatMap((candidate, index) => {
    const m = record(candidate);
    if (!m) return [];
    const moduleId = String(m.id ?? `${id}:module-${index}`);
    return [{
      id: moduleId,
      title: String(m.title ?? `Module ${index + 1}`),
      description: String(m.description ?? ''),
      order: numeric(m.order, index + 1),
      isCompleted: m.is_completed === true || m.isCompleted === true,
      lessons: sortedLessons(m.lessons, moduleId),
    }];
  }) : [];
  if (modules.some((m) => m.lessons.length > 0)) return modules.sort((a, b) => a.order - b.order);

  // Backend CourseDetailResponse sends lessons directly, with no modules.
  if (!Array.isArray(course.lessons) || !course.lessons.length) return modules;
  const moduleId = `${id}:lessons`;
  const lessons = sortedLessons(course.lessons, moduleId);
  if (!lessons.length) return modules;
  return [{
    id: moduleId,
    title: 'Course Lessons',
    description: '',
    order: 1,
    isCompleted: lessons.every((l) => l.isCompleted),
    lessons,
  }];
}
