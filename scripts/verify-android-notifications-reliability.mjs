import { readFileSync } from 'node:fs';

const notifications = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/notifications/NotificationsScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!notifications.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (notifications.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

for (const [expected, label] of [
  ['var loadError by remember', 'notification load failure state'],
  ['var actionError by remember', 'notification action failure state'],
  ['var pendingNotificationId by remember', 'single read pending state'],
  ['var markingAllRead by remember', 'mark-all pending state'],
  ['loaded && visible.isEmpty()', 'confirmed notification empty state'],
  ['.onFailure { error ->\n                loadError = notificationError(error, "load notifications")', 'visible load failure'],
  ['.onSuccess {\n                    notifications = notifications.map { item ->', 'confirmed single read transition'],
  ['.onFailure { error ->\n                    actionError = notificationError(error, "mark the notification read")', 'visible single-read failure'],
  ['.onSuccess {\n                                        notifications = notifications.map { it.copy(isRead = true) }', 'confirmed mark-all transition'],
  ['.onFailure { error ->\n                                        actionError = notificationError(error, "mark all notifications read")', 'visible mark-all failure'],
  ['"post" -> Routes.postDetail(targetId)', 'supported post destination'],
  ['"user", "profile" -> Routes.userProfile(targetId)', 'supported user destination'],
  ['"course" -> Routes.courseDetail(targetId)', 'supported course destination'],
  ['else -> null', 'unsupported target isolation'],
]) {
  requireText(expected, label);
}

const singleRequest = notifications.indexOf('runCatching { ApiClient.api.markNotificationRead(notificationId) }');
const singleSuccess = notifications.indexOf('.onSuccess {', singleRequest);
const singleMutation = notifications.indexOf('notifications = notifications.map { item ->', singleRequest);
if (singleRequest < 0 || singleSuccess < singleRequest || singleMutation < singleSuccess) {
  throw new Error('Single notification read state must change only after backend success.');
}

const allRequest = notifications.indexOf('runCatching { ApiClient.api.markAllNotificationsRead() }');
const allSuccess = notifications.indexOf('.onSuccess {', allRequest);
const allMutation = notifications.indexOf('notifications = notifications.map { it.copy(isRead = true) }', allRequest);
if (allRequest < 0 || allSuccess < allRequest || allMutation < allSuccess) {
  throw new Error('Mark-all state must change only after backend success.');
}

for (const forbidden of [
  '\n            visible.isEmpty() -> EmptyState(',
  'runCatching { ApiClient.api.markAllNotificationsRead() }\n                                refetch()',
  'notifications = notifications.map {\n                                    if (it.idStr == notification.idStr) it.copy(isRead = true)',
]) {
  rejectText(forbidden, 'Android Notifications reliability');
}

console.log('Android Notifications exposes failures and confirms state transitions before mutation.');