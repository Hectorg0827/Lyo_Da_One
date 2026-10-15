/**
 * Diagrams, charts and images a reply writes in Markdown, lifted into the
 * blocks that can actually draw them.
 *
 * Chat already renders a flow diagram, a bar or line chart, and a framed
 * image — the components exist and the Classroom uses them. But a reply that
 * arrives as prose keeps its diagram inside a fenced code block, so the
 * learner reads `graph TD / A[Sunlight] --> B[Chlorophyll]` as source code
 * next to a renderer that would have drawn it.
 *
 * This is additive, unlike the study-material pass: nothing is summarised or
 * thrown away. The prose around a visual is preserved in order, so lifting a
 * diagram out can never cost the learner a sentence.
 */

/** Longest diagram source worth drawing; past this it is a code listing. */
const MAX_DIAGRAM_CHARS = 4000;

/** Chart shape `ChartView` accepts. Mirrored here so an invalid one stays code. */
const MAX_CHART_POINTS = 12;

const FENCE = /```(mermaid|chart)\s*\n([\s\S]*?)```/g;
/** A line that is nothing but an image — an inline one stays in its sentence. */
const IMAGE_LINE = /^[ \t]*!\[([^\]]*)\]\((https:\/\/[^\s)]+)\)[ \t]*$/gm;

/**
 * The reply split into prose and the visuals embedded in it, in order.
 *
 * @returns segments, or null when the text holds no visual worth lifting
 */
export function segmentVisuals(text) {
  const source = String(text || '');
  if (!source) return null;

  const found = [];

  FENCE.lastIndex = 0;
  for (let m = FENCE.exec(source); m; m = FENCE.exec(source)) {
    const body = m[2].trim();
    if (!body || body.length > MAX_DIAGRAM_CHARS) continue;
    if (m[1] === 'mermaid') {
      found.push({ start: m.index, end: m.index + m[0].length, kind: 'mermaid', source: body });
    } else if (isDrawableChart(body)) {
      found.push({ start: m.index, end: m.index + m[0].length, kind: 'chart', source: body });
    }
  }

  IMAGE_LINE.lastIndex = 0;
  for (let m = IMAGE_LINE.exec(source); m; m = IMAGE_LINE.exec(source)) {
    found.push({
      start: m.index,
      end: m.index + m[0].length,
      kind: 'image',
      url: m[2],
      alt: m[1].trim(),
    });
  }

  if (!found.length) return null;

  found.sort((a, b) => a.start - b.start);

  const segments = [];
  let cursor = 0;
  for (const hit of found) {
    if (hit.start < cursor) continue; // overlapping match; keep the first
    pushText(segments, source.slice(cursor, hit.start));
    segments.push(hit);
    cursor = hit.end;
  }
  pushText(segments, source.slice(cursor));

  return segments.length ? segments : null;
}

function pushText(segments, raw) {
  const text = String(raw || '').trim();
  if (text) segments.push({ kind: 'text', text });
}

/**
 * Whether a chart payload is one `ChartView` will draw.
 *
 * Checked before the block is made, so an unparseable or oversized series
 * stays a readable code fence instead of becoming a block that renders as
 * raw source anyway.
 */
export function isDrawableChart(body) {
  let chart;
  try {
    chart = JSON.parse(String(body || ''));
  } catch {
    return false;
  }
  if (!chart || typeof chart !== 'object') return false;
  const { chartType, labels, values } = chart;
  return (
    (chartType === 'bar' || chartType === 'line') &&
    Array.isArray(labels) &&
    Array.isArray(values) &&
    labels.length > 0 &&
    labels.length <= MAX_CHART_POINTS &&
    labels.length === values.length &&
    labels.every((v) => typeof v === 'string' && v.length > 0) &&
    values.every((v) => typeof v === 'number' && Number.isFinite(v) && v >= 0)
  );
}

/**
 * The blocks a turn should end up with once its visuals are drawable.
 *
 * Each text block is split in place, so a visual lands exactly where the
 * reply put it and the prose on either side keeps its position.
 *
 * @returns the new block list, or null when nothing needed lifting
 */
export function expandVisualBlocks(blocks, idPrefix = 'visual') {
  const input = Array.isArray(blocks) ? blocks : [];
  const out = [];
  let changed = false;
  let seq = 0;

  for (const block of input) {
    const text =
      block && block.type === 'text' && typeof block.content?.text === 'string'
        ? block.content.text
        : null;
    if (text === null) {
      out.push(block);
      continue;
    }

    const segments = segmentVisuals(text);
    if (!segments || !segments.some((s) => s.kind !== 'text')) {
      out.push(block);
      continue;
    }

    changed = true;
    for (const segment of segments) {
      seq += 1;
      out.push(blockFor(segment, block, `${idPrefix}-${seq}`));
    }
  }

  return changed ? out : null;
}

function blockFor(segment, origin, id) {
  if (segment.kind === 'text') {
    return { ...origin, id, content: { ...origin.content, text: segment.text } };
  }
  if (segment.kind === 'mermaid') {
    return { id, type: 'dataViz', content: { format: 'mermaid', source: segment.source } };
  }
  if (segment.kind === 'chart') {
    return { id, type: 'dataViz', content: { format: 'chart', source: segment.source } };
  }
  return {
    id,
    type: 'media',
    subtype: 'image',
    content: { url: segment.url, alt: segment.alt, caption: segment.alt },
  };
}
