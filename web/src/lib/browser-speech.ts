export type BrowserSpeechRecognitionAlternative = {
  transcript: string;
  confidence?: number;
};

export type BrowserSpeechRecognitionResult = ArrayLike<BrowserSpeechRecognitionAlternative> & {
  isFinal?: boolean;
};

export type BrowserSpeechRecognitionEvent = {
  resultIndex?: number;
  results: ArrayLike<BrowserSpeechRecognitionResult>;
};

export type BrowserSpeechRecognition = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  start: () => void;
  stop: () => void;
  abort?: () => void;
  onstart?: (() => void) | null;
  onspeechstart?: (() => void) | null;
  onspeechend?: (() => void) | null;
  onresult: ((event: BrowserSpeechRecognitionEvent) => void) | null;
  onend: (() => void) | null;
  onerror: ((event?: unknown) => void) | null;
};

export function createBrowserSpeechRecognition(): BrowserSpeechRecognition | null {
  if (typeof window === 'undefined') return null;
  const browser = window as unknown as Record<string, unknown>;
  const Recognition = (browser.SpeechRecognition || browser.webkitSpeechRecognition) as
    | (new () => BrowserSpeechRecognition)
    | undefined;
  return Recognition ? new Recognition() : null;
}
