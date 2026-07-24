import { readFileSync } from 'node:fs';

const detail = readFileSync(new URL('../android/app/src/main/java/com/lyo/app/ui/screens/community/ReliablePostDetailScreen.kt', import.meta.url), 'utf8');
const navigation = readFileSync(new URL('../android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt', import.meta.url), 'utf8');

const required = [
  [navigation, 'ReliablePostDetailScreen(nav, entry.arguments?.getString("postId") ?: "")'],
  [detail, 'var postLoaded by remember(postId) { mutableStateOf(false) }'],
  [detail, 'var commentsLoaded by remember(postId) { mutableStateOf(false) }'],
  [detail, 'postError != null && post == null && !postLoaded'],
  [detail, 'commentsError != null && comments.isEmpty() && !commentsLoaded'],
  [detail, 'commentsLoaded && comments.isEmpty()'],
  [detail, 'val response = ApiClient.api.toggleCommunityPostLike(postId)'],
  [detail, 'val confirmedLiked = response.liked'],
  [detail, 'val confirmedCount = response.likeCount'],
  [detail, 'ApiClient.api.toggleCommunityPostBookmark(postId)'],
  [detail, 'ApiClient.api.toggleCommunityCommentLike(postId, commentId)'],
  [detail, 'pendingCommentLikeIds = pendingCommentLikeIds + commentId'],
  [detail, 'pendingCommentDeleteIds = pendingCommentDeleteIds + commentId'],
  [detail, 'comments = listOf(created) + comments'],
  [detail, 'commentText = ""'],
  [detail, 'https://lyoai.app/community/$postId'],
  [detail, 'SyncClient.events.collect'],
];

for (const [source, text] of required) {
  if (!source.includes(text)) throw new Error(`Missing post-detail contract marker: ${text}`);
}

for (const forbidden of ['.getOrNull()', 'liked = !wasLiked', 'bookmarked = !wasBookmarked', 'https://lyoapp.com/']) {
  if (detail.includes(forbidden)) throw new Error(`Forbidden unreliable post-detail pattern: ${forbidden}`);
}
if (navigation.includes('PostDetailScreen(nav, entry.arguments?.getString("postId") ?: "")')) {
  throw new Error('Legacy post detail is still active.');
}

function assertMutationAfterSuccess(requestText, successText, mutationText, label) {
  const request = detail.indexOf(requestText);
  const success = detail.indexOf(successText, request);
  const mutation = detail.indexOf(mutationText, success);
  if (request < 0 || success < request || mutation < success) {
    throw new Error(`${label} mutates before confirmed success.`);
  }
}

assertMutationAfterSuccess(
  'val response = ApiClient.api.toggleCommunityPostLike(postId)',
  '.onSuccess { (confirmedLiked, confirmedCount) ->',
  'liked = confirmedLiked',
  'Post like',
);
assertMutationAfterSuccess(
  'ApiClient.api.toggleCommunityPostBookmark(postId)',
  '.onSuccess { confirmedBookmarked ->',
  'bookmarked = confirmedBookmarked',
  'Bookmark',
);
assertMutationAfterSuccess(
  'ApiClient.api.createCommunityComment(',
  '.onSuccess { created ->',
  'commentText = ""',
  'Comment creation',
);

console.log('Android post detail uses recoverable loads and confirmed actions.');
