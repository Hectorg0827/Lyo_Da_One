'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Eye, EyeOff, Mail, Lock, AlertCircle } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';

const containerVariants = {
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
  },
};

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
  onChange: (value: string) => void;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
  placeholder: string;
  rightSlot?: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-semibold uppercase tracking-wider text-secondary">{label}</label>
      <div
        className="flex items-center gap-3 rounded-xl px-4 py-3 transition-all duration-200 focus-within:ring-1 focus-within:ring-[#6c63ff]/60"
        style={{
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      >
        <Icon size={16} className="shrink-0 text-secondary" />
        <input
          type={type}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          autoComplete={type === 'password' ? 'current-password' : 'email'}
          required
          className="min-w-0 flex-1 bg-transparent text-sm text-primary outline-none placeholder:text-secondary"
        />
        {rightSlot}
      </div>
    </div>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const { login, isLoading } = useAuthStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');

  async function handleLogin(event: React.FormEvent) {
    event.preventDefault();
    setError('');

    if (!email.trim() || !password) {
      setError('Enter your email and password.');
      return;
    }

    try {
      await login(email.trim(), password);
      router.push('/');
    } catch (reason) {
      setError(reason instanceof Error && reason.message ? reason.message : 'Invalid email or password.');
    }
  }

  return (
    <div
      className="flex min-h-screen items-center justify-center p-4"
      style={{
        background: 'radial-gradient(ellipse 80% 80% at 50% -20%, rgba(108,99,255,0.25) 0%, rgba(10,10,15,1) 60%)',
      }}
    >
      <div
        className="pointer-events-none fixed left-1/4 top-0 h-96 w-96 rounded-full opacity-20 blur-[120px]"
        style={{ background: 'radial-gradient(circle, #6c63ff, #8b5cf6)' }}
      />
      <div
        className="pointer-events-none fixed bottom-0 right-1/4 h-80 w-80 rounded-full opacity-15 blur-[100px]"
        style={{ background: 'radial-gradient(circle, #ec4899, #6c63ff)' }}
      />

      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="relative z-10 w-full max-w-md"
      >
        <div
          className="space-y-6 rounded-3xl p-8"
          style={{
            background: 'rgba(17,17,24,0.85)',
            backdropFilter: 'blur(24px)',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 32px 80px rgba(0,0,0,0.5)',
          }}
        >
          <div className="flex flex-col items-center gap-4">
            <div className="relative">
              <div
                className="orb-gradient h-20 w-20 animate-float rounded-full"
                style={{ boxShadow: '0 0 40px rgba(108,99,255,0.5)' }}
              />
              <div className="orb-gradient absolute inset-0 rounded-full opacity-50 blur-xl" />
            </div>
            <div className="text-center">
              <h1 className="text-2xl font-black text-primary">Welcome back to LYO</h1>
              <p className="mt-1 text-sm text-secondary">Continue your learning journey</p>
            </div>
          </div>

          {error && (
            <motion.div
              role="alert"
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-center gap-2 rounded-xl px-4 py-3 text-sm"
              style={{
                background: 'rgba(239,68,68,0.12)',
                border: '1px solid rgba(239,68,68,0.25)',
                color: '#ef4444',
              }}
            >
              <AlertCircle size={15} className="shrink-0" />
              {error}
            </motion.div>
          )}

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
                  onClick={() => setShowPassword((current) => !current)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  className="shrink-0 text-secondary transition-colors duration-150 hover:text-primary"
                >
                  {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              }
            />

            <button
              type="submit"
              disabled={isLoading}
              className="w-full rounded-xl py-3.5 text-sm font-bold text-white transition-all duration-200 hover:opacity-90 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60"
              style={{ background: 'linear-gradient(135deg, #6c63ff 0%, #8b5cf6 100%)' }}
            >
              {isLoading ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24" aria-hidden="true">
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

          <p className="text-center text-sm text-secondary">
            New to LYO?{' '}
            <Link
              href="/auth/signup"
              className="font-semibold text-[#8b83ff] transition-colors duration-150 hover:text-[#6c63ff]"
            >
              Sign up
            </Link>
          </p>

          <p className="text-center text-xs leading-relaxed text-secondary">
            Password recovery and social sign-in will appear only after their backend flows are available.
          </p>
        </div>
      </motion.div>
    </div>
  );
}
