import { readFileSync } from 'node:fs';

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

function requireText(source, expected, label) {
  if (!source.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

const settings = read('android/app/src/main/java/com/lyo/app/ui/screens/settings/SettingsScreen.kt');

requireText(settings, 'ApiClient.api.updateProfile', 'Android profile update');
requireText(settings, '.onFailure { error ->', 'Android profile update error handling');
requireText(settings, 'accountError = error.localizedMessage', 'Android visible profile error');
requireText(settings, 'Settings.ACTION_APP_NOTIFICATION_SETTINGS', 'Android notification settings');
requireText(settings, 'Settings.EXTRA_APP_PACKAGE', 'Android notification app target');
requireText(settings, 'BuildConfig.VERSION_NAME', 'Android real version');
requireText(settings, 'showLogoutConfirmation', 'Android logout confirmation');
requireText(settings, 'AlertDialog(', 'Android logout confirmation dialog');

for (const forbidden of [
  'var notifLikes',
  'var notifComments',
  'var notifFollows',
  'var notifAchievements',
  'var notifWeeklyDigest',
  'var publicProfile',
  'var onlineStatus',
  'Switch(',
  '"1.0.0"',
]) {
  rejectText(settings, forbidden, 'Android Settings honesty');
}

console.log('Android Settings exposes only actionable controls and real application metadata.');
