import test from 'node:test';
import assert from 'node:assert/strict';
import { conversationIdFromSearch, conversationListState } from './messages-view.mjs';

test('a blank inbox is never ambiguous: loading, failed, empty, and no match differ', () => {
  assert.equal(conversationListState({ loading: true, error: null, loaded: false, total: 0, shown: 0 }), 'loading');
  assert.equal(conversationListState({ loading: false, error: 'Database operation failed', loaded: false, total: 0, shown: 0 }), 'error');
  assert.equal(conversationListState({ loading: false, error: null, loaded: true, total: 0, shown: 0 }), 'empty');
  assert.equal(conversationListState({ loading: false, error: null, loaded: true, total: 3, shown: 0 }), 'no-match');
  assert.equal(conversationListState({ loading: false, error: null, loaded: true, total: 3, shown: 2 }), 'list');
  // A failed refresh keeps showing what already loaded.
  assert.equal(conversationListState({ loading: false, error: 'offline', loaded: true, total: 2, shown: 2 }), 'list');
});

test('a notification link opens its conversation, and nothing else gets through', () => {
  assert.equal(conversationIdFromSearch('?conversation=42'), '42');
  assert.equal(conversationIdFromSearch('?conversation=abc'), null);
  assert.equal(conversationIdFromSearch('?conversation=42%3Cscript%3E'), null);
  assert.equal(conversationIdFromSearch(''), null);
  assert.equal(conversationIdFromSearch(undefined), null);
});
