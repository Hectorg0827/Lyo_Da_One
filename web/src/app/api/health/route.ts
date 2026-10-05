import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

/**
 * Which commit this running instance was built from, or null.
 *
 * Read at request time rather than baked in at build, because the production
 * web service is built by Railway from `web/Dockerfile` — not from the image
 * CI publishes — so the only identifier present in production is whichever
 * one the platform injects.
 *
 * Several names are tried because the platform's own has not been confirmed
 * against a running instance. `LYO_GIT_COMMIT` is the override that always
 * works: set it as a Railway service variable to the reference
 * `${{RAILWAY_GIT_COMMIT_SHA}}` so it still changes per deploy. A literal
 * commit pasted there would freeze this field and make every deploy look
 * current, which is worse than reporting nothing.
 *
 * Null when nothing supplied one. A health endpoint that invented a commit,
 * or echoed the last one it knew, would make a stale deploy look fresh —
 * the exact failure this field exists to catch.
 */
function deployedCommit(): string | null {
  const candidates = [
    process.env.LYO_GIT_COMMIT,
    process.env.RAILWAY_GIT_COMMIT_SHA,
    process.env.GIT_COMMIT,
  ];
  for (const value of candidates) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed;
  }
  return null;
}

export function GET() {
  return NextResponse.json(
    {
      status: 'healthy',
      service: 'lyo-web',
      // The commit this instance is serving, so a deploy can be told apart
      // from the build before it. `null` means the instance was given no
      // commit, not that it is running the newest one.
      commit: deployedCommit(),
      timestamp: new Date().toISOString(),
    },
    {
      status: 200,
      headers: { 'Cache-Control': 'no-store' },
    }
  );
}
