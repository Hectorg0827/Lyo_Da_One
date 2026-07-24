import { readFileSync } from 'node:fs';

const session = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/data/Session.kt', import.meta.url),
  'utf8',
);
const navigation = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt', import.meta.url),
  'utf8',
);
const login = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/auth/LoginScreen.kt', import.meta.url),
  'utf8',
);
const signup = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/auth/SignupScreen.kt', import.meta.url),
  'utf8',
);
const tokens = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/data/TokenManager.kt', import.meta.url),
  'utf8',
);

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

for (const [source, expected, label] of [
  [session, 'var hydrationError by mutableStateOf<String?>(null)', 'recoverable hydration state'],
  [session, 'if (error is HttpException && error.code() in setOf(401, 403))', 'authorization-only credential clearing'],
  [session, 'hydrationError = hydrationFailureMessage(error)', 'transient hydration recovery'],
  [session, 'private suspend fun establishSession(', 'atomic session establishment'],
  [session, 'val resolvedUser = providedUser ?: ApiClient.api.me()', 'verified user resolution'],
  [session, 'clearLocalSession()\n            throw error', 'partial-session rollback'],
  [navigation, 'Session.isLoading -> SessionLoadingScreen()', 'startup hydration gate'],
  [navigation, 'Session.hydrationError != null -> SessionRecoveryScreen(', 'recoverable startup failure'],
  [navigation, 'startDestination = if (Session.isAuthenticated) Routes.HOME else Routes.LOGIN', 'verified navigation decision'],
  [navigation, 'scope.launch { Session.hydrate() }', 'session retry action'],
  [navigation, 'scope.launch { Session.logout() }', 'local sign-out recovery'],
  [login, 'private fun loginFailureMessage(error: Throwable)', 'classified login failures'],
  [login, 'is IOException -> "Check your connection and try signing in again."', 'login network failure'],
  [login, '429 -> "Too many login attempts.', 'login rate-limit failure'],
  [signup, 'private fun signupFailureMessage(error: Throwable)', 'classified signup failures'],
  [signup, 'is IOException -> "Check your connection and try creating the account again."', 'signup network failure'],
  [signup, '400, 409, 422 ->', 'signup validation/conflict failure'],
  [tokens, 'editor.remove(KEY_REFRESH)', 'stale refresh-token removal'],
]) {
  requireText(source, expected, label);
}

rejectText(navigation, 'TokenManager.hasToken', 'navigation must not trust token presence');
rejectText(session, 'catch (e: Exception) {\n            TokenManager.clear()', 'transient hydration must not clear credentials');
rejectText(login, 'catch (e: Exception) {\n                error = "Invalid email or password."', 'login must not misclassify every failure');
rejectText(signup, 'catch (e: Exception) {\n                error = "Could not create your account.', 'signup must not hide failure type');

const hydrateUser = session.indexOf('val resolvedUser = ApiClient.api.me()');
const hydrateAuth = session.indexOf('isAuthenticated = true', hydrateUser);
if (hydrateUser < 0 || hydrateAuth < hydrateUser) {
  throw new Error('Hydration may authenticate only after the user record resolves.');
}

const establishStart = session.indexOf('private suspend fun establishSession(');
const establishUser = session.indexOf('val resolvedUser = providedUser ?: ApiClient.api.me()', establishStart);
const establishAuth = session.indexOf('isAuthenticated = true', establishUser);
if (establishStart < 0 || establishUser < establishStart || establishAuth < establishUser) {
  throw new Error('Login/signup may authenticate only after the user record resolves.');
}

console.log('Android authentication gates navigation on a verified, atomic, recoverable session.');
