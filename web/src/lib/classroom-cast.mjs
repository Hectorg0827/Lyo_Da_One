/**
 * LYO Classroom's character identities. These are presentation identities,
 * never substitutes for an actual teacher/peer turn from the classroom wire.
 * Keep teacher, AI classmates and the student's companion distinct.
 */
export const TEACHERS = Object.freeze([
  { id: 'teacher_1', name: 'Teacher 1', displayName: 'Mira', voice: 'onyx', image: '/classroom/cast/teacher-1.png', accent: 'text-lyo-300' },
  { id: 'teacher_2', name: 'Teacher 2', displayName: 'Nova', voice: 'echo', image: '/classroom/cast/teacher-2.png', accent: 'text-lyo-300' },
  { id: 'teacher_3', name: 'Teacher 3', displayName: 'Atlas', voice: 'fable', image: '/classroom/cast/teacher-3.png', accent: 'text-lyo-300' },
  { id: 'teacher_4', name: 'Teacher 4', displayName: 'Sage', voice: 'shimmer', image: '/classroom/cast/teacher-4.png', accent: 'text-lyo-300' },
]);

export const CLASSMATES = Object.freeze([
  { id: 'student_maya', name: 'Maya', personality: 'clever and cheeky', voice: 'alloy', image: '/classroom/cast/student-maya.png', accent: 'text-accent-teal' },
  { id: 'student_sam', name: 'Sam', personality: 'cool and analytical', voice: 'nova', image: '/classroom/cast/student-sam.png', accent: 'text-accent-orange' },
  { id: 'student_rio', name: 'Rio', personality: 'funny and supportive', voice: 'fable', image: '/classroom/cast/student-rio.png', accent: 'text-accent-green' },
  { id: 'student_zack', name: 'Zack', personality: 'curious and persistent', voice: 'echo', image: '/classroom/cast/student-zack.png', accent: 'text-accent-gold' },
]);

export const LYO_COMPANION = Object.freeze({
  id: 'lyo', name: 'Lyo', voice: 'nova', image: '/mascot/mascot_standing.png', accent: 'text-accent-gold',
});

/** Stable for a subject on every client; the server uses the same rule. */
export function teacherForTopic(topic = '') {
  const points = Array.from(String(topic).toLowerCase());
  const sum = points.reduce((total, char) => total + (char.codePointAt(0) ?? 0), 0);
  return TEACHERS[sum % TEACHERS.length];
}

export function classroomSpeaker(name, topic = '') {
  if (name === 'Lyo') return LYO_COMPANION;
  const teacher = TEACHERS.find((character) => character.name === name || character.id === name);
  if (teacher) return teacher;
  if (name === 'Teacher' || !name) return teacherForTopic(topic);
  return CLASSMATES.find((character) => character.name === name || character.id === name) ?? null;
}

/** No imaginary seated classmates: show only people the wire has spoken for. */
export function speakingClassmates(transcript, mode) {
  if (mode !== 'classroom') return [];
  const spoken = new Set(transcript.map((entry) => entry.speaker));
  return CLASSMATES.filter((person) => spoken.has(person.name));
}
