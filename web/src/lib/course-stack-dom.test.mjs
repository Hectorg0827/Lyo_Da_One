import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

const filename = new URL('../components/home/CourseStack.tsx', import.meta.url);
const source = readFileSync(filename, 'utf8');
const file = ts.createSourceFile('CourseStack.tsx', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);

function attribute(opening, name) {
  return opening.attributes.properties.find((property) =>
    ts.isJsxAttribute(property) && property.name.text === name);
}

test('saved course links are independent interactive targets, not children of card buttons', () => {
  let links = 0;
  let cardButtons = 0;
  function visit(node, clickableAncestors = []) {
    if (ts.isJsxSelfClosingElement(node)) {
      if (node.tagName.getText(file) === 'button'
        && attribute(node, 'onClick')?.initializer?.getText(file) === '{openBack}') cardButtons++;
      return;
    }
    if (ts.isJsxElement(node)) {
      const opening = node.openingElement;
      const tag = opening.tagName.getText(file);
      const role = attribute(opening, 'role')?.initializer?.getText(file);
      const clickable = tag === 'button' || tag === 'a' || role === '"button"';
      if (tag === 'Link' && attribute(opening, 'href')?.initializer?.getText(file) === '{href}') {
        links++;
        assert.deepEqual(clickableAncestors, [], 'Course action link must not be nested in an interactive card');
        assert.ok(attribute(opening, 'href'), 'Course action link must have a real navigation destination');
        assert.ok(attribute(opening, 'tabIndex'), 'A link on the hidden face must leave the tab order');
        assert.match(attribute(opening, 'className')?.initializer?.getText(file) ?? '', /pointer-events-auto/);
      }
      node.children.forEach((child) => visit(child, clickable ? [...clickableAncestors, tag] : clickableAncestors));
      return;
    }
    ts.forEachChild(node, (child) => visit(child, clickableAncestors));
  }
  visit(file);
  assert.equal(links, 2, 'Front and back course actions must remain navigable');
  assert.equal(cardButtons, 1, 'The transparent card face has its own accessible action');
});
