import assert from 'node:assert/strict';
import test from 'node:test';

import { parseTeachingVisual } from './teaching-activity.mjs';

const base = {
  title: 'Visual teaching example',
  caption: 'Look at the relationship before answering the next question.',
  description: 'A text equivalent describing the important visual relationship.',
  parts: 10,
  whole: 1,
  unit: '',
  value: 0,
  entries: [],
  expression: '',
  params: [],
  x_min: -5,
  x_max: 5,
  y_min: -10,
  y_max: 10,
  image_query: '',
};

test('richer classroom visuals validate without introducing video', () => {
  const visuals = [
    {
      ...base,
      visual_id: 'visual-process-1',
      kind: 'process_flow',
      entries: [
        { label: 'Input', detail: 'Material enters.' },
        { label: 'Process', detail: 'Material changes.' },
        { label: 'Output', detail: 'A result leaves.' },
      ],
      value: 1,
    },
    {
      ...base,
      visual_id: 'visual-timeline-1',
      kind: 'timeline',
      entries: [
        { label: '1900', detail: 'Starting event.' },
        { label: '1950', detail: 'Transition event.' },
        { label: '2000', detail: 'Later event.' },
      ],
    },
    {
      ...base,
      visual_id: 'visual-number-1',
      kind: 'number_line',
      x_min: -10,
      x_max: 10,
      entries: [
        { label: '-5', detail: 'Below zero.', position: -5 },
        { label: '0', detail: 'The origin.', position: 0 },
        { label: '7', detail: 'Above zero.', position: 7 },
      ],
      value: 1,
    },
    {
      ...base,
      visual_id: 'visual-image-1',
      kind: 'annotated_image',
      image_query: 'human heart anatomy',
      image_url: 'https://upload.wikimedia.org/example/heart.jpg',
      source_url: 'https://commons.wikimedia.org/wiki/File:Heart.jpg',
      attribution: 'File:Heart.jpg',
      entries: [
        { label: 'Ventricle', detail: 'Lower pumping chamber.', x: 0.55, y: 0.72 },
      ],
    },
  ];

  for (const visual of visuals) assert.deepEqual(parseTeachingVisual(visual), visual);
  assert.equal(parseTeachingVisual({ ...base, kind: 'video' }), null);
  assert.equal(parseTeachingVisual({ ...base, kind: 'youtube' }), null);
});

test('annotated images reject arbitrary model supplied URLs', () => {
  const invalid = {
    ...base,
    kind: 'annotated_image',
    image_query: 'human heart anatomy',
    image_url: 'https://example.com/invented.jpg',
  };
  assert.equal(parseTeachingVisual(invalid), null);
});
