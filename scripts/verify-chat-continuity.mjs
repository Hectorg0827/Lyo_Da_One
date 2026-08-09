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
      'media?: Array<{',
      'mime_type',
    ],
  },
  {
    name: 'web multimodal composer',
    path: 'web/src/components/chat/ChatInputBar.tsx',
    needles: [
      "api.media.upload(normalizedFile, 'chat')",
      'multiple',
      'sendMessage(trimmed, sentAttachments)',
      'application/pdf',
      'MAX_ATTACHMENTS = 4',
    ],
    forbidden: ["api.storage.upload(file, 'chat')"],
  },
  {
    name: 'web canonical store',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      'hydrate:',
      'loadConversation:',
      'createConversation',
      'userMessage.id',
      'attachments.map((attachment)',
      "modality: attachment.kind === 'image' ? 'IMAGE' as const : 'DOCUMENT' as const",
    ],
  },
  {
    name: 'web adaptive AI response width',
    path: 'web/src/components/chat/MessageBubble.tsx',
    needles: [
      "ASSISTANT_RESPONSE_WIDTH_CLASS = 'w-[99%]'",
      "!isUser && 'w-full'",
    ],
    forbidden: ["'relative max-w-[78%] md:max-w-[68%]'"],
  },
  {
    name: 'web full-width chat viewport',
    path: 'web/src/components/chat/ChatInterface.tsx',
    needles: ['flex flex-col gap-6 py-6 w-full'],
    forbidden: ['px-4 py-6 max-w-3xl mx-auto w-full'],
  },
  {
    name: 'web honest generation status',
    path: 'web/src/components/chat/ChatInterface.tsx',
    needles: [
      'getGenerationStatusLabel',
      "case 'thinking':",
      "case 'response':",
      "case 'course':",
      "return 'Thinking…';",
      "'Finalizing response…' : 'Generating response…'",
      "'Finalizing your course…' : 'Preparing your course…'",
      'aria-live="polite"',
    ],
    forbidden: ['>Generating course…</span>'],
  },
  {
    name: 'web response-aware generation activity',
    path: 'web/src/stores/chat-store.ts',
    needles: [
      "GenerationActivity = 'thinking' | 'response' | 'course'",
      "generationActivity: 'thinking'",
      "generationActivity: 'course'",
    ],
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
    needles: [
      'conversation_id',
      'client_message_id',
      'ChatStreamEvent.Conversation',
      'data class ChatMediaRef',
      '"media"',
      '"mime_type"',
      '"size_bytes"',
    ],
  },
  {
    name: 'Android multimodal chat UI',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt',
    needles: [
      'RecognizerIntent.ACTION_RECOGNIZE_SPEECH',
      'TextToSpeech',
      'ApiClient.api.uploadMedia',
      'folder = "chat"',
      'ActivityResultContracts.OpenMultipleDocuments()',
      'uploadChatAttachment',
      'ChatMediaRef(',
      '"DOCUMENT"',
      'MAX_CHAT_ATTACHMENTS = 4',
      'buildChatContent',
      'parseChatContent',
      'ASSISTANT_RESPONSE_WIDTH_FRACTION = 0.99f',
      'Modifier.fillMaxWidth(ASSISTANT_RESPONSE_WIDTH_FRACTION)',
    ],
    forbidden: [
      'val bubbleModifier = Modifier\n            .widthIn(max = 320.dp)',
      'ChatStreamClient.stream(content, conversationId, clientMessageId)',
    ],
  },
  {
    name: 'iOS adaptive AI response width',
    path: 'Sources/Views/Chat/EnhancedMessageBubble.swift',
    needles: [
      'assistantResponseWidthFraction: CGFloat = 0.99',
      '.containerRelativeFrame(.horizontal) { width, _ in',
      'width * assistantResponseWidthFraction',
    ],
    forbidden: ['.padding(.horizontal, 1) // Near edge-to-edge'],
  },
  {
    name: 'iOS full-width chat viewport',
    path: 'Sources/Views/Main/Hybrid/LyoOverlayView.swift',
    needles: [
      '.padding(.top, 60)\n            .padding(.bottom, 20)',
    ],
    forbidden: [
      '.padding(.top, 60)\n            .padding(.horizontal, 8)\n            .padding(.bottom, 20)',
    ],
  },
  {
    name: 'iOS stream request',
    path: 'Sources/Models/Lyo2Models.swift',
    needles: [
      'conversation_id',
      'client_message_id',
      'case conversation(id: String)',
      'case sizeBytes = "size_bytes"',
    ],
  },
  {
    name: 'iOS active multimodal composer',
    path: 'Sources/Views/Main/Hybrid/LyoOverlayView.swift',
    needles: [
      'showAttachmentMenu = true',
      '.photosPicker(',
      '.fileImporter(',
      'mediaService.uploadMedia(media)',
      'viewModel.addAttachment(attachment)',
    ],
    forbidden: ['Button(action: { /* Show attachments */ })'],
  },
  {
    name: 'iOS multimodal transport',
    path: 'Sources/Services/UnifiedChatService.swift',
    needles: [
      'let media = mediaRefs(from: attachments)',
      'media: media,',
      'modality = "IMAGE"',
      'modality = "DOCUMENT"',
    ],
  },
  {
    name: 'iOS consumer media upload',
    path: 'Sources/Services/MediaPickerService.swift',
    needles: [
      'CloudStorageService.shared.uploadFile(',
      'folder: "chat"',
      'maxAttachmentCount = 4',
      'maxTotalSize: Int64 = 20 * 1024 * 1024',
    ],
    forbidden: ['return try await LyoRepository.shared.uploadFile(url: tempURL)'],
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
  for (const forbidden of contract.forbidden ?? []) {
    if (source.includes(forbidden)) failures.push(`${contract.name}: still contains ${forbidden}`);
  }
}

if (failures.length > 0) {
  console.error('Cross-device chat continuity contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log('Chat contract: Web, Android, and iOS share canonical history, idempotent turn IDs, adaptive 99% AI response width, structured image/document uploads, and context-aware generation status.');
