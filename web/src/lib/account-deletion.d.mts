export const ACCOUNT_DELETION_METHOD: string;
export const ACCOUNT_DELETION_PATH: string;
export const LOCAL_KEY_PREFIX: string;
export function accountDeletionSucceeded(status: number): boolean;
export function accountDeletionFailure(status: number): string;
export type AccountDeletionResult =
  | { ok: true; status: number }
  | { ok: false; status: number; message: string };
export function requestAccountDeletion(options: {
  apiUrl: string;
  getToken: () => string | null;
  refresh?: () => Promise<boolean>;
  fetchImpl: (url: string, init: RequestInit) => Promise<{ status: number }>;
}): Promise<AccountDeletionResult>;
export function clearLocalAccountData(storage: Storage | null | undefined): void;
