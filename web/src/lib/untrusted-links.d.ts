export type UntrustedLink =
  | { kind: 'internal'; href: string }
  | { kind: 'external'; href: string }
  | { kind: 'unsafe'; href?: undefined };

export const APP_HOSTS: readonly string[];
export function classifyUntrustedLink(href?: string | null): UntrustedLink;
