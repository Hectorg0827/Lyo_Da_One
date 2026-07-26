import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const failures = [];

function requireText(source, expected, label) {
  if (!source.includes(expected)) failures.push(`${label}: missing ${JSON.stringify(expected)}`);
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) failures.push(`${label}: forbidden ${JSON.stringify(forbidden)}`);
}

const web = read('web/src/stores/classroom-store.ts');
const webContract = read('web/src/lib/classroom-contract.mjs');
const webSpeech = read('web/src/lib/browser-speech.ts');
const iosClassroom = read('Sources/Services/LivingClassroomService.swift');
const iosTts = read('Sources/Core/Networking/Endpoint.swift');
const iosModels = read('Sources/Models/SDUIModels.swift');
const androidClassroom = read(
  'android/app/src/main/java/com/lyo/app/ui/screens/classroom/ClassroomScreen.kt',
);
const androidVoice = read(
  'android/app/src/main/java/com/lyo/app/ui/screens/classroom/ClassroomVoicePlayer.kt',
);
const androidNavigation = read(
  'android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt',
);

for (const [source, label] of [
  [web, 'Web classroom'],
  [iosTts, 'iOS classroom'],
  [androidVoice, 'Android classroom'],
]) {
  requireText(source, '/api/v1/tts/synthesize', `${label} shared voice endpoint`);
}

requireText(webContract, 'language:', 'Web locale contract');
requireText(web, 'comp.language_code', 'Web component locale');
requireText(iosClassroom, 'component.languageCode ?? "auto"', 'iOS component locale');
requireText(androidClassroom, '"language_code"', 'Android component locale');

requireText(web, 'learnerTakesFloor()', 'Web interruption contract');
requireText(iosClassroom, 'bargeIn()', 'iOS interruption contract');
requireText(androidClassroom, 'learnerTakesFloor()', 'Android interruption contract');

rejectText(web, 'resumePlayer(); // a classmate jumps in', 'Web unattended continuation');
rejectText(iosClassroom, 'startHesitationWatch(for: component)', 'iOS timed learner interruption');
rejectText(
  read('Sources/Views/Classroom/ActiveLessonView.swift'),
  'unlockAndAdvanceSoftly',
  'iOS answer auto-advance',
);

requireText(iosModels, 'case inputField = "InputField"', 'iOS application evidence UI');
requireText(webSpeech, 'SpeechRecognition', 'Web learner voice input');
requireText(androidClassroom, '"InputField"', 'Android application evidence UI');
requireText(androidClassroom, 'RecognizerIntent.ACTION_RECOGNIZE_SPEECH', 'Android learner voice input');
requireText(androidNavigation, 'ClassroomScreen(', 'Android live classroom route');

if (failures.length) {
  console.error('AI Classroom parity gate failed:\n');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log('AI Classroom voice, locale, interruption, and learner-gating parity verified.');
