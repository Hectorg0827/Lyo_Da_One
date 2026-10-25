// Continue with Google on every platform: Google confirms the account through
// Firebase, and the API's POST /auth/firebase is the only way to a LYO session.
// No platform may fake a sign-in (the iOS Apple button used to) or fall back
// to a password anyone could work out (iOS used "Google_<firebase uid>_Auth").
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const failures = [];
const need = (source, text, label) => { if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`); };
const forbid = (source, text, label) => { if (source.includes(text)) failures.push(`${label}: forbidden ${JSON.stringify(text)}`); };

// iOS
const authService = read('Sources/Services/AuthService.swift');
const loginView = read('Sources/Views/Auth/LoginView.swift');
const onboarding = read('Sources/Views/Auth/OnboardingView.swift');
const repository = read('Sources/Services/LyoRepository.swift');
need(authService, 'func signInWithGoogle() async', 'iOS Google sign-in finishes before the screen checks it');
need(authService, 'repository.loginWithGoogle(idToken: firebaseIdToken)', 'iOS sends Firebase\'s token to the API');
need(authService, 'catch GIDSignInError.canceled', 'iOS closing Google\'s sheet is not an error');
need(repository, 'Endpoints.Auth.firebase(idToken: idToken)', 'iOS calls POST /auth/firebase');
for (const [source, label] of [[authService, 'AuthService'], [loginView, 'LoginView'], [onboarding, 'OnboardingView']]) {
  forbid(source, 'Google_\\(', `iOS ${label} must not derive a password from the Firebase uid`);
  forbid(source, 'performLocalAuth', `iOS ${label} must not sign in without the API`);
  forbid(source, 'handleAppleSignIn', `iOS ${label} must not fake Sign in with Apple`);
  forbid(source, 'SignInWithAppleButton', `iOS ${label} has no Apple Developer account for Sign in with Apple yet`);
}
need(loginView, 'await authService.signInWithGoogle()', 'iOS login waits for Google');
need(onboarding, 'await authService.signInWithGoogle()', 'iOS onboarding waits for Google');
forbid(onboarding, 'DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {\n                if authService.isAuthenticated', 'iOS onboarding must not guess when Google finished');

// Android
const session = read('android/app/src/main/java/com/lyo/app/data/Session.kt');
const service = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
const dtos = read('android/app/src/main/java/com/lyo/app/data/api/Dtos.kt');
const google = read('android/app/src/main/java/com/lyo/app/ui/screens/auth/GoogleSignIn.kt');
const androidLogin = read('android/app/src/main/java/com/lyo/app/ui/screens/auth/LoginScreen.kt');
const androidSignup = read('android/app/src/main/java/com/lyo/app/ui/screens/auth/SignupScreen.kt');
need(service, '@POST("auth/firebase")', 'Android calls POST /auth/firebase');
need(dtos, 'data class FirebaseLoginRequest(@SerializedName("id_token") val idToken: String)', 'Android sends id_token');
const firebaseLogin = session.slice(session.indexOf('suspend fun loginWithFirebase('));
need(firebaseLogin.slice(0, 600), 'establishSession(', 'Android Google sign-in uses the verified, atomic session');
need(google, 'if (FirebaseApp.getApps(context).isEmpty()) return null', 'Android hides Google until Firebase is configured');
need(google, '?: return', 'Android shows no button without the web client ID');
need(google, 'auth.signOut()', 'Android Firebase keeps no session of its own');
need(androidLogin, 'GoogleSignInSection(', 'Android login offers Google');
need(androidSignup, 'GoogleSignInSection(', 'Android sign-up offers Google');

// Web
const webLogin = read('web/src/app/auth/login/page.tsx');
const webSignup = read('web/src/app/auth/signup/page.tsx');
const webApi = read('web/src/lib/api.ts');
need(webLogin, '<GoogleSignInButton', 'web login offers Google');
need(webSignup, '<GoogleSignInButton', 'web sign-up offers Google');
need(webApi, "'/auth/firebase'", 'web calls POST /auth/firebase');

if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}
console.log('Continue with Google reaches a LYO session only through POST /auth/firebase, on web, iOS and Android.');
