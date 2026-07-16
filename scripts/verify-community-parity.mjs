import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const contract = JSON.parse(read('community-parity.json'));
const failures = [];

const expectIncludes = (file, marker, label = marker) => {
  const contents = read(file);
  if (!contents.toLowerCase().includes(marker.toLowerCase())) {
    failures.push(`${file}: missing ${label}`);
  }
};

for (const [platform, entries] of Object.entries(contract.evidence)) {
  for (const entry of entries) {
    for (const marker of entry.markers) {
      expectIncludes(entry.file, marker, `${platform} evidence marker "${marker}"`);
    }
  }
}

const tokens = JSON.parse(read('design-tokens.json'));
const expectedTokens = {
  primary: tokens.color.brand.primary,
  secondary: tokens.color.brand.secondary,
  background: tokens.color.surface.background,
  surface: tokens.color.surface.surface,
  textPrimary: tokens.color.text.primary,
  textSecondary: tokens.color.text.secondary,
};

for (const [name, expected] of Object.entries(contract.design)) {
  if (expected.toUpperCase() !== expectedTokens[name].toUpperCase()) {
    failures.push(`community-parity.json design.${name} does not match design-tokens.json`);
  }
}

const normalized = (hex) => hex.replace('#', '').toLowerCase();
const iosAccent = read('Sources/Resources/Assets.xcassets/LyoAccent.colorset/Contents.json');
for (const component of ['"red" : "0x63"', '"green" : "0x66"', '"blue" : "0xF1"']) {
  if (!iosAccent.includes(component)) failures.push(`iOS LyoAccent is not ${contract.design.primary}`);
}

const androidTheme = read('android/app/src/main/java/com/lyo/app/ui/theme/Theme.kt').toLowerCase();
const webTheme = `${read('web/src/app/globals.css')}\n${read('web/tailwind.config.ts')}`.toLowerCase();
for (const [name, value] of Object.entries(contract.design)) {
  const hex = normalized(value);
  if (!androidTheme.includes(hex)) failures.push(`Android theme missing design.${name} ${value}`);
  if (!webTheme.includes(`#${hex}`)) failures.push(`Web theme missing design.${name} ${value}`);
}

const apiFiles = {
  ios: 'Sources/Core/Networking/Endpoint.swift',
  android: 'android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt',
  web: 'web/src/lib/api.ts',
};

const backendDefaults = {
  ios: read('Sources/Core/Configuration/AppConfig.swift'),
  android: read('android/app/build.gradle.kts'),
  web: read('web/src/lib/api.ts'),
};
for (const [platform, contents] of Object.entries(backendDefaults)) {
  if (!contents.includes(contract.canonicalBackend)) {
    failures.push(`${platform} does not default to canonical backend ${contract.canonicalBackend}`);
  }
}

const postCreationFiles = {
  ios: read('Sources/Models/Community/CommunityPostModels.swift'),
  android: read('android/app/src/main/java/com/lyo/app/ui/screens/community/CommunityScreen.kt'),
  web: read('web/src/components/community/CreatePostModal.tsx'),
};
for (const [platform, contents] of Object.entries(postCreationFiles)) {
  for (const type of contract.postTypes) {
    if (!contents.includes(type)) failures.push(`${platform} post creation missing ${type}`);
  }
}
for (const [platform, file] of Object.entries(apiFiles)) {
  const compact = read(file)
    .toLowerCase()
    .replace(/\\\([^)]*\)/g, '{id}')
    .replace(/\$\{[^}]*\}/g, '{id}')
    .replace(/\{(?:post|group|event|comment)[^}]*\}/g, '{id}')
    .replaceAll('/api/v1', '')
    .replaceAll('"community/', '"/community/');
  for (const endpoint of contract.canonicalEndpoints) {
    const path = endpoint.replace(/\{[^}]+\}/g, '{id}').toLowerCase();
    if (!compact.includes(path)) failures.push(`${platform} API missing ${endpoint}`);
  }
}

const communityUi = [
  'Sources/Views/Community/CommunityView.swift',
  'Sources/Views/Community/CreateCommunityItemSheet.swift',
  'Sources/Views/Community/CommentsView.swift',
  'Sources/ViewModels/CommunityViewModel.swift',
  'android/app/src/main/java/com/lyo/app/ui/screens/community/CommunityScreen.kt',
  'android/app/src/main/java/com/lyo/app/ui/screens/community/GroupsScreen.kt',
  'web/src/app/(main)/community/page.tsx',
  'web/src/app/(main)/community/groups/page.tsx',
  'web/src/components/community/CreatePostModal.tsx',
  'web/src/components/community/PostCard.tsx',
  'web/src/app/(main)/community/[postId]/page.tsx',
];
const forbidden = ['coming soon', 'would load here', '/mock-image.jpg', "alert('create group"];
for (const file of communityUi) {
  const contents = read(file).toLowerCase();
  for (const phrase of forbidden) {
    if (contents.includes(phrase)) failures.push(`${file}: forbidden fake UI "${phrase}"`);
  }
}

const iosCommunityModel = read('Sources/ViewModels/CommunityViewModel.swift');
for (const legacyExclusive of [
  'privateLesson',
  'educationalCenter',
  'marketplace',
  'showNearbyPlaces',
  'fetchRealWorldCenters',
]) {
  if (iosCommunityModel.includes(legacyExclusive)) {
    failures.push(`iOS active Community model still exposes platform-exclusive ${legacyExclusive}`);
  }
}

if (failures.length > 0) {
  console.error('Community parity gate failed:\n');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(`Community parity ${contract.version}: iOS, Android, and web evidence verified.`);
