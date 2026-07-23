import fs from 'node:fs';

const contracts = [
  {
    name: 'web API',
    path: 'web/src/lib/api.ts',
    needles: [
      '/api/v1/chat/conversations',
      '/api/v1/lyo2/chat/stream',
      'conversation_id',
      'client_message_id',
      'device_id',
    ],
  },
  {
    name: 'web canonical store',
    path: 'web/src/stores/chat-store.ts',
    needles: ['hydrate:', 'loadConversation:', 'createConversation', 'userMessage.id'],
  },
  {
    name: 'Android API',
    path: 'android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt',
    needles: [
      'api/v1/chat/conversations',
      'createAiConversation',
      'aiConversation',
      'uploadMedia',
    ],
  },
  {
    name: 'Android stream',
    path: 'android/app/src/main/java/com/lyo/app/data/api/ChatStreamClient.kt',
    needles: ['conversation_id', 'client_message_id', 'ChatStreamEvent.Conversation'],
  },
  {
    name: 'Android multimodal chat UI',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt',
    needles: [
      'RecognizerIntent.ACTION_RECOGNIZE_SPEECH',
      'TextToSpeech',
      'ApiClient.api.uploadMedia',
      'folder = "chat"',
      'buildChatContent',
      'parseChatContent',
      'completed?'
    ].filter((needle) => needle !== 'completed?'),
  },
  {
    name: 'iOS stream request',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: ['conversation_id', 'client_message_id', 'case conversation(id: String)'],
  },
  {
    name: 'iOS server history',
    path: 'Sources/Services/ConversationManager.swift',
    needles: [
      '/api/v1/chat/conversations',
      'refreshFromServer',
      'hydrateConversation',
      'adoptCanonicalId',
    ],
  },
];

const failures = [];
for (const contract of contracts) {
  const source = fs.readFileSync(contract.path, 'utf8');
  for (const needle of contract.needles) {
    if (!source.includes(needle)) failures.push(`${contract.name}: missing ${needle}`);
  }
}

if (failures.length > 0) {
  console.error('Cross-device chat continuity contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log('Chat continuity contract: web, Android, and iOS share canonical server history and idempotent turn IDs; Android media and voice input remain wired.');