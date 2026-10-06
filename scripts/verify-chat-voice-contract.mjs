#!/usr/bin/env node
/**
 * Conversational voice must remain a transport/delivery layer over canonical Chat.
 *
 * This contract intentionally forbids a second voice AI path. Every platform
 * must send voice turns through the same Lyo2 Chat stream and use the typed
 * top-level voice_session metadata so the backend interaction contract changes
 * delivery style without changing intent, memory, tools or pedagogy.
 */
import fs from 'node:fs';

const failures = [];
const contracts = [
  {
    name: 'Web voice uses canonical Chat store',
    path: 'web/src/components/chat/ConversationalVoiceLayer.tsx',
    needles: [
      'voiceSession: true',
      'voiceInterruptedPreviousTurn:',
      'voiceEndOfTurnDelayMs',
      'interruptGeneration()',
      'api.tts.synthesizeStream',
      'createSpeechRecognition',
      'bargeIn',
      'subscribeVoiceStreamEvents',
      'voiceSegmentQueueRef',
    ],
    forbidden: ['/voice/chat', '/realtime/voice'],
  },
  {
    name: 'Web transport marks voice session',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      "transport: 'client_stt_tts'",
      "delivery: 'segments'",
      'interrupted_previous_turn:',
      'turn_id:',
      'voiceLocale',
      "chunk.type === 'voice_text_segment'",
      'publishVoiceStreamEvent',
      'interruptGeneration',
      'activeStreamController?.abort()',
    ],
  },
  {
    name: 'iOS parses canonical voice delivery events',
    path: 'Sources/Services/Lyo2ChatService.swift',
    needles: [
      'case "voice_text_segment"',
      '.voiceTextSegment',
      'case "voice_ready"',
      '.voiceReady',
      'case "voice_incomplete"',
      'json["spoken_text"]',
    ],
  },
  {
    name: 'iOS stream model carries canonical voice events',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: [
      'case voiceTextSegment',
      'case voiceReady',
      'case voiceIncomplete',
      'spokenText: String?',
    ],
  },
  {
    name: 'iOS ChatRouter keeps voice on Lyo2',
    path: 'Sources/Services/ChatRouter.swift',
    needles: [
      'voiceSession: Bool = false',
      'voiceInterruptedPreviousTurn: Bool = false',
      'voiceTurnId: String? = nil',
      'Lyo2VoiceSessionContext',
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
      'voiceInterruptedPreviousTurn: interruptedPreviousTurn',
      'voiceEndOfTurnDelayNanoseconds(for:',
      'unifiedChat.interruptCurrentResponse()',
      'onVoiceTextSegment',
      'voiceSegmentStreamOpen',
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
      'voiceInterruptedPreviousTurn = interruptedPreviousTurn',
      'voiceTurnId = clientMessageId',
      'EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS',
      'onBeginningOfSpeech',
      'streamJob?.cancel()',
      'chatVoicePlayer.enqueue',
      'chatVoicePlayer.speak',
      'ChatStreamEvent.VoiceSegment',
      'event.spokenText',
      'pendingVoiceUtterances',
    ],
    forbidden: ['/voice/chat', '/realtime/voice'],
  },
  {
    name: 'Android Chat uses shared neural voice with device fallback only',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatVoicePlayer.kt',
    needles: [
      '/api/v1/tts/synthesize/stream',
      'ApiClient.okHttp',
      'MediaPlayer',
      'TextToSpeech',
      'fetchSharedVoice',
      'playDeviceFallback',
      'audio = scope.async',
    ],
    forbidden: ['/voice/chat', '/realtime/voice'],
  },
  {
    name: 'Android transport marks voice session',
    path: 'android/app/src/main/java/com/lyo/app/data/api/ChatStreamClient.kt',
    needles: [
      'voiceSession: Boolean = false',
      'voiceInterruptedPreviousTurn: Boolean = false',
      '"voice_session"',
      '"interrupted_previous_turn"',
      '"turn_id"',
      '"client_stt_tts"',
      '"delivery" to "segments"',
      '"voice_text_segment"',
      '"spoken_text"',
      'ChatStreamEvent.VoiceSegment',
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

const iosModels = 'Sources/Models/Lyo2Models.swift';
if (fs.existsSync(iosModels)) {
  const source = fs.readFileSync(iosModels, 'utf8');
  for (const needle of [
    'struct Lyo2VoiceSessionContext',
    'case voiceSession = "voice_session"',
    'case interruptedPreviousTurn = "interrupted_previous_turn"',
    'case turnId = "turn_id"',
  ]) {
    if (!source.includes(needle)) failures.push(`iOS typed voice contract missing ${needle}`);
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
  'with canonical segment streaming, shared neural TTS, STT transport, voice_session delivery metadata and barge-in; no separate voice AI path.'
);
