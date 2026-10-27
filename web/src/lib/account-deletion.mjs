/**
 * Deleting a learner's account.
 *
 * The contract agreed with the backend: `DELETE /auth/me` with the bearer
 * token and no body; 200 or 204 means the account is gone. Android
 * (AccountDeletion.kt) and iOS follow the same contract, and
 * scripts/verify-account-deletion.mjs keeps them in step.
 *
 * Order matters: local data is cleared only after the server confirms. A
 * failed request leaves the learner signed in, so they are never shown as
 * "deleted" while their account still exists.
 */

export const ACCOUNT_DELETION_METHOD = 'DELETE';
export const ACCOUNT_DELETION_PATH = '/auth/me';

/** Every key the web app writes to browser storage starts with this. */
export const LOCAL_KEY_PREFIX = 'lyo_';

/** True only for the statuses the backend promised for a completed deletion. */
export function accountDeletionSucceeded(status) {
  return status === 200 || status === 204;
}

/** What to tell the learner when deletion did not happen. They stay signed in. */
export function accountDeletionFailure(status) {
  if (status === 401 || status === 403) {
    return 'Your session has expired. Log in again, then delete your account.';
  }
  if (status === 429) return 'Too many attempts. Please wait a few minutes and try again.';
  if (status === 0) return 'Your account was not deleted. Check your connection and try again.';
  return `Your account was not deleted (error ${status}). Please try again, or email support@lyoai.app.`;
}

/**
 * Send the deletion request. Retries once after a token refresh when the
 * access token had merely expired. Never throws: the result says whether it
 * worked and, if not, why.
 */
export async function requestAccountDeletion({ apiUrl, getToken, refresh, fetchImpl }) {
  const url = `${String(apiUrl).replace(/\/$/, '')}${ACCOUNT_DELETION_PATH}`;
  const send = () => {
    const token = getToken();
    if (!token) return Promise.resolve({ status: 401 });
    return fetchImpl(url, {
      method: ACCOUNT_DELETION_METHOD,
      headers: { Authorization: `Bearer ${token}` },
    });
  };
  try {
    let response = await send();
    if (response.status === 401 && refresh && (await refresh())) {
      response = await send();
    }
    if (accountDeletionSucceeded(response.status)) return { ok: true, status: response.status };
    return { ok: false, status: response.status, message: accountDeletionFailure(response.status) };
  } catch {
    return { ok: false, status: 0, message: accountDeletionFailure(0) };
  }
}

/** Remove everything LYO stored in this browser (tokens, cached sessions, preferences). */
export function clearLocalAccountData(storage) {
  if (!storage) return;
  const keys = [];
  for (let index = 0; index < storage.length; index += 1) {
    const key = storage.key(index);
    if (key && key.startsWith(LOCAL_KEY_PREFIX)) keys.push(key);
  }
  for (const key of keys) storage.removeItem(key);
}
