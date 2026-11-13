/**
 * Read-only public staging smoke test. No learner credentials, writes, test
 * accounts, or production requests. Run only against the isolated Railway URLs.
 */
const web = 'https://lyoonestagingweb-staging.up.railway.app';
const api = 'https://lyojourneystagingbackend-staging.up.railway.app';
const timeoutMs = 20000;

async function probe(path, base, expect) {
  const url = new URL(path, base);
  if (!url.hostname.endsWith('-staging.up.railway.app')) {
    throw new Error('Refusing non-staging host: ' + url.hostname);
  }
  const signal = AbortSignal.timeout(timeoutMs);
  const t0 = performance.now();
  const response = await fetch(url, {signal, redirect: 'follow', headers: {'User-Agent': 'LYO-Staging-QA-Smoke/1.0'}});
  const elapsedMs = Math.round(performance.now() - t0);
  if (!response.ok) throw new Error(url + ' returned HTTP ' + response.status);
  if (!response.url.startsWith(web) && !response.url.startsWith(api)) {
    throw new Error('Staging request redirected outside approved hosts: ' + response.url);
  }
  const data = await response.text();
  if (expect === 'html' && !/<(?:!doctype\s+html|html)\b/i.test(data)) {
    throw new Error('Unexpected non-HTML response for ' + url);
  }
  console.log(JSON.stringify({endpoint: url.pathname, service: url.origin === web ? 'web' : 'api', http: response.status, elapsedMs, bytes: data.length}));
  return data;
}

await probe('/health', api, 'health');
const html = await probe('/', web, 'html');
await probe('/auth/login', web, 'html');

// The root document must reference a loadable Next.js JS chunk. A successful
// HTML response alone misses broken asset paths and empty deployments.
const scripts = Array.from(html.matchAll(/<script[^>]+src="([^"]+\.js(?:\?[^"]*)?)"/g), match => match[1]);
const chunk = scripts.find(url => url.startsWith('/_next/static/') && url.includes('.js'));
if (!chunk) throw new Error('No Next.js static script referenced by the staging home page');
const source = await probe(chunk, web, 'asset');
if (!source || source.length < 100) throw new Error('Next.js script was empty or truncated');
console.log('PASS: staging Web, auth screen, backend health, and a Next.js asset are reachable');
