import Link from 'next/link';

export const SUPPORT_EMAIL = 'support@lyoai.app';

/**
 * The frame the public legal pages share (/privacy, /terms, /support).
 * A server component with no auth: these pages must open for anyone,
 * including App Store and Play Store reviewers who are not signed in.
 */
export function LegalPage({
  title,
  updated,
  intro,
  children,
}: {
  title: string;
  updated?: string;
  intro?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-[#0d0f18] px-4 py-10 text-white sm:px-6">
      <article className="mx-auto max-w-3xl">
        <nav className="mb-8 flex flex-wrap items-center justify-between gap-3 text-sm">
          <Link href="/" className="font-bold tracking-[0.2em] text-violet-200">LYO</Link>
          <div className="flex gap-4 text-white/60">
            <Link href="/privacy" className="hover:text-white">Privacy</Link>
            <Link href="/terms" className="hover:text-white">Terms</Link>
            <Link href="/support" className="hover:text-white">Support</Link>
          </div>
        </nav>
        <h1 className="font-rounded text-3xl font-extrabold sm:text-4xl">{title}</h1>
        {updated && <p className="mt-2 text-sm text-white/50">Last updated: {updated}</p>}
        {intro && <div className="mt-6 text-base leading-relaxed text-white/75">{intro}</div>}
        <div className="mt-8 space-y-8">{children}</div>
        <footer className="mt-12 border-t border-white/10 pt-6 text-sm text-white/50">
          Questions? Email <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
        </footer>
      </article>
    </main>
  );
}

export function LegalSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="text-xl font-bold text-white">{title}</h2>
      <div className="mt-3 space-y-3 text-[15px] leading-relaxed text-white/75 [&_li]:ml-5 [&_li]:list-disc [&_li]:pl-1 [&_strong]:text-white">
        {children}
      </div>
    </section>
  );
}
