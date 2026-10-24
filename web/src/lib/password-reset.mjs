/**
 * Resetting a forgotten password.
 *
 * /auth/forgot-password asks the API to email a one-time link
 * (POST /auth/password-reset/request); the link opens
 * /auth/reset-password?token=..., which sets the new password
 * (POST /auth/password-reset/confirm). A link works once, for one hour.
 */

/** The same rules sign-up applies: at least 8 characters, at most 72 bytes (bcrypt's limit). */
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_BYTES = 72;

/** The reset token from a page's query string, or '' when it has none. */
export function resetTokenFrom(search) {
  const token = new URLSearchParams(search || '').get('token');
  return token ? token.trim() : '';
}

/** Why a new password cannot be used yet, or null when it can. */
export function passwordProblem(password, confirmation) {
  if (password.length < PASSWORD_MIN_LENGTH) {
    return `Use at least ${PASSWORD_MIN_LENGTH} characters.`;
  }
  if (new TextEncoder().encode(password).length > PASSWORD_MAX_BYTES) {
    return 'That password is too long. Use a shorter one.';
  }
  if (password !== confirmation) {
    return "The two passwords don't match.";
  }
  return null;
}

/**
 * What a failed request means for the learner. 400 on confirm is a used,
 * expired or unknown link (or a password the server refused), with the
 * server's reason; 429 is too many attempts.
 */
export function resetFailure(status, serverMessage) {
  if (status === 429) return 'Too many attempts. Please wait a few minutes and try again.';
  if (status === 400 && serverMessage) return serverMessage;
  return "Something went wrong. Please check your connection and try again.";
}
