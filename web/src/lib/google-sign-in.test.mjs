import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { firebaseWebConfig, googleServerFailure, googleWindowFailure } from './google-sign-in.mjs';

const settings = { apiKey: 'AIza-key', authDomain: 'lyo-app.firebaseapp.com', projectId: 'lyo-app', appId: '1:2:web:3' };

test('the Google button needs all four Firebase settings, trimmed', () => {
  assert.deepEqual(firebaseWebConfig({ ...settings, apiKey: ' AIza-key ' }), settings);
  for (const missing of Object.keys(settings)) {
    assert.equal(firebaseWebConfig({ ...settings, [missing]: '' }), null, `${missing} missing`);
    assert.equal(firebaseWebConfig({ ...settings, [missing]: undefined }), null, `${missing} undefined`);
  }
  assert.equal(firebaseWebConfig(undefined), null);
});

test("closing Google's window says nothing; other window failures say what to do", () => {
  assert.equal(googleWindowFailure('auth/popup-closed-by-user'), null);
  assert.equal(googleWindowFailure('auth/cancelled-popup-request'), null);
  assert.match(googleWindowFailure('auth/popup-blocked'), /Allow pop-ups/);
  assert.match(googleWindowFailure('auth/unauthorized-domain'), /not set up for this website/);
  assert.match(googleWindowFailure('auth/network-request-failed'), /connection/);
  assert.match(googleWindowFailure(undefined), /log in with your email/);
});

test("the API's refusals become plain messages", () => {
  assert.match(googleServerFailure(401, 'Confirm your email address before signing in with it'), /confirmed this email/);
  assert.match(googleServerFailure(401, 'Token verification failed'), /couldn't confirm your Google account/);
  assert.match(googleServerFailure(429, ''), /Too many attempts/);
  assert.match(googleServerFailure(503, ''), /not available right now/);
  assert.match(googleServerFailure(0, null), /connection/);
});

test('login and sign-up offer Google, which signs in through POST /auth/firebase', () => {
  const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
  const login = read('../app/auth/login/page.tsx');
  const signup = read('../app/auth/signup/page.tsx');
  const button = read('../components/auth/GoogleSignInButton.tsx');
  const browser = read('./google-popup.ts');
  const api = read('./api.ts');
  assert.ok(login.includes('<GoogleSignInButton onError={setError} />'));
  assert.ok(!login.includes('Social sign-in will appear'), 'the login page no longer says social sign-in is missing');
  assert.ok(signup.includes('<GoogleSignInButton') && signup.includes('By continuing with Google, you agree'));
  assert.ok(button.includes('if (!googleSignInConfig) return null;'), 'no button without the Firebase settings');
  assert.ok(button.includes('prepareGoogleSignIn()'), 'Firebase loads when the button appears, so a tap opens the window at once');
  assert.ok(browser.includes('loaded ?? (await prepareGoogleSignIn())'));
  assert.ok(browser.includes('persistence: sdk.inMemoryPersistence'), 'Firebase keeps no session of its own');
  for (const name of ['API_KEY', 'AUTH_DOMAIN', 'PROJECT_ID', 'APP_ID']) {
    assert.ok(browser.includes(`process.env.NEXT_PUBLIC_FIREBASE_${name}`), `${name} is written out for Next to inline`);
  }
  assert.ok(api.includes("'/auth/firebase'") && api.includes('JSON.stringify({ id_token: idToken })'));
});
