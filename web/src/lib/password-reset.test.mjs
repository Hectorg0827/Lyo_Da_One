import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PASSWORD_MAX_BYTES, PASSWORD_MIN_LENGTH, passwordProblem, resetFailure, resetTokenFrom } from './password-reset.mjs';

test('the reset token is read from the link, and a link without one has none', () => {
  assert.equal(resetTokenFrom('?token=abc_DEF-123'), 'abc_DEF-123');
  assert.equal(resetTokenFrom('?utm=x&token=%20t0k%20'), 't0k');
  assert.equal(resetTokenFrom(''), '');
  assert.equal(resetTokenFrom('?token='), '');
  assert.equal(resetTokenFrom(null), '');
});

test('a new password follows the sign-up rules and must be typed twice the same', () => {
  assert.equal(PASSWORD_MIN_LENGTH, 8);
  assert.equal(PASSWORD_MAX_BYTES, 72);
  assert.equal(passwordProblem('short', 'short'), 'Use at least 8 characters.');
  assert.equal(passwordProblem('long-enough', 'long-enougH'), "The two passwords don't match.");
  assert.equal(passwordProblem('é'.repeat(37), 'é'.repeat(37)), 'That password is too long. Use a shorter one.',
    '37 accented letters are 74 bytes, over bcrypt\'s 72');
  assert.equal(passwordProblem('long-enough', 'long-enough'), null);
});

test('a refused link shows the server\'s reason; other failures say what to do', () => {
  assert.equal(resetFailure(400, 'This reset link is invalid, used or expired. Ask for a new one.'),
    'This reset link is invalid, used or expired. Ask for a new one.');
  assert.match(resetFailure(429, 'whatever'), /Too many attempts/);
  assert.match(resetFailure(0, null), /check your connection/);
  assert.match(resetFailure(500, 'Internal'), /check your connection/);
});

test('login links to the reset, and the pages call the API the server serves', () => {
  const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
  const login = read('../app/auth/login/page.tsx');
  const forgot = read('../app/auth/forgot-password/page.tsx');
  const reset = read('../app/auth/reset-password/page.tsx');
  const api = read('./api.ts');
  assert.ok(login.includes('href="/auth/forgot-password"') && login.includes('Forgot password?'));
  assert.ok(!login.includes('Password recovery'), 'the login page no longer says recovery is missing');
  assert.ok(forgot.includes('api.auth.requestPasswordReset(email.trim())'));
  assert.ok(reset.includes('resetTokenFrom(window.location.search)'));
  assert.ok(reset.includes('passwordProblem(password, confirmation)') && reset.includes('api.auth.confirmPasswordReset(token, password)'));
  assert.ok(api.includes("'/auth/password-reset/request'") && api.includes("'/auth/password-reset/confirm'"));
  assert.ok(api.includes('JSON.stringify({ token, new_password: newPassword })'));
});
