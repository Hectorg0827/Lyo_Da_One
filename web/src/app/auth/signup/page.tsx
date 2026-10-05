'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Eye, EyeOff, Mail, Lock, User, AlertCircle, CheckSquare, Square } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';
import { authReturnPath, authSwitchHref } from '@/lib/auth-return.mjs';
import MascotAvatar from '@/components/chat/MascotAvatar';

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
        className="flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 focus-within:ring-1 focus-within:ring-[#6366f1]/60"
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

// ── Password strength ──────────────────────────────────────────────────────────

function getPasswordStrength(pw: string): { label: string; color: string; width: string } {
  if (pw.length === 0) return { label: '', color: 'transparent', width: '0%' };
  if (pw.length < 8) return { label: 'Too short', color: '#ef4444', width: '25%' };
  if (pw.length < 10) return { label: 'Weak', color: '#f59e0b', width: '50%' };
  if (/[A-Z]/.test(pw) && /[0-9]/.test(pw)) return { label: 'Strong', color: '#22c55e', width: '100%' };
  return { label: 'Fair', color: '#6366f1', width: '75%' };
}

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function SignupPage() {
  const router = useRouter();
  const { signup, isLoading } = useAuthStore();

  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [error, setError] = useState('');
  const [resumeTestPrep, setResumeTestPrep] = useState(false);
  const [switchHref, setSwitchHref] = useState('/auth/login');

  useEffect(() => {
    setResumeTestPrep(authReturnPath(window.location.search) === '/test-prep');
    setSwitchHref(authSwitchHref('/auth/login', window.location.search));
  }, []);

  const pwStrength = getPasswordStrength(password);

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (!displayName || !email || !password) {
      setError('Please fill in all fields.');
      return;
    }
    if (!agreedToTerms) {
      setError('Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }
    try {
      await signup(email, password, displayName);
      router.push(authReturnPath(window.location.search));
    } catch {
      setError('Something went wrong. Please try again.');
    }
  }


  return (
    <div
      className="min-h-screen flex items-center justify-center p-4"
      style={{
        background: 'radial-gradient(ellipse 80% 80% at 50% -20%, rgba(99,102,241,0.25) 0%, rgba(10,10,15,1) 60%)',
      }}
    >
      {/* Background orbs */}
      <div
        className="fixed top-0 right-1/4 w-96 h-96 rounded-full blur-[120px] pointer-events-none opacity-20"
        style={{ background: 'radial-gradient(circle, #8b5cf6, #ec4899)' }}
      />
      <div
        className="fixed bottom-0 left-1/4 w-80 h-80 rounded-full blur-[100px] pointer-events-none opacity-15"
        style={{ background: 'radial-gradient(circle, #6366f1, #3b82f6)' }}
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
          {/* Lyo mascot */}
          <div className="flex flex-col items-center gap-4">
            <div className="relative w-20 h-20 flex items-center justify-center">
              <div className="absolute inset-0 rounded-full blur-xl opacity-50 orb-gradient" />
              <MascotAvatar idle size={72} />
            </div>
            <div className="text-center">
              <h1 className="text-2xl font-black text-primary">Join LYO</h1>
              <p className="text-sm text-secondary mt-1">Start your AI-powered learning journey</p>
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
          <form onSubmit={handleSignup} className="space-y-4">
            <AuthInput
              label="Display Name"
              type="text"
              value={displayName}
              onChange={setDisplayName}
              icon={User}
              placeholder="Your name"
            />

            <AuthInput
              label="Email"
              type="email"
              value={email}
              onChange={setEmail}
              icon={Mail}
              placeholder="you@example.com"
            />

            <div className="space-y-2">
              <AuthInput
                label="Password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={setPassword}
                icon={Lock}
                placeholder="Min. 8 characters"
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
              {password.length > 0 && (
                <div className="space-y-1">
                  <div className="h-1 rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.08)' }}>
                    <div
                      className="h-full rounded-full transition-all duration-300"
                      style={{ width: pwStrength.width, background: pwStrength.color }}
                    />
                  </div>
                  <p className="text-[11px]" style={{ color: pwStrength.color }}>{pwStrength.label}</p>
                </div>
              )}
            </div>

            {/* Terms consent — legal links are real destinations, not part of the checkbox hit target. */}
            <div className="flex items-start gap-2.5 text-left w-full">
              <button
                type="button"
                onClick={() => setAgreedToTerms((v) => !v)}
                aria-pressed={agreedToTerms}
                aria-label="Agree to Terms of Service and Privacy Policy"
                className="shrink-0 mt-0.5"
              >
                {agreedToTerms ? (
                  <CheckSquare size={17} style={{ color: '#6366f1' }} />
                ) : (
                  <Square size={17} className="text-secondary" />
                )}
              </button>
              <span className="text-xs text-secondary leading-relaxed">
                I agree to LYO&apos;s{' '}
                <a href="https://lyo.app/terms" target="_blank" rel="noreferrer" className="text-[#a78bfa] hover:underline">Terms of Service</a>
                {' '}and{' '}
                <a href="https://lyo.app/privacy" target="_blank" rel="noreferrer" className="text-[#a78bfa] hover:underline">Privacy Policy</a>
              </span>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3.5 rounded-xl text-sm font-bold text-white transition-all duration-200 hover:opacity-90 active:scale-[0.98] disabled:opacity-60 disabled:cursor-not-allowed"
              style={{ background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)' }}
            >
              {isLoading ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Creating account…
                </span>
              ) : (
                'Create Account'
              )}
            </button>
          </form>

          {/* Log in link */}
          <p className="text-center text-sm text-secondary">
            Already have an account?{' '}
            <Link
              href={switchHref}
              className="font-semibold text-[#a78bfa] hover:text-[#6366f1] transition-colors duration-150"
            >
              Log in
            </Link>
          </p>
        </div>
      </motion.div>
    </div>
  );
}
