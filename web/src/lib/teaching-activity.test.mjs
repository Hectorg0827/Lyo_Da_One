import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseTeachingVisual } from './teaching-activity.mjs';

const fixture = JSON.parse(readFileSync(new URL('../../../Sources/Tests/Fixtures/GuidedTeaching.json', import.meta.url)));

test('all four teaching activities from the production runner validate and preserve saved values', () => {
  assert.deepEqual(fixture.visuals.map(v => v.kind), ['fraction_bar', 'comparison', 'sequence', 'graph']);
  for (const visual of fixture.visuals) assert.deepEqual(parseTeachingVisual(visual), visual);
  for (const scene of Object.values(fixture.scenes)) {
    for (const component of scene.components.filter(c => c.block_type === 'teaching_visual')) {
      assert.ok(parseTeachingVisual(component.block));
      assert.equal(scene.components.filter(c => c.component_id === component.component_id).length, 1);
    }
  }
});

test('malformed arrays, ranges and parameters fail without crashing the lesson', () => {
  const [fraction, comparison, , graph] = fixture.visuals;
  for (const raw of [null, {}, { ...fraction, parts: 0 }, { ...fraction, value: 5 },
    { ...fraction, whole: Infinity }, { ...comparison, entries: [null, null] },
    { ...comparison, value: 9 }, { ...graph, params: [null] },
    { ...graph, params: [graph.params[0], graph.params[0]] },
    { ...graph, params: [{ ...graph.params[0], initial: NaN }] },
    { ...graph, params: [{ ...graph.params[0], step: -1 }] },
    { ...graph, y_min: 10, y_max: -10 }]) {
    assert.equal(parseTeachingVisual(raw), null);
  }
});

test('paced teaching has an explicit canonical CTA and the first task is supported choice', () => {
  for (const name of ['orientation', 'model_1', 'model_2']) {
    const components = fixture.scenes[name].components;
    assert.ok(components.some(c => c.type === 'ExampleBlock'));
    assert.equal(components.some(c => c.type === 'QuizCard' || c.type === 'InputField'), false);
    const cta = components.find(c => c.type === 'CTAButton');
    assert.equal(cta.action_intent, 'continue');
    assert.ok(cta.component_id);
  }
  assert.ok(fixture.scenes.guided.components.some(c => c.type === 'QuizCard'));
  const faded = fixture.scenes.faded.components.find(c => c.type === 'InputField');
  assert.equal(faded.min_words, 1);
  assert.match(faded.question, /1\/__/);
});

test('a unit opens by asking, with no worked example and no way to move on unanswered', () => {
  const components = fixture.scenes.diagnostic.components;
  // One teacher line, then the floor is the learner's. The probe is asked
  // before anything is taught, so there is a question and nothing to walk
  // through — this is the scene that replaced opening every unit with a
  // lecture, and the shape is the whole point of it.
  assert.equal(components.filter(c => c.type === 'TeacherMessage').length, 1);
  const input = components.find(c => c.type === 'InputField');
  assert.ok(input, 'the opening scene must ask the learner something');
  assert.ok(input.question.trim().length > 0);

  // A Continue here would make answering optional, which is the monologue
  // with an extra tap.
  assert.equal(components.some(c => c.type === 'CTAButton'), false);

  // Nothing on the wire tells the learner what the answer is. The probe is
  // graded by the server against a rubric it keeps.
  assert.equal(JSON.stringify(components).includes('example_answer'), false);
  assert.equal(JSON.stringify(components).includes('criteria'), false);
  assert.deepEqual(input.expected_keywords ?? [], []);

  // It is scored as an explanation, never as transfer: transfer is defined
  // relative to something taught, and nothing has been.
  assert.equal(input.evidence_type, 'explanation');

  // And no teaching visual: the comparison tool's own description explains why
  // the answer is the answer. A probe's board may carry the situation, never
  // the reasoning.
  assert.equal(components.some(c => c.block_type === 'teaching_visual'), false);
});
