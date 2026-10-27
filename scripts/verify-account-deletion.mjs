import { readFileSync } from 'node:fs';

// Delete account must behave the same on every client, following the
// contract agreed with the backend: DELETE /auth/me with the bearer token and
// no body; 200 or 204 means deleted. Local data is cleared only after that
// success, and the confirmation says plainly that deletion is permanent.
//
// Web and Android are checked here. Add the iPhone app (Sources/) once its
// Delete account lands, with the same rules.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const failures = [];

function requireText(source, expected, label) {
  if (!source.includes(expected)) failures.push(`${label}: missing ${JSON.stringify(expected)}`);
}

function requireOrder(source, first, second, label) {
  const a = source.indexOf(first);
  const b = source.indexOf(second, a + 1);
  if (a < 0 || b < 0) failures.push(`${label}: expected ${JSON.stringify(first)} before ${JSON.stringify(second)}`);
}

const PERMANENT = 'This is permanent and cannot be undone.';

// ── Web ──
const webContract = read('web/src/lib/account-deletion.mjs');
const webApi = read('web/src/lib/api.ts');
const webStore = read('web/src/stores/auth-store.ts');
const webSettings = read('web/src/app/(main)/settings/page.tsx');

requireText(webContract, "ACCOUNT_DELETION_METHOD = 'DELETE'", 'Web method');
requireText(webContract, "ACCOUNT_DELETION_PATH = '/auth/me'", 'Web path');
requireText(webContract, 'status === 200 || status === 204', 'Web success statuses');
requireText(webContract, 'Authorization: `Bearer ${token}`', 'Web bearer token');
if (/requestAccountDeletion[\s\S]*?body\s*:/.test(webContract)) failures.push('Web deletion request must not send a body');
requireText(webApi, 'requestAccountDeletion({', 'Web API client uses the shared contract');
requireOrder(webStore, 'if (result.ok)', 'clearLocalAccountData(window.localStorage)', 'Web clears local data only after success');
requireText(webSettings, PERMANENT, 'Web confirmation wording');
requireText(webSettings, "router.replace('/auth/login')", 'Web returns to login');

// ── Android ──
const androidApi = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
const androidContract = read('android/app/src/main/java/com/lyo/app/data/AccountDeletion.kt');
const androidSession = read('android/app/src/main/java/com/lyo/app/data/Session.kt');
const androidSettings = read('android/app/src/main/java/com/lyo/app/ui/screens/settings/SettingsScreen.kt');

requireText(androidApi, '@DELETE("auth/me")\n    suspend fun deleteAccount(): Response<Unit>', 'Android endpoint (DELETE auth/me, no body)');
requireText(androidContract, 'code == 200 || code == 204', 'Android success statuses');
requireOrder(androidSession, 'if (!accountDeletionSucceeded(code)) return', 'clearLocalSession()\n        return null', 'Android clears local data only after success');
requireText(androidSettings, PERMANENT, 'Android confirmation wording');
requireText(androidSettings, 'showDeleteConfirmation = true', 'Android asks before deleting');
requireText(androidSettings, 'nav.navigate(Routes.LOGIN) { popUpTo(0) }', 'Android returns to login');

// ── Legal pages the stores and the apps link to ──
for (const page of ['privacy', 'terms', 'support']) {
  requireText(androidSettings, `https://lyoai.app/${page}`, `Android links /${page}`);
  try {
    read(`web/src/app/${page}/page.tsx`);
  } catch {
    failures.push(`Web /${page} page is missing`);
  }
}

if (failures.length) {
  console.error('Account deletion parity failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('Delete account follows DELETE /auth/me on web and Android, confirms first, and clears data only after success.');
