#!/usr/bin/env node
/**
 * Conversational voice must remain a transport/delivery layer over canonical Chat.
 *
 * This contract intentionally forbids a second voice AI path. Every platform
 * must send voice turns through the same Lyo2 Chat stream and mark
 * state_summary.voice_session.active=true so the backend interaction contract
 * changes delivery style without changing intent, memory, tools or pedagogy.
 */
import fs from 'node:fs';

const failures = [];
const contracts = [
  {
    name: 'Web voice uses canonical Chat store',
    path: 'web/src/components/chat/ConversationalVoiceLayer.tsx',
    needles: [
      'sendMessage(transcript, [], { voiceSession: true })',
      'interruptGeneration()',
      'api.tts.synthesizeStream',
      'createSpeechRecognition',
      'bargeIn',
    ],
    forbidden: ['/voice/chat', '/realtime/voice'],
  },
  {
    name: 'Web transport marks voice session',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      "voice_session: { active: true, transport: 'client_stt_tts' }",
      'interruptGeneration',
      'activeStreamController?.abort()',
    ],
  },
  {
    name: 'iOS ChatRouter keeps voice on Lyo2',
    path: 'Sources/Services/ChatRouter.swift',
    needles: [
      'voiceSession: Bool = false',
      'if voiceSession',
      '"voice_session"',
      '"client_stt_tts"',
      'handleDeepPath',
    ],
    forbidden: ['AudioStreamManager.shared.startLiveMode'],
  },
  {
    name: 'iOS live mode aliases Unified Chat voice loop',
    path: 'Sources/ViewModels/LyoAIViewModel.swift',
    needles: [
      'func startLiveMode()',
      'voiceLoopActive = true',
      'startListening()',
      'voiceSession: shouldResumeListening',
      'unifiedChat.interruptCurrentResponse()',
    ],
    forbidden: [
      'await AudioStreamManager.shared.startLiveMode',
      'AudioStreamManager.shared.stopLiveMode()',
    ],
  },
  {
    name: 'iOS audio is full duplex',
    path: 'Sources/Services/VoiceInputService.swift',
    needles: ['.playAndRecord', '.voiceChat', '.defaultToSpeaker'],
  },
  {
    name: 'Android voice uses canonical ChatStream',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt',
    needles: [
      'SpeechRecognizer.createSpeechRecognizer',
      'voiceSession = voiceConversation',
      'onBeginningOfSpeech',
      'streamJob?.cancel()',
      'engine.speak',
    ],
    forbidden: ['/voice/chat', '/realtime/voice'],
  },
  {
    name: 'Android transport marks voice session',
    path: 'android/app/src/main/java/com/lyo/app/data/api/ChatStreamClient.kt',
    needles: [
      'voiceSession: Boolean = false',
      '"voice_session"',
      '"client_stt_tts"',
      '"api/v1/lyo2/chat/stream"',
    ],
  },
];

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
    if (source.includes(forbidden)) failures.push(`${contract.name}: forbidden separate voice path ${forbidden}`);
  }
}

const backendContract = '../lyobackendjune/lyo_app/teaching_runtime/interaction_contract.py';
if (fs.existsSync(backendContract)) {
  const source = fs.readFileSync(backendContract, 'utf8');
  for (const needle of ['class DeliveryMode', 'VOICE = "voice"', 'voice_mode: bool = False', 'Delivery:']) {
    if (!source.includes(needle)) failures.push(`Backend voice contract missing ${needle}`);
  }
}

if (failures.length) {
  console.error('Conversational voice contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(
  'Conversational voice contract: Web, iOS and Android use canonical Chat ' +
  'with STT/TTS transport, voice_session delivery metadata and barge-in; no separate voice AI path.'
);
