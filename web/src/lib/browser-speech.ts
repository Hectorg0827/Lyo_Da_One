export type BrowserSpeechRecognition = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  start: () => void;
  stop: () => void;
  onresult: ((event: {
    results: ArrayLike<ArrayLike<{ transcript: string }>>;
  }) => void) | null;
  onend: (() => void) | null;
  onerror: (() => void) | null;
};

export function createBrowserSpeechRecognition(): BrowserSpeechRecognition | null {
  if (typeof window === 'undefined') return null;
  const browser = window as unknown as Record<string, unknown>;
  const Recognition = (browser.SpeechRecognition || browser.webkitSpeechRecognition) as
    | (new () => BrowserSpeechRecognition)
    | undefined;
  return Recognition ? new Recognition() : null;
}

