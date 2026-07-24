import { readFileSync } from 'node:fs';

const clips = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/clips/ClipsScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!clips.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (clips.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

for (const [expected, label] of [
  ['var loaded by remember { mutableStateOf(false) }', 'confirmed clips load state'],
  ['var loadError by remember { mutableStateOf<String?>(null) }', 'clips load failure state'],
  ['loadError != null && clips.isEmpty() -> ClipsLoadError(', 'clips failure before empty state'],
  ['loaded && clips.isEmpty()', 'confirmed clips empty state'],
  ['val response = ApiClient.api.likeClip(id)', 'like request'],
  ['response.get("isLiked")?.asBoolean', 'confirmed like toggle state'],
  ['response.get("likeCount")?.asInt', 'confirmed like count'],
  ['val response = ApiClient.api.saveClip(id)', 'save request'],
  ['response.get("isSaved")?.asBoolean', 'confirmed save toggle state'],
  ['if (response.get("success")?.asBoolean != true)', 'explicit sync success validation'],
  ['viewSyncFailed = id in failedViewIds', 'retryable view sync state'],
  ['text = "View sync failed · Retry"', 'view retry affordance'],
  ['var pendingDeleteIds by remember(clipId)', 'comment delete pending state'],
  ['loadError != null && comments.isEmpty() && !loaded -> CommentLoadError(', 'comment failure before empty state'],
  ['loaded && comments.isEmpty() -> EmptyState(', 'confirmed comment empty state'],
  ['text = ""\n                                onCountChanged(1)', 'comment draft clears after success'],
  ['File.createTempFile("lyo-clip-"', 'streamed temporary upload file'],
  ['file.asRequestBody(contentType.toMediaType())', 'file-backed upload request body'],
  ['if (created.success != true || created.clip == null)', 'confirmed clip publication'],
]) {
  requireText(expected, label);
}

for (const [forbidden, label] of [
  ['.getOrDefault(emptyList())', 'failed feeds must not become empty lists'],
  ['it.readBytes()', 'clip upload must not load the whole video into memory'],
  ['if (id !in likedIds) {\n                                likedIds = likedIds + id', 'like state must not change before confirmation'],
  ['if (id !in savedIds) {\n                                savedIds = savedIds + id', 'save state must not change before confirmation'],
  ['comments.isEmpty() -> EmptyState(title = "No comments yet"', 'comment failure must not masquerade as empty'],
]) {
  rejectText(forbidden, label);
}

const likeRequest = clips.indexOf('val response = ApiClient.api.likeClip(id)');
const likeSuccess = clips.indexOf('.onSuccess { (confirmedLiked, confirmedCount) ->', likeRequest);
const likeMutation = clips.indexOf('likedIds = if (confirmedLiked)', likeSuccess);
if (likeRequest < 0 || likeSuccess < likeRequest || likeMutation < likeSuccess) {
  throw new Error('Like state must change only after the backend returns confirmed state.');
}

const saveRequest = clips.indexOf('val response = ApiClient.api.saveClip(id)');
const saveSuccess = clips.indexOf('.onSuccess { confirmedSaved ->', saveRequest);
const saveMutation = clips.indexOf('savedIds = if (confirmedSaved)', saveSuccess);
if (saveRequest < 0 || saveSuccess < saveRequest || saveMutation < saveSuccess) {
  throw new Error('Saved state must change only after the backend returns confirmed state.');
}

const commentRequest = clips.indexOf('ApiClient.api.createClipComment(');
const commentSuccess = clips.indexOf('.onSuccess { created ->', commentRequest);
const draftClear = clips.indexOf('text = ""', commentSuccess);
if (commentRequest < 0 || commentSuccess < commentRequest || draftClear < commentSuccess) {
  throw new Error('Comment drafts may clear only after confirmed creation.');
}

console.log('Android Clips exposes failures and uses confirmed transactional state.');
