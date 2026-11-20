/** Stack cards may represent a catalog course ID or a free-topic classroom.
 * Only catalog IDs are valid under /courses/[id]; the course detail API
 * rejects titles with a 422. Free-topic cards must return to the classroom.
 */
export function catalogCourseId(value) {
  const id = String(value || '').trim();
  return /^[1-9]\d*$/.test(id) && Number.isSafeInteger(Number(id)) ? id : null;
}

export function classroomExitHref(courseId) {
  const catalogId = catalogCourseId(courseId);
  return catalogId ? `/courses/${catalogId}` : '/';
}

export function stackCourseHref(item) {
  // Stack item.id is the *stack row* ID, not a catalog course ID.
  const id = String(item?.content_id || '').trim();
  if (catalogCourseId(id)) {
    return `/courses/${id}`;
  }

  const saved = item?.extra_data?.classroom;
  const topic = String(saved?.topic || item?.title || id || 'General Learning').trim();
  const params = new URLSearchParams({ topic, courseId: id || topic });
  if (saved?.objective) params.set('objective', String(saved.objective));
  if (saved?.recordScope === 'unit') params.set('recordScope', 'unit');
  if (['beginner', 'intermediate', 'advanced'].includes(saved?.difficulty)) {
    params.set('difficulty', saved.difficulty);
  }
  if ([5, 10, 15, 20, 30, 45, 60].includes(Number(saved?.durationMinutes))) {
    params.set('duration', String(saved.durationMinutes));
  }
  if (saved?.language) params.set('language', String(saved.language));
  if (['solo', 'classroom', 'challenge', 'review'].includes(saved?.mode)) {
    params.set('mode', saved.mode);
  }
  if (item?.status === 'in_progress' || item?.status === 'paused') {
    params.set('resume', '1');
  }
  return `/classroom?${params.toString()}`;
}
