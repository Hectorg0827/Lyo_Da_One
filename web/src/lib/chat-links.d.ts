export type ChatLink =
  | { kind: 'internal'; href: string }
  | { kind: 'external'; href: string }
  | { kind: 'unsafe'; href?: undefined };

export const APP_HOSTS: readonly string[];
export function classifyChatLink(href?: string | null): ChatLink;
