export interface CommonsImage {
  /** An https URL on upload.wikimedia.org. */
  url: string;
  attribution: string;
  /** The Commons page for credit, when the response carried one. */
  sourceUrl?: string;
}

/** The Commons search request for a topic. */
export function commonsSearchUrl(query: string): string;

/** The usable image in a Commons API response, or null if there is none. */
export function parseCommonsResponse(data: unknown): CommonsImage | null;

/** One illustrative image for a topic. Never throws; returns null on failure. */
export function resolveCommonsImage(
  query: string | null | undefined,
  fetchImpl?: (url: string) => Promise<Response>,
): Promise<CommonsImage | null>;
