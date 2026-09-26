/**
 * What the Messages list shows. Loading, a failed load, an empty inbox, and a
 * search with no matches each look different, so a blank list never has to
 * be guessed at.
 */
export function conversationListState({ loading, error, loaded, total, shown }) {
  if (!loaded) {
    if (error) return 'error';
    return 'loading';
  }
  if (total === 0) return 'empty';
  if (shown === 0) return 'no-match';
  return 'list';
}

/** The conversation a notification link points at (?conversation=12), or null. */
export function conversationIdFromSearch(search) {
  const value = new URLSearchParams(search ?? '').get('conversation');
  return value && /^\d{1,12}$/.test(value) ? value : null;
}
