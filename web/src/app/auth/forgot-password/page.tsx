'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoai.app';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (loading) return;
    setError('');
    setLoading(true);
    try {
      const response = await fetch(API_URL + '/api/v1/auth/password-reset/request', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.trim() }),
      });
      if (!response.ok) {
        throw new Error(response.status === 429
          ? 'Too many requests. Please try again later.'
          : 'Password recovery is temporarily unavailable. Please contact support.');
      }
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not request a password reset.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0d0f18] px-5 py-12 text-white">
      <section className="w-full max-w-md rounded-3xl border border-white/10 bg-white/[0.04] p-7 sm:p-9">
        <Link href="/" className="text-sm font-extrabold tracking-[0.18em] text-violet-300">LYO</Link>
        <h1 className="mt-6 font-rounded text-3xl font-bold">Reset your password</h1>
        {done ? (
          <div role="status" className="mt-5 space-y-5">
            <p className="text-white/75">If your email is associated with an account, a password reset link will arrive shortly. Check your spam folder too. The link expires after one hour.</p>
            <Link href="/auth/login" className="inline-flex min-h-11 items-center justify-center rounded-xl bg-violet-500 px-5 font-semibold hover:bg-violet-400">Return to login</Link>
          </div>
        ) : (
          <form onSubmit={submit} className="mt-6 space-y-4">
            <p className="text-sm leading-6 text-white/65">Enter your account email and we'll send a secure link to choose a new password.</p>
            <label htmlFor="recovery-email" className="block text-sm font-semibold">Email address</label>
            <input id="recovery-email" name="email" type="email" autoComplete="email" required maxLength={254} value={email} onChange={(e)=>setEmail(e.target.value)}
              placeholder="you@example.com" className="w-full rounded-xl border border-white/20 bg-white/10 px-4 py-3 text-white placeholder:text-white/40 focus:outline focus:outline-2 focus:outline-violet-400" />
            {error && <p role="alert" className="text-sm text-red-300">{error}</p>}
            <button disabled={loading} type="submit" className="min-h-12 w-full rounded-xl bg-violet-500 px-6 font-bold transition hover:bg-violet-400 disabled:opacity-60">
              {loading ? 'Sending…' : 'Send reset link'}
            </button>
          </form>
        )}
        <p className="mt-6 text-sm text-white/60"><Link className="text-violet-300 hover:underline" href="/auth/login">Back to login</Link> · <a className="hover:underline" href="mailto:support@lyo.app">Support</a></p>
      </section>
    </main>
  );
}
