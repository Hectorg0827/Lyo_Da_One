import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const nextConfig = createRequire(import.meta.url)('../../next.config.js');

test('the bare domain forwards every path to www, permanently', async () => {
  const rules = await nextConfig.redirects();
  const bare = rules.filter((rule) => rule.has?.some((c) => c.type === 'host' && c.value === 'lyoai.app'));
  assert.equal(bare.length, 1);
  assert.deepEqual(bare[0], {
    source: '/:path*',
    has: [{ type: 'host', value: 'lyoai.app' }],
    destination: 'https://www.lyoai.app/:path*',
    permanent: true,
  });
});

test('no rule matches the canonical host, so www can never loop', async () => {
  const rules = await nextConfig.redirects();
  assert.ok(rules.every((rule) => rule.has?.some((c) => c.type === 'host' && c.value !== 'www.lyoai.app')));
});
