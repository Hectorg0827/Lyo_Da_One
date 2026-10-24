import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

// Every NEXT_PUBLIC_ switch is compiled into the bundle, and a Docker build
// only receives the service variables it declares with ARG before the build.
test('every launch switch reaches the production build', () => {
  const switches = [...read('./launch-features.ts').matchAll(/process\.env\.(NEXT_PUBLIC_\w+)/g)].map((m) => m[1]);
  assert.ok(switches.length > 0);
  const dockerfile = read('../../Dockerfile');
  const builder = dockerfile.slice(dockerfile.indexOf('AS builder'), dockerfile.indexOf('RUN npm run build'));
  for (const name of switches) {
    assert.match(builder, new RegExp(`^ARG ${name}=false$`, 'm'), `${name} is not declared as a build arg`);
    assert.match(builder, new RegExp(`^ENV ${name}=\\$${name}$`, 'm'), `${name} is not passed to the build`);
  }
});
