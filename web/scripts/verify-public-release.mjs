// Run after deployment: SITE_URL=https://www.lyoai.app node scripts/verify-public-release.mjs
// Fails closed if a public launch artifact is missing or incorrectly served.
const origin = process.env.SITE_URL;
if (!origin || !/^https:\/\//.test(origin)) {
  console.error('Set SITE_URL to an HTTPS deployment URL.');
  process.exit(2);
}
const checks = [
  { path: '/', status: 200, contentType: 'text/html' },
  { path: '/robots.txt', status: 200, contentType: 'text/plain', contains: 'sitemap' },
  { path: '/sitemap.xml', status: 200, contentType: 'xml', contains: 'lyoai.app' },
  { path: '/opengraph-image', status: 200, contentType: 'image/png' },
  { path: '/nonexistent-launch-smoke-page-483921', status: 404, contentType: 'text/html', contains: 'Back to LYO home' },
];
let failed = 0;
for (const check of checks) {
  try {
    const res = await fetch(new URL(check.path, origin), { redirect: 'follow', signal: AbortSignal.timeout(15000) });
    const body = check.contains ? await res.text() : '';
    const ok = res.status === check.status &&
      res.headers.get('content-type')?.includes(check.contentType) &&
      (!check.contains || body.toLowerCase().includes(check.contains.toLowerCase()));
    console.log(`${ok ? 'PASS' : 'FAIL'} ${check.path} — ${res.status} ${res.headers.get('content-type')}`);
    if (!ok) failed += 1;
  } catch (error) {
    console.error(`FAIL ${check.path}: ${error.message}`);
    failed += 1;
  }
}
if (failed) process.exitCode = 1;
