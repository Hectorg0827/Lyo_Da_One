// Continue with Google on every platform: Google confirms the account through
// Firebase, and the API's POST /auth/firebase is the only way to a LYO session.
// No platform may fake a sign-in (the iOS Apple button once did) or fall back
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
}
// Sign in with Apple (App Store guideline 4.8: required wherever Google is
// offered) is real: Apple's token goes through Firebase with a hashed nonce,
// and the API's POST /auth/firebase is still the only way to a LYO session.
need(authService, 'request.nonce = Self.sha256(nonce)', 'iOS Apple request carries a hashed nonce');
need(authService, 'OAuthProvider.appleCredential(withIDToken: appleIdToken', 'iOS Apple sign-in goes through Firebase');
need(authService, 'repository.loginWithFirebase(idToken: firebaseIdToken)', 'iOS Apple sends Firebase\'s token to the API');
need(repository, 'try await loginWithFirebase(idToken: idToken)', 'iOS Google and Apple share one POST /auth/firebase exchange');
need(loginView, 'SignInWithAppleButton(', 'iOS login offers Sign in with Apple next to Google');
need(loginView, 'await authService.finishAppleSignIn(result)', 'iOS login waits for Apple');
need(read('Lyo.entitlements'), '<key>com.apple.developer.applesignin</key>', 'iOS entitlement for Sign in with Apple');
// The Google client the app signs in with must belong to the Firebase project
// (lyo-app) that issues its tokens; one from another project is refused.
const plistValue = (source, key) => source.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]*)</string>`))?.[1];
const firebasePlist = read('Sources/Resources/GoogleService-Info.plist');
const infoPlist = read('Sources/Resources/Info.plist');
const clientId = plistValue(firebasePlist, 'CLIENT_ID') ?? '';
if (plistValue(firebasePlist, 'PROJECT_ID') !== 'lyo-app') failures.push('iOS GoogleService-Info.plist is not project lyo-app');
if (plistValue(firebasePlist, 'BUNDLE_ID') !== 'com.lyo.app') failures.push('iOS GoogleService-Info.plist is not for com.lyo.app');
if (!clientId.startsWith(`${plistValue(firebasePlist, 'GCM_SENDER_ID')}-`)) failures.push(`iOS CLIENT_ID ${clientId} is from another Google project than lyo-app`);
if (plistValue(infoPlist, 'GIDClientID') !== clientId) failures.push('iOS Info.plist GIDClientID differs from GoogleService-Info.plist CLIENT_ID');
need(infoPlist, `<string>${plistValue(firebasePlist, 'REVERSED_CLIENT_ID')}</string>`, 'iOS Info.plist URL scheme for Google\'s sign-in redirect');
if (read('Sources/Resources/GoogleService-Info (2).plist') !== firebasePlist) failures.push('iOS GoogleService-Info (2).plist differs from GoogleService-Info.plist');
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
console.log('Continue with Google (web, iOS, Android) and Sign in with Apple (iOS) reach a LYO session only through POST /auth/firebase.');
