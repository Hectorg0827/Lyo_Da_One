#!/usr/bin/env node
/**
 * Canonical conversational-voice contract.
 *
 * Voice is allowed to change input/output transport and presentation only.
 * It must not create a second AI router, memory, learner state, or voice-only
 * model path. All three clients must ultimately send a normal Lyo2 Chat turn
 * carrying response_channel=voice.
 */
import fs from 'node:fs';

const contracts = [
  {
    name: 'Web sends voice through canonical Chat',
    path: 'web/src/lib/api.ts',
    needles: [
      "responseChannel: 'text' | 'voice' = 'text'",
      'response_channel: responseChannel',
      '/api/v1/lyo2/chat/stream',
      '/api/v1/tts/synthesize/stream',
    ],
  },
  {
    name: 'Web continuous voice owns only transport',
    path: 'web/src/hooks/useChatVoiceSession.ts',
    needles: [
      'useChatStore',
      'onFinalUtterance',
      'cancelActiveResponse',
      'api.tts.stream',
      'playSpeechResponse',
      'response_channel=voice',
    ],
    forbidden: ['/voice/ai', '/api/v1/voice/chat'],
  },
  {
    name: 'Web composer enters canonical voice channel',
    path: 'web/src/components/chat/ChatInputBar.tsx',
    needles: [
      'useChatVoiceSession',
      "responseChannel: 'voice'",
      'voice.bargeIn()',
    ],
  },
  {
    name: 'iOS request carries presentation channel',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: ['responseChannel', 'response_channel'],
  },
  {
    name: 'iOS forces spoken turns through Lyo2 Chat',
    path: 'Sources/Services/ChatRouter.swift',
    needles: [
      'responseChannel == "voice"',
      'handleDeepPath(',
      'responseChannel: responseChannel',
    ],
  },
  {
    name: 'iOS voice loop feeds canonical Chat',
    path: 'Sources/ViewModels/LyoAIViewModel.swift',
    needles: [
      'sttService.onUtteranceReady',
      'unifiedChat.cancelCurrentResponse()',
      'responseChannel: shouldResumeListening ? "voice" : "text"',
    ],
    forbidden: ['AudioStreamManager.shared.startLiveMode'],
  },
  {
    name: 'Android sends voice through Lyo2 Chat',
    path: 'android/app/src/main/java/com/lyo/app/data/api/ChatStreamClient.kt',
    needles: [
      'responseChannel: String = "text"',
      '"response_channel" to responseChannel',
      'api/v1/lyo2/chat/stream',
    ],
  },
  {
    name: 'Android voice controller owns STT/TTS only',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatVoiceController.kt',
    needles: [
      'SpeechRecognizer',
      'TextToSpeech',
      'onFinalUtterance',
      'onBargeIn',
      'responseReady',
    ],
    forbidden: ['/voice/ai', '/api/v1/voice/chat', 'OpenAI', 'Gemini'],
  },
  {
    name: 'Android screen submits the canonical voice turn',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt',
    needles: [
      'send(utterance, responseChannel = "voice")',
      'voiceController.bargeIn()',
      'streamJob?.cancel()',
    ],
  },
];

const failures = [];
for (const contract of contracts) {
  if (!fs.existsSync(contract.path)) {
    failures.push(`${contract.name}: missing ${contract.path}`);
    continue;
  }
  const source = fs.readFileSync(contract.path, 'utf8');
  for (const needle of contract.needles ?? []) {
    if (!source.includes(needle)) failures.push(`${contract.name}: missing ${needle}`);
  }
  for (const forbidden of contract.forbidden ?? []) {
    if (source.includes(forbidden)) failures.push(`${contract.name}: forbidden ${forbidden}`);
  }
}

if (failures.length) {
  console.error('Conversational voice contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(
  'Conversational voice contract: Web, iOS, and Android all layer STT/TTS and ' +
  'barge-in over canonical Lyo2 Chat; no client introduces a separate voice AI.'
);
