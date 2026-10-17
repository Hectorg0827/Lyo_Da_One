import { pathToFileURL } from 'node:url';

/** Require actual serving revisions, never a caller's optimistic build label. */
export async function verifyReleaseRevisions(env = process.env, fetcher = fetch) {
  const targets = [
    ['web', env.SITE_URL, '/api/health', env.EXPECTED_WEB_SHA, 'commit'],
    ['backend', env.API_URL, '/health', env.EXPECTED_BACKEND_SHA, 'commit_sha'],
  ];
  const evidence = [];
  for (const [service, origin, path, expected, field] of targets) {
    if (!/^[a-f0-9]{40}$/.test(expected || '')) {
      throw new Error(`${service}: exact 40-character expected SHA is required`);
    }
    const base = new URL(origin);
    if (base.protocol !== 'https:' || base.username || base.password ||
        base.pathname !== '/' || base.search || base.hash) {
      throw new Error(`${service}: HTTPS deployment origin is required`);
    }
    const response = await fetcher(new URL(path, base), {
      redirect: 'error', headers: { 'Cache-Control': 'no-cache' },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`${service}: health HTTP ${response.status}`);
    const body = await response.json();
    if (body.status !== 'healthy' || body[field] !== expected) {
      throw new Error(`${service}: selected revision is not serving (reported ${body[field] || 'unknown'})`);
    }
    evidence.push({ service, origin: base.origin, sha: expected, checked_at: new Date().toISOString() });
  }
  return evidence;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(JSON.stringify(await verifyReleaseRevisions(), null, 2));
  } catch (error) {
    console.error(`Release revision check failed: ${error.message}`);
    process.exitCode = 1;
  }
}
