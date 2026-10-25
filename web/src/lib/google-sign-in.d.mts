export interface FirebaseWebConfig {
  apiKey: string;
  authDomain: string;
  projectId: string;
  appId: string;
}

export function firebaseWebConfig(env: {
  apiKey?: string;
  authDomain?: string;
  projectId?: string;
  appId?: string;
} | null | undefined): FirebaseWebConfig | null;

export function googleWindowFailure(code: string | null | undefined): string | null;

export function googleServerFailure(status: number, serverMessage: string | null | undefined): string;
