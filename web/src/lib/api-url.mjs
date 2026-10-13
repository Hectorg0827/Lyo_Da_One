/** Build a v1 API URL once, irrespective of legacy or absolute-v1 callers.
 *
 * Both NEXT_PUBLIC_API_URL=... and NEXT_PUBLIC_API_URL=.../api/v1 are
 * supported, and the endpoint may or may not already have /api/v1.
 * Never return an external URL supplied by an untrusted endpoint.
 */
export function resolveApiEndpoint(apiBase, endpoint) {
  if (typeof apiBase !== 'string' || typeof endpoint !== 'string' ||
      !endpoint.startsWith('/') || endpoint.startsWith('//')) {
    throw Error('Invalid API endpoint');
  }
  const base = new URL(apiBase);
  if (!['http:', 'https:'].includes(base.protocol) ||
      base.username || base.password || base.search || base.hash) {
    throw Error('Invalid API base');
  }
  const path = base.pathname.replace(/\/+$/, '');
  if (path !== '' && path !== '/api/v1') {
    throw Error('API base must end at its host or /api/v1');
  }
  const target = endpoint.startsWith('/api/v1/') || endpoint === '/api/v1'
    ? endpoint
    : '/api/v1' + endpoint;
  return base.origin + target;
}
