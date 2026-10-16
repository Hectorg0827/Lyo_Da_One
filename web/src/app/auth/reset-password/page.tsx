'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AlertCircle, Lock } from 'lucide-react';
import { api, clearTokens } from '@/lib/api';

export default function ResetPasswordPage() {
  const [token, setToken] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [pending, setPending] = useState(false);
  const [completed, setCompleted] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const value = new URLSearchParams(window.location.search).get('token');
    setToken(value && value.length >= 40 && value.length <= 1024 ? value : null);
    setLoaded(true);
    // Do not retain credential-bearing reset URLs in browser history.
    if (value) window.history.replaceState(null, '', window.location.pathname);
  }, []);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token || pending) return;
    if (password.length < 8 || password.length > 72) {
      setError('Password must contain between 8 and 72 characters.');
      return;
    }
    if (password !== confirmation) {
      setError('The passwords do not match.');
      return;
    }
    setPending(true);
    setError('');
    try {
      await api.auth.confirmPasswordReset(token, password, confirmation);
      clearTokens(); // Any credentials held by this browser are now untrusted.
      setToken(null);
      setPassword('');
      setConfirmation('');
      setCompleted(true);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Reset failed. Request a new link.');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0a0a0f] px-4 py-12 text-white">
      <div className="w-full max-w-md space-y-6 rounded-3xl border border-white/10 bg-[#171720] p-8 shadow-2xl">
        <div className="space-y-2 text-center">
          <h1 className="text-2xl font-bold">
            {completed ? 'Password updated' : 'Create a new password'}
          </h1>
          <p className="text-sm text-gray-300">
            {completed
              ? 'Your password was changed. Sign in again with your new credentials.'
              : 'Choose a new password for your LYO account.'}
          </p>
        </div>

        {loaded && !token && !completed && (
          <p role="alert" className="text-sm text-amber-200">
            This reset link is missing or invalid. Request a fresh email to continue.
          </p>
        )}

        {loaded && token && !completed && (
          <form onSubmit={submit} className="space-y-4">
            {[
              { id: 'new-password', label: 'New password', value: password, onChange: setPassword },
              { id: 'confirm-password', label: 'Confirm new password', value: confirmation, onChange: setConfirmation },
            ].map((field) => (
              <label key={field.id} htmlFor={field.id} className="block space-y-2 text-sm font-semibold">
                <span>{field.label}</span>
                <span className="flex items-center gap-2 rounded-xl border border-white/20 bg-white/5 px-3">
                  <Lock size={18} aria-hidden="true" />
                  <input
                    id={field.id}
                    type="password"
                    autoComplete="new-password"
                    minLength={8}
                    maxLength={72}
                    className="w-full bg-transparent py-3 outline-none"
                    value={field.value}
                    onChange={(event) => field.onChange(event.target.value)}
                    required
                  />
                </span>
              </label>
            ))}
            {error && (
              <p role="alert" className="flex items-center gap-2 text-sm text-red-300">
                <AlertCircle size={16} aria-hidden="true" />{error}
              </p>
            )}
            <button
              disabled={pending}
              type="submit"
              className="w-full rounded-xl bg-indigo-600 px-4 py-3 font-semibold hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending ? 'Updating password…' : 'Update password'}
            </button>
          </form>
        )}

        <Link href={completed ? '/auth/login' : '/auth/forgot-password'}
          className="block text-center text-sm text-indigo-300 hover:underline">
          {completed ? 'Sign in' : 'Request a new reset link'}
        </Link>
      </div>
    </main>
  );
}
