'use client';

import { useEffect } from 'react';
import { useAuthStore } from '@/stores/auth-store';
import { syncClient } from '@/lib/sync';

export default function AuthProvider({ children }: { children: React.ReactNode }) {
  const hydrate = useAuthStore((s) => s.hydrate);
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);

  useEffect(() => {
    hydrate();
  }, [hydrate]);

  // Keep the cross-device sync socket in lockstep with auth state:
  // connected while logged in, torn down on logout.
  useEffect(() => {
    if (isAuthenticated) {
      syncClient.connect();
      return () => syncClient.disconnect();
    }
    syncClient.disconnect();
  }, [isAuthenticated]);

  return <>{children}</>;
}
