/**
 * Unread indicators in the top bar come only from the server's own counts;
 * with nothing unread (or no account) there is no badge at all.
 */

/**
 * Fired on window by a page that has just marked something read on the
 * server, so the top bar re-checks now rather than at its next minute.
 */
export const UNREAD_CHANGED_EVENT = 'lyo:unread-changed';

/** Badge text for an unread count: nothing at zero, "9+" past nine. */
export function unreadBadge(count) {
  const value = Number(count);
  if (!Number.isFinite(value) || value < 1) return null;
  return value > 9 ? '9+' : String(Math.floor(value));
}

/** Unread messages across conversations, summed from each one's server count. */
export function totalUnread(conversations) {
  if (!Array.isArray(conversations)) return 0;
  return conversations.reduce((sum, conversation) => {
    const value = Number(conversation?.unread_count ?? conversation?.unreadCount ?? 0);
    return sum + (Number.isFinite(value) && value > 0 ? Math.floor(value) : 0);
  }, 0);
}

/** What a screen reader hears: "Notifications, 3 unread" or just "Notifications". */
export function unreadLabel(name, count) {
  const value = Number(count);
  if (!Number.isFinite(value) || value < 1) return name;
  return `${name}, ${Math.floor(value)} unread`;
}
