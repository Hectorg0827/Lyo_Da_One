import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyReleaseRevisions } from '../../scripts/verify-release-revisions.mjs';

const web = 'a'.repeat(40);
const backend = 'b'.repeat(40);
const env = { SITE_URL: 'https://web.example', API_URL: 'https://api.example', EXPECTED_WEB_SHA: web, EXPECTED_BACKEND_SHA: backend };
const responding = (webBody, backendBody) => async (url) => ({
  ok: true, json: async () => url.hostname === 'web.example' ? webBody : backendBody,
});

test('acceptance binds both independently deployed repositories', async () => {
  const result = await verifyReleaseRevisions(env, responding(
    { status: 'healthy', commit: web }, { status: 'healthy', commit_sha: backend },
  ));
  assert.deepEqual(result.map(({ service, sha }) => [service, sha]), [['web', web], ['backend', backend]]);
});

test('a healthy older deployment cannot certify the selected candidate', async () => {
  await assert.rejects(verifyReleaseRevisions(env, responding(
    { status: 'healthy', commit: 'c'.repeat(40) }, { status: 'healthy', commit_sha: backend },
  )), /web: selected revision is not serving/);
});

test('missing backend revision and unhealthy status both fail closed', async () => {
  for (const body of [{ status: 'healthy' }, { status: 'degraded', commit_sha: backend }]) {
    await assert.rejects(verifyReleaseRevisions(env, responding({ status: 'healthy', commit: web }, body)), /backend: selected revision/);
  }
});

test('missing expected revision fails before probing', async () => {
  await assert.rejects(verifyReleaseRevisions({ ...env, EXPECTED_WEB_SHA: '' }, () => {
    assert.fail('must not fetch before a selected revision exists');
  }), /exact 40-character/);
});
