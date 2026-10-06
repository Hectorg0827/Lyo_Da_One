// Does the live site actually serve the commit that was just pushed?
//
// Nothing in CI deploys the web app. The production service is a Railway
// service connected straight to this repository (see
// WEB_PRODUCTION_DEPLOYMENT.md): Railway notices a push to main, builds
// web/Dockerfile itself, and swaps the running instance. CI only publishes a
// parallel image to GHCR, which that service does not consume.
//
// So "the pipeline went green" has never meant "the site changed", and there
// was no way to tell the difference from outside — a question that came up the
// first time a merged change did not appear on lyoai.app. This closes that:
// it polls the live health endpoint until the commit it reports is the one
// being released, and fails loudly when that never happens.
//
// It asserts; it does not deploy. If this fails, the deploy did not happen or
// did not finish, and the message says which.

const url = process.env.DEPLOY_HEALTH_URL ?? 'https://lyoai.app/api/health';
const expected = (process.env.DEPLOY_EXPECTED_COMMIT ?? '').trim();
const timeoutMs = Number(process.env.DEPLOY_TIMEOUT_MS ?? 15 * 60 * 1000);
const intervalMs = Number(process.env.DEPLOY_POLL_INTERVAL_MS ?? 20 * 1000);

if (!expected) {
  throw new Error('DEPLOY_EXPECTED_COMMIT is required (the commit being released)');
}

const short = (sha) => sha.slice(0, 12);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** One look at the live service. Never throws: a deploy in progress refuses
 *  connections, and that is a reason to keep waiting, not to fail. */
async function probe() {
  try {
    const response = await fetch(url, {
      headers: { 'Cache-Control': 'no-cache' },
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) return { ok: false, why: `HTTP ${response.status}` };
    const body = await response.json();
    return { ok: true, commit: typeof body.commit === 'string' ? body.commit.trim() : null };
  } catch (error) {
    return { ok: false, why: error instanceof Error ? error.message : String(error) };
  }
}

const startedAt = Date.now();
let attempts = 0;
let last = null;

console.log(`Waiting for ${url} to serve ${short(expected)}`);

while (Date.now() - startedAt < timeoutMs) {
  attempts += 1;
  const result = await probe();
  const elapsed = Math.round((Date.now() - startedAt) / 1000);

  if (result.ok && result.commit === expected) {
    console.log(`Live after ${elapsed}s (${attempts} checks): ${url} serves ${short(expected)}.`);
    process.exit(0);
  }

  last = result;
  const saw = result.ok ? (result.commit ? short(result.commit) : 'no commit reported') : result.why;
  console.log(`  ${elapsed}s — ${saw}`);
  await sleep(intervalMs);
}

// Out of time. Say which of the three failures this is, because they need
// different fixes and a bare "timed out" sends people to the wrong one.
const waited = Math.round((Date.now() - startedAt) / 1000);
const waitedLabel = waited >= 90 ? `${Math.round(waited / 60)} minutes` : `${waited}s`;
let diagnosis;
if (!last?.ok) {
  diagnosis =
    `The health endpoint never answered (last: ${last?.why ?? 'no response'}). ` +
    'Either the service is down or the deploy is still building.';
} else if (last.commit === null) {
  diagnosis =
    'The service is up but reports no commit, so a fresh deploy cannot be ' +
    'told from a stale one. Either it is still running an image built ' +
    'before /api/health carried the field — in which case the next deploy ' +
    'fixes it — or the platform supplies no commit variable. If this ' +
    'persists, add a Railway service variable LYO_GIT_COMMIT set to the ' +
    'reference ${{RAILWAY_GIT_COMMIT_SHA}} (the reference, so it changes ' +
    'per deploy; a literal commit pasted there would make every deploy ' +
    'look current).';
} else {
  diagnosis =
    `The service is up and healthy, but still serving ${short(last.commit)}. ` +
    'The push did not trigger a deploy — check that the Railway service is ' +
    'still connected to this repository and that automatic deploys from ' +
    'main are enabled.';
}

console.error(`\nAfter ${waitedLabel}, ${url} is not serving ${short(expected)}.\n${diagnosis}`);
process.exit(1);
