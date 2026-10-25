/**
 * Continue with Google: Google confirms who the learner is through Firebase
 * (project lyo-app), and the API exchanges Firebase's ID token for a LYO
 * session at POST /auth/firebase.
 *
 * The button shows only when the website was built with the Firebase web
 * app's settings (NEXT_PUBLIC_FIREBASE_*); these are public identifiers,
 * not secrets.
 */

/** The Firebase settings, or null when any required one is missing. */
export function firebaseWebConfig(env) {
  const config = {
    apiKey: (env?.apiKey ?? '').trim(),
    authDomain: (env?.authDomain ?? '').trim(),
    projectId: (env?.projectId ?? '').trim(),
    appId: (env?.appId ?? '').trim(),
  };
  return Object.values(config).every(Boolean) ? config : null;
}

/** What to tell the learner when Google's window fails; null when they closed it themselves. */
export function googleWindowFailure(code) {
  switch (code) {
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
    case 'auth/user-cancelled':
      return null;
    case 'auth/popup-blocked':
      return 'Your browser blocked the Google window. Allow pop-ups for this site and try again.';
    case 'auth/unauthorized-domain':
    case 'auth/operation-not-allowed':
      return 'Google sign-in is not set up for this website yet. Log in with your email for now.';
    case 'auth/network-request-failed':
      return 'Could not reach Google. Check your connection and try again.';
    default:
      return "Google sign-in didn't work. Try again, or log in with your email.";
  }
}

/** What to tell the learner when the API refuses Google's confirmation. */
export function googleServerFailure(status, serverMessage) {
  if (status === 401) {
    return serverMessage && /confirm/i.test(serverMessage)
      ? 'Google has not confirmed this email address yet. Confirm it with Google, then try again.'
      : "We couldn't confirm your Google account. Try again.";
  }
  if (status === 429) return 'Too many attempts. Please wait a few minutes and try again.';
  if (status === 503) return 'Google sign-in is not available right now. Log in with your email for now.';
  return "Google sign-in didn't work. Check your connection and try again.";
}
