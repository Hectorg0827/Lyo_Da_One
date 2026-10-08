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
      "reportVoiceQuality(qualityContext(), 'first_audio'",
      "'false_barge_in'",
      "'barge_in_confirmed'",
      "'mic_speech_started'",
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
      "'stream_disconnected'",
      "'stream_recovered'",
      "'voice_handoff_requested'",
      "'voice_handoff_ready'",
    ],
  },
  {
    name: 'Web voice QA is privacy-bounded and uses canonical telemetry endpoint',
    path: 'web/src/lib/voice-quality.ts',
    needles: [
      'sessionId',
      'turnId',
      'conversationId',
      'detectLanguageFamily',
      'reportVoiceQuality',
    ],
    forbidden: [
      'audio:',
      'transcript:',
    ],
  },
  {
    name: 'Web API reports bounded voice quality',
    path: 'web/src/lib/api.ts',
    needles: [
      'reportVoiceQuality',
      "'/api/v1/lyo2/voice/quality'",
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
    ],
  },
  {
    name: 'iOS stream model carries canonical voice events',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: [
      'case voiceTextSegment',
      'case voiceReady',
      'case voiceIncomplete',
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
      'engine.speak',
      'ChatStreamEvent.VoiceSegment',
      'pendingVoiceUtterances',
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

// A learner's turn is sent by a timer counting out the pause after they stop
// speaking. The recognizer ends itself during that same pause and is replaced
// moments later, so tearing the timer down with the recognizer means the
// replacement always wins and the turn is never sent — the session transcribes
// and then sits there. Ending the turn and stopping the recognizer must stay
// separate concerns.
const voiceLayer = 'web/src/components/chat/ConversationalVoiceLayer.tsx';
if (fs.existsSync(voiceLayer)) {
  const source = fs.readFileSync(voiceLayer, 'utf8');
  if (!source.includes('const cancelPendingTurn = useCallback(')) {
    failures.push('Web voice: end-of-turn cancellation must be its own callback');
  }
  const stopRecognition = source.match(
    /const stopRecognition = useCallback\(\(\) => \{([\s\S]*?)\n  \}, \[/,
  );
  if (!stopRecognition) {
    failures.push('Web voice: stopRecognition not found in the expected shape');
  } else if (stopRecognition[1].includes('silenceTimerRef')) {
    failures.push(
      'Web voice: stopRecognition must not clear the end-of-turn timer; '
      + 'restarting the recognizer after a pause would cancel the turn being sent',
    );
  }
  // A turn kept alive across a restart must not then fire into the middle of
  // the sentence the learner has resumed.
  const speechStart = source.match(
    /recognition\.onspeechstart = \(\) => \{([\s\S]*?)\n    \};/,
  );
  if (!speechStart) {
    failures.push('Web voice: onspeechstart not found in the expected shape');
  } else if (!speechStart[1].includes('armTurnTimer(')) {
    failures.push(
      'Web voice: renewed speech must defer the turn already waiting to be sent, '
      + 'or it submits mid-sentence and truncates the learner',
    );
  }
}

// Playback bleeds back into the microphone, so loudness alone cannot end a
// turn: Lyo hears itself and cuts itself off. Loudness ducks and waits for the
// recognizer to confirm words that are not an echo.
const voiceLayerBarge = 'web/src/components/chat/ConversationalVoiceLayer.tsx';
if (fs.existsSync(voiceLayerBarge)) {
  const source = fs.readFileSync(voiceLayerBarge, 'utf8');
  const bargeIn = source.match(/const bargeIn = useCallback\(\(\) => \{([\s\S]*?)\n  \}, \[/);
  if (!bargeIn) {
    failures.push('Web voice: bargeIn not found in the expected shape');
  } else {
    if (bargeIn[1].includes('stopSpeech()')) {
      failures.push(
        'Web voice: a loud microphone alone must not stop playback; '
        + "Lyo's own voice clears the bar and it interrupts itself",
      );
    }
    if (!bargeIn[1].includes('duckPlayback()')) {
      failures.push('Web voice: a suspected interruption must duck playback while unconfirmed');
    }
  }
  // The bar must be built from the measured bleed, not merely mention it.
  if (!/bleedFloorRef\.current \* BARGE_IN_EXCESS/.test(source)) {
    failures.push(
      "Web voice: the barge-in bar must track Lyo's own bleed, not a fixed level",
    );
  }
  // Recognized words alone cannot end a turn while Lyo is audible: the
  // microphone hears Lyo through the speaker, and that bleed transcribes into
  // words that are in no echo of the answer, so Lyo interrupts itself.
  if (!/shouldEndTurnOnSpeech\(\{/.test(source)) {
    failures.push(
      'Web voice: speech heard during playback must be weighed against the '
      + "microphone level, or Lyo's own bleed reads as a learner",
    );
  }
  // The confirmation block consumes the loudness flag, so reading it at the
  // decision point finds it already spent by the very speech that confirmed
  // it — holding the turn exactly when the learner did interrupt.
  if (/loudEnough: pendingRmsBargeAtRef\.current/.test(source)) {
    failures.push(
      'Web voice: the microphone level must be read before the confirmation '
      + 'block clears it, or a real interruption never registers',
    );
  }
  if (!/monitorState: micMonitorStateRef\.current/.test(source)) {
    failures.push(
      'Web voice: that decision must know whether the volume monitor is ready, '
      + 'or the opening of playback falls back to words alone',
    );
  }
  // An answer streams in far faster than it is spoken, so it is shown only as
  // far as it has been read aloud.
  if (!/\bsetVoiceSpokenText\(/.test(source)) {
    failures.push('Web voice: spoken progress must be published for the answer to follow');
  }
}

// Voice stream events are addressed to the message this client is rendering.
// The server's own id names a row the client has never seen, so anything
// matching on it — the display following the voice, the guard against
// speaking a turn twice — silently never matches and the feature reads as
// doing nothing rather than as broken.
const chatStore = 'web/src/stores/chat-store.ts';
if (fs.existsSync(chatStore)) {
  const source = fs.readFileSync(chatStore, 'utf8');
  if (/messageId:\s*(?:typeof\s*)?chunk\.message_id/.test(source)) {
    failures.push(
      "Web transport: voice events must carry this client's message id, "
      + "not the server's, or nothing downstream can match them",
    );
  }
  if (!/messageId: aiMessageId/.test(source)) {
    failures.push('Web transport: voice events must carry the rendered assistant message id');
  }
}

// Live voice renders inside the chat input, so its effects run first: a
// passive effect would start the live recognizer before dictation released the
// microphone. The handover has to be ordered by the control itself.
const chatInput = 'web/src/components/chat/ChatInputBar.tsx';
if (fs.existsSync(chatInput)) {
  const source = fs.readFileSync(chatInput, 'utf8');
  if (!/if \(!voiceSessionActive\) stopDictation\(\);/.test(source)) {
    failures.push(
      'Web chat input: the live-conversation control must stop dictation '
      + 'before activating the session, not through an effect afterwards',
    );
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
  'with canonical segment streaming, STT/TTS transport, voice_session delivery metadata and barge-in; no separate voice AI path.'
);
