import { readFileSync } from 'node:fs';

const messages = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/messages/MessagesScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!messages.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (messages.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

for (const [expected, label] of [
  ['conversationError', 'conversation failure state'],
  ['messagesError', 'message failure state'],
  ['sendError', 'send failure state'],
  ['var sending by remember', 'pending send state'],
  ['enabled = draft.isNotBlank() && !sending', 'double-send prevention'],
  ['.onSuccess { sentMessage ->', 'confirmed server send'],
  ['messages = (messages + sentMessage).distinctBy', 'confirmed message append'],
  ['.onFailure {\n                                sendError = messagingError(it, "send message")', 'visible send failure'],
  ['onRetry = { conversationReload += 1 }', 'conversation retry'],
  ['onRetry = { messagesReload += 1 }', 'message retry'],
  ['conversationsLoaded && conversations.isEmpty()', 'confirmed empty inbox'],
  ['messagesLoaded && messages.isEmpty()', 'confirmed empty conversation'],
]) {
  requireText(expected, label);
}

const sendStart = messages.indexOf('runCatching {\n                                ApiClient.api.sendMessage');
const sendSuccess = messages.indexOf('.onSuccess { sentMessage ->', sendStart);
const draftClear = messages.indexOf('draft = ""', sendStart);
const sendFailure = messages.indexOf('.onFailure {', sendSuccess);
if (sendStart < 0 || sendSuccess < sendStart || draftClear < sendSuccess || sendFailure < draftClear) {
  throw new Error('Draft text must clear only after a confirmed server send and remain available on failure.');
}

for (const forbidden of [
  'if (text.isEmpty()) return@IconButton\n                        draft = ""',
  'enabled = draft.isNotBlank(),',
  'runCatching { ApiClient.api.sendMessage(conv.idStr, SendMessageRequest(text)) }\n                            runCatching',
]) {
  rejectText(forbidden, 'Android Messages reliability');
}

console.log('Android Messages preserves drafts and exposes recoverable load/send failures.');