'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Eye, EyeOff, Mail, Lock, AlertCircle } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';

// ── Animation variants ─────────────────────────────────────────────────────────

const containerVariants = {
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
  },
};

// ── Input component ────────────────────────────────────────────────────────────

function AuthInput({
  label,
  type,
  value,
  onChange,
  icon: Icon,
  placeholder,
  rightSlot,
}: {
  label: string;
  type: string;
  value: string;
  onChange: (v: string) => void;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
  placeholder: string;
  rightSlot?: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-semibold text-secondary uppercase tracking-wider">{label}</label>
      <div
        className="flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 focus-within:ring-1 focus-within:ring-[#6c63ff]/60"
        style={{
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      >
        <Icon size={16} className="text-secondary shrink-0" />
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="flex-1 bg-transparent text-sm text-primary placeholder:text-secondary outline-none min-w-0"
        />
        {rightSlot}
      </div>
    </div>
  );
}

// ── OAuth button ───────────────────────────────────────────────────────────────

function OAuthButton({
  provider,
  icon,
  onClick,
}: {
  provider: string;
  icon: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="flex-1 flex items-center justify-center gap-2.5 py-3 rounded-xl text-sm font-semibold text-primary transition-all duration-200 hover:bg-white/[0.08] active:scale-[0.97]"
      style={{ border: '1px solid rgba(255,255,255,0.12)' }}
    >
      {icon}
      {provider}
    </button>
  );
}

// ── Google SVG ─────────────────────────────────────────────────────────────────

const GoogleIcon = (
  <svg width="18" height="18" viewBox="0 0 48 48" fill="none">
    <path d="M43.611 20.083H42V20H24v8h11.303C33.654 32.657 29.332 36 24 36c-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z" fill="#FFC107"/>
    <path d="M6.306 14.691l6.571 4.819C14.655 15.108 19.001 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z" fill="#FF3D00"/>
    <path d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0124 36c-5.302 0-9.816-3.404-11.32-8.07l-6.474 4.99C9.505 39.556 16.227 44 24 44z" fill="#4CAF50"/>
    <path d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 01-4.087 5.571l6.19 5.238C39.999 35.554 44 30.377 44 24c0-1.341-.138-2.65-.389-3.917z" fill="#1976D2"/>
  </svg>
);

const AppleIcon = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
    <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.52-1.27 3.02-2.53 4.08zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
  </svg>
);

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function LoginPage() {
  const router = useRouter();
  const { login, isLoading } = useAuthStore();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (!email || !password) {
      setError('Please fill in all fields.');
      return;
    }
    try {
      await login(email, password);
      router.push('/');
    } catch {
      setError('Invalid email or password. Try demo@lyo.app / any password.');
    }
  }

  function handleOAuth(provider: string) {
    // OAuth placeholder — triggers demo login
    login('demo@lyo.app', 'demo').then(() => router.push('/'));
    console.log(`OAuth: ${provider}`);
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-4"
      style={{
        background: 'radial-gradient(ellipse 80% 80% at 50% -20%, rgba(108,99,255,0.25) 0%, rgba(10,10,15,1) 60%)',
      }}
    >
      {/* Background orbs */}
      <div
        className="fixed top-0 left-1/4 w-96 h-96 rounded-full blur-[120px] pointer-events-none opacity-20"
        style={{ background: 'radial-gradient(circle, #6c63ff, #8b5cf6)' }}
      />
      <div
        className="fixed bottom-0 right-1/4 w-80 h-80 rounded-full blur-[100px] pointer-events-none opacity-15"
        style={{ background: 'radial-gradient(circle, #ec4899, #6c63ff)' }}
      />

      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="w-full max-w-md relative z-10"
      >
        <div
          className="rounded-3xl p-8 space-y-6"
          style={{
            background: 'rgba(17,17,24,0.85)',
            backdropFilter: 'blur(24px)',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 32px 80px rgba(0,0,0,0.5)',
          }}
        >
          {/* LYO orb */}
          <div className="flex flex-col items-center gap-4">
            <div className="relative">
              <div
                className="w-20 h-20 rounded-full orb-gradient animate-float"
                style={{ boxShadow: '0 0 40px rgba(108,99,255,0.5)' }}
              />
              <div
                className="absolute inset-0 rounded-full blur-xl opacity-50 orb-gradient"
              />
            </div>
            <div className="text-center">
              <h1 className="text-2xl font-black text-primary">Welcome back to LYO</h1>
              <p className="text-sm text-secondary mt-1">Continue your learning journey</p>
            </div>
          </div>

          {/* Error banner */}
          {error && (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-center gap-2 px-4 py-3 rounded-xl text-sm"
              style={{ background: 'rgba(239,68,68,0.12)', border: '1px solid rgba(239,68,68,0.25)', color: '#ef4444' }}
            >
              <AlertCircle size={15} className="shrink-0" />
              {error}
            </motion.div>
          )}

          {/* Form */}
          <form onSubmit={handleLogin} className="space-y-4">
            <AuthInput
              label="Email"
              type="email"
              value={email}
              onChange={setEmail}
              icon={Mail}
              placeholder="you@example.com"
            />

            <AuthInput
              label="Password"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={setPassword}
              icon={Lock}
              placeholder="••••••••"
              rightSlot={
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="text-secondary hover:text-primary transition-colors duration-150 shrink-0"
                >
                  {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              }
            />

            <div className="flex justify-end">
              <Link
                href="/auth/forgot-password"
                className="text-xs text-secondary hover:text-[#8b83ff] transition-colors duration-150"
              >
                Forgot password?
              </Link>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3.5 rounded-xl text-sm font-bold text-white transition-all duration-200 hover:opacity-90 active:scale-[0.98] disabled:opacity-60 disabled:cursor-not-allowed"
              style={{ background: 'linear-gradient(135deg, #6c63ff 0%, #8b5cf6 100%)' }}
            >
              {isLoading ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Logging in…
                </span>
              ) : (
                'Log In'
              )}
            </button>
          </form>

          {/* Divider */}
          <div className="flex items-center gap-3">
            <div className="flex-1 h-px" style={{ background: 'rgba(255,255,255,0.08)' }} />
            <span className="text-xs text-secondary">or continue with</span>
            <div className="flex-1 h-px" style={{ background: 'rgba(255,255,255,0.08)' }} />
          </div>

          {/* OAuth buttons */}
          <div className="flex gap-3">
            <OAuthButton
              provider="Google"
              icon={GoogleIcon}
              onClick={() => handleOAuth('google')}
            />
            <OAuthButton
              provider="Apple"
              icon={<span className="text-primary">{AppleIcon}</span>}
              onClick={() => handleOAuth('apple')}
            />
          </div>

          {/* Sign up link */}
          <p className="text-center text-sm text-secondary">
            New to LYO?{' '}
            <Link
              href="/auth/signup"
              className="font-semibold text-[#8b83ff] hover:text-[#6c63ff] transition-colors duration-150"
            >
              Sign up
            </Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
}
