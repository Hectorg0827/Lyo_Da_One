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

test('approved educational archives survive Classroom visual validation', () => {
  const approved = [
    ['https://upload.wikimedia.org/a/leaf.jpg', 'https://commons.wikimedia.org/wiki/File:Leaf.jpg'],
    ['https://images.pexels.com/photos/123/leaf.jpeg', 'https://www.pexels.com/photo/green-leaf-123/'],
    ['https://images-assets.nasa.gov/image/PIA1/PIA1~thumb.jpg', 'https://images.nasa.gov/details/PIA1'],
    ['https://ids.si.edu/ids/deliveryService?id=ABC', 'https://www.si.edu/object/edanmdm-nmnh-abc'],
  ];
  for (const [image_url, source_url] of approved) {
    const visual = { ...base, kind: 'annotated_image', image_query: 'scientific specimen', image_url, source_url };
    assert.deepEqual(parseTeachingVisual(visual), visual);
  }
});

test('image and attribution host checks reject impersonation and cross-host confusion', () => {
  const valid = { ...base, kind: 'annotated_image', image_query: 'leaf' };
  const forbidden = [
    ['https://images.pexels.com.evil.test/photo.jpg', 'https://www.pexels.com/photo/leaf-2/'],
    ['https://evil.test@images.pexels.com/photo.jpg', 'https://www.pexels.com/photo/leaf-2/'],
    ['http://images.pexels.com/photos/a.jpg', 'https://www.pexels.com/photo/leaf-2/'],
    ['https://images.pexels.com/photos/a.jpg', 'https://www.pexels.com.evil.test/photo/leaf/'],
    ['https://images-assets.nasa.gov/image/file.jpg', 'https://images-assets.nasa.gov/details/PIA'],
    ['https://images.pexels.com/photos/a.jpg', 'https://images.nasa.gov.evil.test/details/PIA'],
  ];
  for (const [image_url, source_url] of forbidden) {
    assert.equal(parseTeachingVisual({ ...valid, image_url, source_url }), null);
  }
});
