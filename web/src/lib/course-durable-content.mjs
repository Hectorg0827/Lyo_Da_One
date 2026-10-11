/**
 * Adapt the durable backend lesson contract to CoursePlayer's LessonBlocks.
 * A plain text lesson is content, not an empty lesson.
 */
export function courseLessonBlocks(content, lessonId = 'lesson') {
  if (Array.isArray(content)) return content;
  if (typeof content === 'string' && content.trim()) {
    return [{ id: `${lessonId}-text`, type: 'text', content }];
  }
  return [];
}

export function courseLessonMinutes(lesson) {
  const explicit = lesson?.duration_minutes;
  if (Number.isInteger(explicit) && explicit > 0) return explicit;
  const oldValue = lesson?.duration;
  if (Number.isInteger(oldValue) && oldValue > 0) return oldValue;
  if (typeof oldValue === 'string') {
    const match = oldValue.trim().match(/^(\d+)\s*(?:min(?:utes?)?)?$/i);
    if (match && Number(match[1]) > 0) return Number(match[1]);
  }
  return 10;
}
