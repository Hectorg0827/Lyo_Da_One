#!/usr/bin/env node
/**
 * Conversational voice parity contract.
 *
 * Voice is a delivery/input layer over canonical Chat. These assertions exist
 * specifically to prevent a future "voice AI" from bypassing the interaction
 * contract, learner state, source grounding or cross-surface tools.
 */
import fs from 'node:fs';

const contracts = [
  {
    name: 'Web sends voice through canonical Chat stream',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      "deliveryMode?: 'text' | 'voice'",
      'options.deliveryMode',
      'voiceTurnId',
      'interruptActiveResponse',
      "chunk.type === 'voice_delivery'",
      "chunk.type === 'voice_turn'",
    ],
  },
  {
    name: 'Web voice controller supports turn-taking and barge-in',
    path: 'web/src/hooks/use-conversational-voice.ts',
    needles: [
      "deliveryMode: 'voice'",
      'interruptActiveResponse',
      'onspeechstart',
      'SILENCE_COMMIT_MS',
      'api.tts.streamSpeech',
      "setPhase('speaking')",
      "setPhase('listening')",
    ],
  },
  {
    name: 'Web mic starts a conversation, not dictation',
    path: 'web/src/components/chat/ChatInputBar.tsx',
    needles: [
      'useConversationalVoice',
      'Start voice conversation',
      'talk to interrupt',
    ],
    forbidden: ['toggleDictation', 'Dictate your message'],
  },
  {
    name: 'iOS canonical request carries voice delivery metadata',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: ['deliveryMode', 'voiceTurnId', 'VoiceDeliveryEvent', 'VoiceTurnEvent'],
  },
  {
    name: 'iOS voice reuses Lyo2 canonical Chat',
    path: 'Sources/Services/UnifiedChatService.swift',
    needles: [
      'deliveryMode: "voice"',
      'sendMessageLyo2',
      'onVoiceDelivery',
      'cancelActiveResponse',
    ],
  },
  {
    name: 'iOS old separate live AI is retired from the Chat view model',
    path: 'Sources/ViewModels/LyoAIViewModel.swift',
    needles: [
      'Conversational Voice Control',
      'serverVoiceDeliveryExpected',
      'scheduleVoiceTurnCommit',
      'unifiedChat.cancelActiveResponse',
    ],
    forbidden: [
      'AudioStreamManager.shared.startLiveMode',
      'AudioStreamManager.shared.stopLiveMode',
    ],
  },
  {
    name: 'Android canonical stream carries voice metadata',
    path: 'android/app/src/main/java/com/lyo/app/data/api/ChatStreamClient.kt',
    needles: [
      'deliveryMode: String = "text"',
      '"delivery_mode" to deliveryMode',
      'ChatStreamEvent.VoiceDelivery',
      'ChatStreamEvent.VoiceTurn',
    ],
  },
  {
    name: 'Android turn-taking controller supports interruption',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ConversationalVoiceController.kt',
    needles: [
      'onBargeIn',
      'onUtterance',
      'SpeechRecognizer',
      'Phase.SPEAKING',
      'Phase.THINKING',
      'Phase.LISTENING',
    ],
  },
  {
    name: 'Android Chat sends voice back through the normal stream',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt',
    needles: [
      'deliveryMode = if (voice) "voice" else "text"',
      'voiceTurnId = voiceTurnId',
      'voiceController.speak',
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
  'Conversational voice contract: Web, iOS and Android all reuse canonical Chat, ' +
  'preserve interaction-contract routing, and expose interruptible turn-taking.'
);
