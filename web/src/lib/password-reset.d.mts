export const PASSWORD_MIN_LENGTH: number;
export const PASSWORD_MAX_BYTES: number;
export function resetTokenFrom(search: string | null | undefined): string;
export function passwordProblem(password: string, confirmation: string): string | null;
export function resetFailure(status: number, serverMessage?: string | null): string;
