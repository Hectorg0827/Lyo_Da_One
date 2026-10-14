export type SpeechAlternativeLike = {
  transcript?: string;
  confidence?: number;
};

export type SpeechResultLike = ArrayLike<SpeechAlternativeLike> & {
  isFinal?: boolean;
};

export type SpeechResultEventLike = {
  resultIndex?: number;
  results: ArrayLike<SpeechResultLike>;
};

export type TranscriptState = {
  final: string;
  interim: string;
  combined: string;
};

export type TranscriptAccumulator = {
  readonly final: string;
  push(event: SpeechResultEventLike): TranscriptState;
  carryOver(): void;
  reset(): void;
};

export function normalizeSpeechLang(raw?: string | null): string;
export function bestAlternative(result?: SpeechResultLike | null): string;
export function mergeTranscript(base?: string | null, addition?: string | null): string;
export function tidyTranscript(
  text?: string | null,
  options?: { capitalize?: boolean },
): string;
export function createTranscriptAccumulator(): TranscriptAccumulator;
