'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/stores/auth-store';
import { ApiError } from '@/lib/api';
import { authReturnPath } from '@/lib/auth-return.mjs';
import { googleServerFailure, googleWindowFailure } from '@/lib/google-sign-in.mjs';
import { googleIdToken, googleSignInConfig, prepareGoogleSignIn } from '@/lib/google-popup';

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
    </svg>
  );
}

/**
 * "Continue with Google", with an "or" line above it and an optional note
 * below. Shows nothing when the website was built without the Firebase settings.
 */
export function GoogleSignInButton({ onError, note }: { onError: (message: string) => void; note?: React.ReactNode }) {
  const router = useRouter();
  const loginWithFirebase = useAuthStore((state) => state.loginWithFirebase);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (googleSignInConfig) prepareGoogleSignIn().catch(() => {});
  }, []);

  if (!googleSignInConfig) return null;

  async function signIn() {
    if (busy) return;
    onError('');
    setBusy(true);
    let idToken: string;
    try {
      idToken = await googleIdToken();
    } catch (reason) {
      const message = googleWindowFailure((reason as { code?: string } | null)?.code);
      if (message) onError(message);
      setBusy(false);
      return;
    }
    try {
      await loginWithFirebase(idToken);
      router.push(authReturnPath(window.location.search));
    } catch (reason) {
      onError(googleServerFailure(reason instanceof ApiError ? reason.status : 0, reason instanceof Error ? reason.message : null));
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3 text-xs font-bold uppercase tracking-wider text-secondary">
        <span className="h-px flex-1" style={{ background: 'rgba(255,255,255,0.1)' }} />
        or
        <span className="h-px flex-1" style={{ background: 'rgba(255,255,255,0.1)' }} />
      </div>
      <button
        type="button"
        onClick={signIn}
        disabled={busy}
        className="flex w-full items-center justify-center gap-3 rounded-xl bg-white py-3.5 text-sm font-bold text-[#1f1f1f] transition-all duration-200 hover:opacity-90 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60"
      >
        <GoogleMark />
        {busy ? 'Signing in with Google…' : 'Continue with Google'}
      </button>
      {note && <p className="text-center text-xs leading-relaxed text-secondary">{note}</p>}
    </div>
  );
}
