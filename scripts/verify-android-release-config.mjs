import { readFileSync } from 'node:fs';

// The Play Store build must sign with a key that never enters git, talk to
// production unless told otherwise, and keep the JSON models Gson reads.
// Test builds must be able to reach staging. See android/RELEASE.md and
// docs/STAGING.md.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const failures = [];
const need = (source, text, label) => { if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`); };

const gradle = read('android/app/build.gradle.kts');
const ignore = read('android/.gitignore');
const proguard = read('android/app/proguard-rules.pro');

need(gradle, 'rootProject.file("keystore.properties")', 'Signing reads the gitignored keystore.properties');
for (const name of ['LYO_UPLOAD_STORE_FILE', 'LYO_UPLOAD_STORE_PASSWORD', 'LYO_UPLOAD_KEY_ALIAS', 'LYO_UPLOAD_KEY_PASSWORD']) {
  need(gradle, `"${name}"`, 'Signing can come from the environment');
}
if (/(storePassword|keyPassword)\s*=\s*"/.test(gradle)) failures.push('A signing password is written into build.gradle.kts');
need(gradle, 'if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")', 'Release signs only when the key is configured');
need(gradle, 'val productionApiUrl = "https://api.lyoai.app/"', 'Production API address');
need(gradle, 'setting("LYO_API_BASE_URL") ?: productionApiUrl', 'Release defaults to production');
need(gradle, 'setting("LYO_STAGING_API_BASE_URL")', 'Test builds can target staging');
need(gradle, 'create("staging")', 'Staging build type');
need(gradle, 'setting("LYO_VERSION_CODE")', 'versionCode is overridable');
need(gradle, 'setting("LYO_VERSION_NAME")', 'versionName is overridable');
need(gradle, 'if (file("google-services.json").exists()) { apply(plugin = "com.google.gms.google-services") }', 'Firebase plugin stays optional');

for (const pattern of ['keystore.properties', '*.jks', '*.keystore', 'app/google-services.json']) {
  if (!ignore.split('\n').includes(pattern)) failures.push(`android/.gitignore: missing ${pattern}`);
}
for (const pkg of ['data.api', 'data.classroom', 'data.a2ui']) {
  need(proguard, `-keep class com.lyo.app.${pkg}.** { *; }`, 'Minified builds keep Gson models');
}

if (failures.length) {
  console.error('Android release configuration failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log('Android release builds sign from outside git, default to production, keep Gson models, and test builds can target staging.');
