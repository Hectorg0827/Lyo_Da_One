export type MicMonitorState = 'ready' | 'pending' | 'unavailable';

export function shouldEndTurnOnSpeech(input?: {
  isEcho?: boolean;
  loudEnough?: boolean;
  monitorState?: MicMonitorState;
}): boolean;
