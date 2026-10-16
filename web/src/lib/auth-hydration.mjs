/** Preserve learner identity across transient session-verification failures.
 * A server 401 after refresh is authoritative; 429/5xx/network is not.
 */
export function hydrationFailureKind(error) {
  const status = typeof error?.status === 'number' ? error.status : null;
  return status === 401 || status === 403 ? 'invalid_session' : 'transient';
}
