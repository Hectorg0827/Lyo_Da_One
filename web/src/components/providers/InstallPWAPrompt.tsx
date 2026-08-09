'use client';

import { useEffect, useState } from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

const DISMISS_KEY = 'lyo_install_prompt_dismissed';

/**
 * "The browser version should also offer Install Lyo and run as a
 * full-screen PWA" — a manifest alone doesn't surface an in-app
 * affordance; Chrome shows its own small icon in the address bar, easy to
 * miss. This renders an explicit, dismissible "Install Lyo" banner driven
 * by the real `beforeinstallprompt` event, and registers the service
 * worker that reliable installability depends on.
 */
export default function InstallPWAPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return;
    navigator.serviceWorker.register('/sw.js').catch(() => {
      // Installability degrades gracefully without it — not fatal.
    });
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const isStandalone =
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as unknown as { standalone?: boolean }).standalone === true;
    if (isStandalone) return;
    if (localStorage.getItem(DISMISS_KEY) === '1') return;

    const handleBeforeInstall = (event: Event) => {
      event.preventDefault();
      setDeferredPrompt(event as BeforeInstallPromptEvent);
      setVisible(true);
    };
    window.addEventListener('beforeinstallprompt', handleBeforeInstall);

    const handleInstalled = () => {
      setVisible(false);
      setDeferredPrompt(null);
      localStorage.setItem(DISMISS_KEY, '1');
    };
    window.addEventListener('appinstalled', handleInstalled);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall);
      window.removeEventListener('appinstalled', handleInstalled);
    };
  }, []);

  const install = async () => {
    if (!deferredPrompt) return;
    await deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    setDeferredPrompt(null);
    setVisible(false);
  };

  const dismiss = () => {
    setVisible(false);
    localStorage.setItem(DISMISS_KEY, '1');
  };

  if (!visible) return null;

  return (
    <div
      role="dialog"
      aria-label="Install Lyo"
      className={cn(
        'fixed bottom-4 left-4 right-4 z-[60] mx-auto flex max-w-sm items-center gap-3',
        'rounded-2xl border border-white/10 bg-[#111a38]/95 px-4 py-3',
        'shadow-2xl shadow-black/40 backdrop-blur-xl',
      )}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/icons/icon-192.png" alt="" className="h-10 w-10 shrink-0 rounded-xl" />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-bold text-white">Install Lyo</p>
        <p className="text-xs text-white/60">Add to your home screen for the full app experience.</p>
      </div>
      <button
        onClick={install}
        className="shrink-0 rounded-full bg-gradient-to-r from-lyo-600 to-accent-purple px-3 py-1.5 text-xs font-semibold text-white"
      >
        Install
      </button>
      <button
        onClick={dismiss}
        aria-label="Dismiss install prompt"
        className="shrink-0 p-1 text-white/40 hover:text-white transition-colors"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
