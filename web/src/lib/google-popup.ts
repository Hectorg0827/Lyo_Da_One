import type { Auth } from '@firebase/auth';
import { firebaseWebConfig } from './google-sign-in.mjs';

// Next inlines NEXT_PUBLIC_* only where each is written out in full.
export const googleSignInConfig = firebaseWebConfig({
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
});

type Firebase = { auth: Auth; sdk: typeof import('@firebase/auth') };
let loading: Promise<Firebase> | null = null;
let loaded: Firebase | null = null;

/**
 * Loads Firebase. The Google button calls this when it appears, so that a tap
 * can open Google's window at once: browsers block windows opened later.
 */
export function prepareGoogleSignIn(): Promise<Firebase> {
  const config = googleSignInConfig;
  if (!config) return Promise.reject(new Error('Google sign-in is not configured'));
  loading ??= Promise.all([import('@firebase/app'), import('@firebase/auth')])
    .then(([app, sdk]) => {
      // Kept in memory only: the LYO session is the API's tokens, not Firebase's.
      const auth = sdk.initializeAuth(app.initializeApp(config), {
        persistence: sdk.inMemoryPersistence,
        popupRedirectResolver: sdk.browserPopupRedirectResolver,
      });
      loaded = { auth, sdk };
      return loaded;
    })
    .catch((error) => {
      loading = null;
      throw error;
    });
  return loading;
}

/** Opens Google's window and returns Firebase's ID token for the chosen account. */
export async function googleIdToken(): Promise<string> {
  const { auth, sdk } = loaded ?? (await prepareGoogleSignIn());
  const provider = new sdk.GoogleAuthProvider();
  provider.setCustomParameters({ prompt: 'select_account' });
  const result = await sdk.signInWithPopup(auth, provider);
  try {
    return await result.user.getIdToken();
  } finally {
    await sdk.signOut(auth);
  }
}
