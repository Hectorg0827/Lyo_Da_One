export type AuthHydrationFailure = 'invalid_session' | 'transient';
export function hydrationFailureKind(error: unknown): AuthHydrationFailure;
