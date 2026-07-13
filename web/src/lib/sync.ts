import { getAccessToken } from '@/lib/api';

/**
 * Cross-device sync client for the backend's Multi-Device Sync service
 * (LyoBackendJune lyo_app/routers/sync.py).
 *
 * Connects a websocket to /api/v1/sync/ws so this browser receives
 * real-time events when the same account acts on another device
 * (iOS, Android, or another browser tab).
 */

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoapp.com';
const HEARTBEAT_MS = 30_000;
const RECONNECT_BASE_MS = 2_000;
const RECONNECT_MAX_MS = 60_000;

export type SyncEventType =
  | 'connected'
  | 'device_connected'
  | 'device_disconnected'
  | 'message_sent'
  | 'message_received'
  | 'typing_started'
  | 'typing_stopped'
  | 'session_transferred'
  | 'context_updated'
  | 'error';

export interface SyncEvent {
  event_type: SyncEventType;
  device_id?: string;
  [key: string]: unknown;
}

export type SyncListener = (event: SyncEvent) => void;

function wsUrl(token: string): string {
  const base = API_URL.replace(/^http/, 'ws').replace(/\/$/, '');
  const deviceType = /Mobi|Android|iPhone/i.test(navigator.userAgent)
    ? 'web_mobile'
    : 'web_desktop';
  const params = new URLSearchParams({
    token,
    device_type: deviceType,
    device_name: 'LYO Web',
  });
  return `${base}/api/v1/sync/ws?${params.toString()}`;
}

class SyncClient {
  private socket: WebSocket | null = null;
  private listeners = new Set<SyncListener>();
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempt = 0;
  private shouldRun = false;

  /** This browser's device id, assigned by the server on connect. */
  deviceId: string | null = null;

  /** Start (or restart) the sync connection. Safe to call repeatedly. */
  connect() {
    this.shouldRun = true;
    this.open();
  }

  /** Stop syncing (e.g. on logout). */
  disconnect() {
    this.shouldRun = false;
    this.cleanup();
  }

  /** Subscribe to sync events; returns an unsubscribe function. */
  subscribe(listener: SyncListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Tell other devices this one is (or stopped) typing. */
  sendTyping(isTyping: boolean) {
    this.send({ type: 'typing', is_typing: isTyping });
  }

  private open() {
    if (typeof window === 'undefined') return;
    if (!this.shouldRun) return;
    const token = getAccessToken();
    if (!token) {
      // Auth state can flip before the token is persisted; retry with
      // backoff instead of staying offline until the next login.
      this.scheduleReconnect();
      return;
    }
    if (this.socket && this.socket.readyState <= WebSocket.OPEN) return;

    try {
      this.socket = new WebSocket(wsUrl(token));
    } catch {
      this.scheduleReconnect();
      return;
    }

    this.socket.onopen = () => {
      this.reconnectAttempt = 0;
      this.heartbeatTimer = setInterval(
        () => this.send({ type: 'heartbeat' }),
        HEARTBEAT_MS
      );
    };

    this.socket.onmessage = (msg) => {
      let event: SyncEvent;
      try {
        event = JSON.parse(msg.data as string);
      } catch {
        return;
      }
      if (event.event_type === 'connected' && event.device_id) {
        this.deviceId = event.device_id;
      }
      this.listeners.forEach((l) => {
        try {
          l(event);
        } catch {
          // one bad listener must not break the rest
        }
      });
    };

    this.socket.onclose = () => {
      this.cleanup(false);
      this.scheduleReconnect();
    };

    this.socket.onerror = () => {
      this.socket?.close();
    };
  }

  private send(payload: Record<string, unknown>) {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(payload));
    }
  }

  private scheduleReconnect() {
    if (!this.shouldRun || this.reconnectTimer) return;
    const delay = Math.min(
      RECONNECT_BASE_MS * 2 ** this.reconnectAttempt,
      RECONNECT_MAX_MS
    );
    this.reconnectAttempt += 1;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.open();
    }, delay);
  }

  private cleanup(clearReconnect = true) {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    if (clearReconnect && this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.socket) {
      this.socket.onclose = null;
      this.socket.close();
      this.socket = null;
    }
    this.deviceId = null;
    if (clearReconnect) {
      // Fresh session, fresh backoff — a flaky previous session must not
      // delay the first reconnect after the next sign-in.
      this.reconnectAttempt = 0;
    }
  }
}

/** App-wide singleton sync client. */
export const syncClient = new SyncClient();
