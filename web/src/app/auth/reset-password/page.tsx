'use client';

import { FormEvent, Suspense, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoai.app';

function ResetForm() {
  const params = useSearchParams();
  const token = params.get('token');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [completed, setCompleted] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token || password.length < 8 || password !== confirm || loading) {
      setError('Choose a password with at least eight characters and confirm it.');
      return;
    }
    setError('');
    setLoading(true);
    try {
      const response = await fetch(API_URL + '/api/v1/auth/password-reset/confirm', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, new_password: password, confirm_password: confirm }),
      });
      if (!response.ok) {
        throw new Error(response.status === 400
          ? 'This link has expired or was already used. Request a new reset link.'
          : 'Password recovery is unavailable. Please try again later.');
      }
      window.history.replaceState({}, '', '/auth/reset-password');
      setCompleted(true);
      setPassword('');
      setConfirm('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Password reset failed.');
    } finally { setLoading(false); }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0d0f18] px-5 py-12 text-white">
      <section className="w-full max-w-md rounded-3xl border border-white/10 bg-white/[0.04] p-7 sm:p-9">
        <Link href="/" className="text-sm font-extrabold tracking-[0.18em] text-violet-300">LYO</Link>
        <h1 className="mt-6 font-rounded text-3xl font-bold">{completed ? 'Password updated' : 'Choose a new password'}</h1>
        {completed ? (
          <div role="status" className="mt-6 space-y-5">
            <p>Your password has been updated. Sign in with your new password.</p>
            <Link href="/auth/login" className="inline-flex min-h-12 items-center justify-center rounded-xl bg-violet-500 px-6 font-semibold hover:bg-violet-400">Sign in</Link>
          </div>
        ) : !token ? (
          <div className="mt-5 space-y-5">
            <p role="alert" className="text-white/75">The recovery link is missing its token.</p>
            <Link className="text-violet-300 underline" href="/auth/forgot-password">Request a new link</Link>
          </div>
        ) : (
          <form onSubmit={submit} className="mt-6 space-y-4">
            <label htmlFor="new-password" className="block text-sm font-semibold">New password</label>
            <input id="new-password" required minLength={8} maxLength={72} autoComplete="new-password" type="password" value={password} onChange={e=>setPassword(e.target.value)}
              className="w-full rounded-xl border border-white/20 bg-white/10 px-4 py-3 text-white focus:outline focus:outline-2 focus:outline-violet-400" />
            <label htmlFor="confirm-password" className="block text-sm font-semibold">Confirm password</label>
            <input id="confirm-password" required minLength={8} maxLength={72} autoComplete="new-password" type="password" value={confirm} onChange={e=>setConfirm(e.target.value)}
              className="w-full rounded-xl border border-white/20 bg-white/10 px-4 py-3 text-white focus:outline focus:outline-2 focus:outline-violet-400" />
            {error && <p role="alert" className="text-sm text-red-300">{error}</p>}
            <button type="submit" disabled={loading} className="min-h-12 w-full rounded-xl bg-violet-500 px-6 font-bold hover:bg-violet-400 disabled:opacity-60">
              {loading ? 'Saving…' : 'Set new password'}
            </button>
          </form>
        )}
        <p className="mt-6 text-sm text-white/60"><Link href="/auth/login" className="text-violet-300 hover:underline">Back to login</Link></p>
      </section>
    </main>
  );
}

export default function ResetPasswordPage() {
  return <Suspense fallback={<div role="status" className="min-h-screen bg-[#0d0f18] text-white">Preparing password reset…</div>}><ResetForm /></Suspense>;
}
