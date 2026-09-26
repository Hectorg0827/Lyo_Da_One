export type ConversationListState = 'loading' | 'error' | 'empty' | 'no-match' | 'list';
export function conversationListState(input: {
  loading: boolean;
  error: string | null;
  loaded: boolean;
  total: number;
  shown: number;
}): ConversationListState;
export function conversationIdFromSearch(search: string | null | undefined): string | null;
