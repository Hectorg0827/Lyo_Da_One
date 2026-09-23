/** Keep the learner's Test Prep destination across authentication. */
export function authReturnPath(search) {
  return new URLSearchParams(search).get('next') === '/test-prep' ? '/test-prep' : '/';
}
