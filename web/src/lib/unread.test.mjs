import test from 'node:test';
import assert from 'node:assert/strict';
import { totalUnread, unreadBadge, unreadLabel } from './unread.mjs';

test('badges show real counts only, and nothing when there is nothing unread', () => {
  assert.equal(unreadBadge(0), null);
  assert.equal(unreadBadge(undefined), null);
  assert.equal(unreadBadge('oops'), null);
  assert.equal(unreadBadge(-2), null);
  assert.equal(unreadBadge(1), '1');
  assert.equal(unreadBadge(9), '9');
  assert.equal(unreadBadge(10), '9+');
  assert.equal(unreadBadge(250), '9+');
});

test('unread messages add up each conversation the server counted', () => {
  assert.equal(totalUnread([{ unread_count: 2 }, { unread_count: 0 }, { unread_count: 3 }]), 5);
  assert.equal(totalUnread([{ unreadCount: 1 }, {}, null, { unread_count: 'x' }]), 1);
  assert.equal(totalUnread(undefined), 0);
  assert.equal(totalUnread([]), 0);
});

test('screen readers hear the count only when there is one', () => {
  assert.equal(unreadLabel('Notifications', 3), 'Notifications, 3 unread');
  assert.equal(unreadLabel('Messages', 0), 'Messages');
});
