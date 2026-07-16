'use client';

import { useState, useEffect, useCallback, useRef } from 'react';

interface UseApiResult<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useApi<T>(
  fetcher: (() => Promise<T>) | null,
  deps: unknown[] = []
): UseApiResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(!!fetcher);
  const [error, setError] = useState<string | null>(null);
  const versionRef = useRef(0);

  const execute = useCallback(() => {
    if (!fetcher) {
      setIsLoading(false);
      return;
    }
    const version = ++versionRef.current;
    setIsLoading(true);
    setError(null);
    fetcher()
      .then((result) => {
        if (version === versionRef.current) {
          setData(result);
          setIsLoading(false);
        }
      })
      .catch((err) => {
        if (version === versionRef.current) {
          setError(err?.message || 'Something went wrong');
          setIsLoading(false);
        }
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    execute();
  }, [execute]);

  return { data, isLoading, error, refetch: execute };
}
