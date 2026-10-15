/**
 * A Stack row is not necessarily a persisted course. /api/v1/learning/courses/:id
 * accepts integer course IDs only; titles, UUIDs and Stack row IDs cannot be
 * passed to it. Keep unpersisted topic cards useful by opening a fresh class.
 */
export function courseDestination(item) {
  const contentId = typeof item.content_id === 'string' ? item.content_id.trim() : '';
  if (/^[1-9]\d*$/.test(contentId) && Number.isSafeInteger(Number(contentId))) {
    return `/courses/${contentId}`;
  }

  const topic = (typeof item.title === 'string' && item.title.trim()) || 'General Learning';
  const identity = contentId || `stack-${item.id}`;
  return `/classroom?topic=${encodeURIComponent(topic)}&courseId=${encodeURIComponent(identity)}`;
}
