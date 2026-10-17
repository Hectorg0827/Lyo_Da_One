/** Read-only contract inventory against the real public backend; no credentials. */
const origin = process.env.API_URL || 'https://api.lyoai.app';
const candidates = ['/openapi.json', '/api/v1/openapi.json'];
let paths = null;
for (const path of candidates) {
  try {
    const response = await fetch(new URL(path, origin), { signal: AbortSignal.timeout(15000) });
    console.log(`OpenAPI ${path}: HTTP ${response.status}`);
    if (response.ok) {
      const body = await response.json();
      if (body && typeof body.paths === 'object') {
        paths = body.paths;
        break;
      }
    }
  } catch (error) {
    console.log(`OpenAPI ${path}: ${error.message}`);
  }
}
if (!paths) {
  console.error('No accessible production OpenAPI specification; route parity NOT certified.');
  process.exit(2);
}
const required = [
  ['/auth/login', 'post'],
  ['/auth/register', 'post'],
  ['/api/v1/auth/password-reset/request', 'post'],
  ['/api/v1/auth/password-reset/confirm', 'post'],
  ['/api/v1/learning/courses/mine', 'get'],
  ['/api/v1/gamification/my-achievements', 'get'],
];
let misses = 0;
console.log(`Production API publishes ${Object.keys(paths).length} paths.`);
for (const [p, method] of required) {
  const exists = Boolean(paths[p]?.[method]);
  console.log(`${exists ? 'PASS' : 'FAIL'} ${method.toUpperCase()} ${p}`);
  if (!exists) misses += 1;
}
if (misses) {
  console.error(`${misses} critical routes missing from the actual serving API; launch blocked.`);
  process.exitCode = 1;
}
