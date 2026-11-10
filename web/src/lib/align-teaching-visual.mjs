import { parseTeachingVisual } from './teaching-activity.mjs';

/**
 * Keep an authored fraction's exact counts while correcting a narrowly
 * identifiable shape mismatch in the adjacent worked-example heading.
 * Never infer counts from prose or override a lesson explicitly comparing
 * a bar with a circle/pizza.
 */
export function alignTeachingVisualToExample(visual, exampleTitle, exampleContent = '') {
  if (!visual || visual.kind !== 'fraction_pie' || visual.parts < 2) return visual;
  const heading = typeof exampleTitle === 'string' ? exampleTitle : '';
  const content = typeof exampleContent === 'string' ? exampleContent : '';
  if (!/\b(?:chocolate|candy)\s+bars?\b/i.test(heading)) return visual;
  if (/\b(?:circle|circular|pizza|pie)\b/i.test(`${heading} ${content}`)) return visual;
  const label = /\bcandy\b/i.test(heading) ? 'candy bar' : 'chocolate bar';
  return parseTeachingVisual({
    ...visual,
    kind: 'fraction_bar',
    title: `${label[0].toUpperCase()}${label.slice(1)} fraction model`,
    caption: `${visual.value} of ${visual.parts} equal pieces of the ${label}`,
    description: `${visual.parts} equal ${label} pieces; ${visual.value} selected`,
  }) || visual;
}
